"""Build the route's gates, their portcullis and the hall's pillar from their generated pictures.

art/ui/route/source/gate_<chapter>.png is a stone gateway seen from the
front, its opening and everything outside it a flat magenta (#FF00FF);
gate_bars.png is an iron portcullis and hall_pillar.png a stone column,
each on the same magenta. This keys the magenta out, trims each to what is
painted and writes, into art/ui/route/:

	gate_<chapter>.png        the gateway, its opening see-through, GATE_HEIGHT tall
	gate_<chapter>_light.png  the same size: red is the opening (where the
	                          gate's light and its portcullis show), green is
	                          how much of that light falls on the stone round
	                          the opening (strongest on its inner edge), blue
	                          is the light spilt past the stone (its halo)
	gate_bars.png             the portcullis, BARS_WIDTH wide
	hall_pillar.png           the pillar, PILLAR_HEIGHT tall

RouteGateView reads where the opening lies from the light picture itself, so
a gate repainted with another opening needs no constant changed.

Run from the Godot project root:

	python tools/build_route_gates.py                 # everything
	python tools/build_route_gates.py gate_gale_woods  # the named ones
	python tools/build_route_gates.py --measure        # where each opening lies
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from image_boards import key_out

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "route" / "source"
OUTPUT = ROOT / "art" / "ui" / "route"
GATES = ["gate_ash_corridor", "gate_gale_woods", "gate_amethyst_mausoleum", "gate_abyss_of_echoes"]
OTHERS = ["gate_bars", "hall_pillar"]
GATE_HEIGHT = 1000
BARS_WIDTH = 512
PILLAR_HEIGHT = 1200
# How far the gate's light reaches over its stone and past it, as shares of
# the gate's width.
RIM_REACH = 0.045
HALO_REACH = 0.12
# The opening is found above this share of the gate's height (see opening_of).
FOOT_CUT = 0.94


def keyed(name: str) -> Image.Image:
	image = key_out(Image.open(SOURCE / f"{name}.png"), 2)
	box = image.getchannel("A").point(lambda value: 255 if value > 24 else 0).getbbox()
	return image.crop(box)


def opening_of(gate: Image.Image) -> Image.Image:
	"""The gate's opening as a mask: the see-through region its middle lies in."""
	clear = gate.getchannel("A").point(lambda value: 255 if value < 128 else 0)
	seed = (gate.width // 2, round(gate.height * 0.62))
	if clear.getpixel(seed) == 0:
		raise ValueError("the gate's middle is not see-through: is its opening magenta?")
	# The jambs' feet are uneven, and a see-through sliver under one would join
	# the opening to the outside: the fill stops short of the foot, and the
	# opening runs straight down from there between the same two sides.
	cut = round(gate.height * FOOT_CUT)
	upper = clear.crop((0, 0, gate.width, cut))
	ImageDraw.floodfill(upper, seed, 128)
	hole = np.asarray(upper) == 128
	sides = np.flatnonzero(hole[-1])
	if sides.size == 0 or hole[:, 0].any() or hole[:, -1].any():
		raise ValueError("the gate's opening is not closed in by its stone")
	whole = np.zeros((gate.height, gate.width), dtype=bool)
	whole[:cut] = hole
	whole[cut:, sides[0]:sides[-1] + 1] = np.asarray(clear)[cut:, sides[0]:sides[-1] + 1] > 0
	return Image.fromarray((whole * 255).astype(np.uint8))


def build_gate(name: str) -> list[Path]:
	gate = keyed(name)
	size = (round(gate.width * GATE_HEIGHT / gate.height), GATE_HEIGHT)
	gate = gate.resize(size, Image.Resampling.LANCZOS)
	opening = opening_of(gate)
	stone = np.asarray(gate.getchannel("A"), dtype=np.float32) / 255.0
	hole = np.asarray(opening, dtype=np.float32) / 255.0
	# The opening's light on the stone: its blurred mask where there is stone,
	# lifted so the inner edge is fully lit.
	rim = np.asarray(opening.filter(ImageFilter.GaussianBlur(size[0] * RIM_REACH)), dtype=np.float32) / 255.0
	rim = np.clip(rim * 2.4, 0.0, 1.0) * stone
	halo = np.asarray(opening.filter(ImageFilter.GaussianBlur(size[0] * HALO_REACH)), dtype=np.float32) / 255.0
	halo = np.clip(halo * 1.6, 0.0, 1.0)
	light = np.dstack([hole, rim, halo, np.ones_like(hole)])
	# Whatever of the gate was painted over its own opening is cut away.
	pixels = np.asarray(gate, dtype=np.float32) / 255.0
	pixels[..., 3] *= 1.0 - hole
	gate_path = OUTPUT / f"{name}.png"
	light_path = OUTPUT / f"{name}_light.png"
	Image.fromarray((pixels * 255.0).round().astype(np.uint8), "RGBA").save(gate_path)
	Image.fromarray((light * 255.0).round().astype(np.uint8), "RGBA").save(light_path)
	return [gate_path, light_path]


def build_other(name: str) -> list[Path]:
	image = keyed(name)
	if name == "gate_bars":
		size = (BARS_WIDTH, round(image.height * BARS_WIDTH / image.width))
	else:
		size = (round(image.width * PILLAR_HEIGHT / image.height), PILLAR_HEIGHT)
	target = OUTPUT / f"{name}.png"
	image.resize(size, Image.Resampling.LANCZOS).save(target)
	return [target]


def measure(name: str) -> str:
	with Image.open(OUTPUT / f"{name}_light.png") as light:
		hole = np.asarray(light.getchannel("R")) > 128
		rows = np.flatnonzero(hole.any(axis=1))
		columns = np.flatnonzero(hole.any(axis=0))
		height, width = hole.shape
		return (f"{name}: {width}x{height}  opening x {columns[0] / width:.3f}-{(columns[-1] + 1) / width:.3f}"
			f"  y {rows[0] / height:.3f}-{(rows[-1] + 1) / height:.3f}  ({columns[-1] + 1 - columns[0]}x{rows[-1] + 1 - rows[0]} px)")


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("names", nargs="*", choices=GATES + OTHERS)
	parser.add_argument("--measure", action="store_true")
	arguments = parser.parse_args()
	names = arguments.names or GATES + OTHERS
	for name in names:
		if arguments.measure:
			if name in GATES:
				print(measure(name))
			continue
		for target in build_gate(name) if name in GATES else build_other(name):
			with Image.open(target) as built:
				print(f"{target.relative_to(ROOT)}: {built.width}x{built.height}")


if __name__ == "__main__":
	main()
