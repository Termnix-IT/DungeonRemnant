"""Build the pictures the fight's effects are drawn from.

The fight's effects (combat/vfx) are not finished pictures shown and faded;
each is a shader moving a painted picture: sweeping it round an arc, running
it along a line, rolling it out as a ring, letting it burn away. The
pictures are painted in white on black (how bright: how strong the light),
kept as they came in art/effects/vfx/source (the requests are in
docs/絵の制作記録/地形とエフェクトの絵.md), and cut and sized here:

	art/effects/vfx/slash_trail.png   a blade's trail laid out straight: its
	                                  head at the right, its sharp outer edge
	                                  along the top, cut to what is painted
	art/effects/vfx/bolt_strip.png    three bolts of lightning, one above
	                                  another, each running from side to side
	art/effects/vfx/flame_strip.png   a row of flames rising from the bottom
	                                  edge, its ends meeting
	art/effects/vfx/shock_ring.png    a shock's ring seen from above, its
	                                  outer edge at RING_EDGE of the picture's
	                                  half width (--measure prints where the
	                                  painted one was)
	art/effects/vfx/noise.png         three fields of cloudy noise that tile
	                                  (red: broad; green: fine; blue: drawn
	                                  out sideways into streaks), made here

All are single-channel pictures; black is pushed to true black so nothing
is added where nothing is painted.

Needs Pillow and numpy. Run from the Godot project root, then import, and
turn `mipmaps/generate` on in each new picture's .import (the shaders read
the blurred copies for their glow):

	python tools/build_vfx_art.py
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
VFX = ROOT / "art" / "effects" / "vfx"
SOURCE = VFX / "source"
# Below this a painted picture is taken for black; what is above is spread
# over the whole range again.
BLACK = 0.045
TRAIL_SIZE = (1024, 256)
BOLT_SIZE = (1024, 684)
FLAME_SIZE = (1024, 512)
RING_SIZE = 768
# Where the ring's outer edge is put, as a share of the picture's half width.
RING_EDGE = 0.86
NOISE_SIZE = 256


def light(name: str) -> np.ndarray:
	"""A source picture as brightness, 0 to 1, true black where it was nearly so."""
	picture = np.asarray(Image.open(SOURCE / f"{name}.png").convert("L"), dtype=np.float32) / 255.0
	return np.clip((picture - BLACK) / (1.0 - BLACK), 0.0, 1.0)


def save(name: str, picture: np.ndarray, size: tuple[int, int]) -> Path:
	target = VFX / f"{name}.png"
	Image.fromarray((np.clip(picture, 0.0, 1.0) * 255.0).round().astype(np.uint8), "L").resize(size, Image.LANCZOS).save(target)
	return target


def painted(picture: np.ndarray, floor: float = 0.08) -> tuple[int, int, int, int]:
	"""The box that holds what is painted: left, top, right, bottom."""
	rows = np.where(picture.max(axis=1) > floor)[0]
	columns = np.where(picture.max(axis=0) > floor)[0]
	return int(columns[0]), int(rows[0]), int(columns[-1]) + 1, int(rows[-1]) + 1


def build_trail() -> Path:
	picture = light("slash_trail")
	left, top, right, bottom = painted(picture)
	# The sparks thrown off the head stand above and below the stroke; the
	# stroke itself is the band where a row is lit along much of its length.
	lit = (picture > 0.2).mean(axis=1)
	band = np.where(lit > 0.06)[0]
	top, bottom = int(band[0]), int(band[-1]) + 1
	return save("slash_trail", picture[top:bottom, left:right], TRAIL_SIZE)


def build_bolts() -> Path:
	return save("bolt_strip", light("bolt_strip"), BOLT_SIZE)


def build_flames() -> Path:
	picture = light("flame_strip")
	# Its ends are made to meet: each is eased toward the other's over a
	# narrow strip.
	blend = max(8, picture.shape[1] // 40)
	ramp = np.linspace(0.5, 0.0, blend, dtype=np.float32)[None, :]
	left = picture[:, :blend].copy()
	right = picture[:, -blend:].copy()
	picture[:, :blend] = left * (1.0 - ramp[:, ::-1] * 1.0) + right[:, ::-1] * ramp[:, ::-1]
	picture[:, -blend:] = right * (1.0 - ramp) + left[:, ::-1] * ramp
	return save("flame_strip", picture, FLAME_SIZE)


def ring_edge(picture: np.ndarray) -> float:
	"""The ring's outer edge as a share of the picture's half width: where a circle's mean light is brightest."""
	side = picture.shape[0]
	ys, xs = np.mgrid[0:side, 0:side]
	far = np.hypot(xs - side / 2.0, ys - side / 2.0) / (side / 2.0)
	shares = np.linspace(0.3, 1.0, 141)
	mean = [picture[(far >= at - 0.004) & (far < at + 0.004)].mean() for at in shares]
	return float(shares[int(np.argmax(mean))])


def build_ring(measure: bool = False) -> Path | None:
	picture = light("shock_ring")
	side = min(picture.shape)
	picture = picture[:side, :side]
	edge = ring_edge(picture)
	if measure:
		print(f"shock_ring: its outer edge is at {edge:.3f} of the half width; built at {RING_EDGE}")
		return None
	# Scaled about its middle so the edge sits at RING_EDGE whatever was painted.
	scale = edge / RING_EDGE
	image = Image.fromarray((picture * 255.0).round().astype(np.uint8), "L")
	across = round(side * scale)
	offset = (side - across) // 2
	canvas = Image.new("L", (across, across), 0)
	canvas.paste(image, (-offset, -offset)) if across < side else canvas.paste(image, ((across - side) // 2, (across - side) // 2))
	target = VFX / "shock_ring.png"
	canvas.resize((RING_SIZE, RING_SIZE), Image.LANCZOS).save(target)
	return target


def cloud(rng: np.random.Generator, size: int, octaves: list[tuple[int, int, float]]) -> np.ndarray:
	"""Noise that tiles: grids of random values, each smoothed up to the picture, summed."""
	total = np.zeros((size, size), dtype=np.float32)
	weight = 0.0
	for across, down, share in octaves:
		grid = rng.random((down, across)).astype(np.float32)
		# One more row and column, wrapped, so the smoothing meets at the seams.
		grid = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")
		image = Image.fromarray((grid * 255.0).astype(np.uint8), "L").resize((size + size // across, size + size // down), Image.BICUBIC)
		total += np.asarray(image, dtype=np.float32)[:size, :size] / 255.0 * share
		weight += share
	total /= weight
	return (total - total.min()) / max(float(total.max() - total.min()), 1e-6)


def build_noise() -> Path:
	rng = np.random.default_rng(7)
	broad = cloud(rng, NOISE_SIZE, [(4, 4, 1.0), (8, 8, 0.5), (16, 16, 0.25)])
	fine = cloud(rng, NOISE_SIZE, [(16, 16, 1.0), (32, 32, 0.6), (64, 64, 0.3)])
	streaks = cloud(rng, NOISE_SIZE, [(4, 32, 1.0), (8, 64, 0.5), (16, 128, 0.25)])
	target = VFX / "noise.png"
	Image.fromarray((np.dstack([broad, fine, streaks]) * 255.0).round().astype(np.uint8), "RGB").save(target)
	return target


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--measure", action="store_true", help="print where the painted ring's edge is, and write nothing")
	arguments = parser.parse_args()
	if arguments.measure:
		build_ring(measure=True)
		return
	for target in [build_trail(), build_bolts(), build_flames(), build_ring(), build_noise()]:
		with Image.open(target) as image:
			print(f"{target.relative_to(ROOT)}  {image.width}x{image.height}")


if __name__ == "__main__":
	main()
