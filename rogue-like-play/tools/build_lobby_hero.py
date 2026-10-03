"""Build the lobby heroine's textures from her generated illustration.

art/characters/source/mio_lobby_source.png is the transparent full-body
illustration, and mio_lobby_eyes_closed.png the same picture edited to close
her eyes. This writes, all the same size:

- art/characters/mio_lobby.png: the figure, trimmed, with clear margins on
  the sides and top so swaying hair never leaves the texture.
- art/characters/mio_lobby_blink.png: the figure with only the eye area taken
  from the closed-eyes edit (feathered), so nothing else can differ.
- art/characters/mio_lobby_motion.png: how far each pixel may sway, read by
  ui/lobby_hero.gdshader. Red is hair, green the coat and skirt hem; both
  grow from the roots towards the tips.

	python tools/build_lobby_hero.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "characters" / "source" / "mio_lobby_source.png"
CLOSED = ROOT / "art" / "characters" / "source" / "mio_lobby_eyes_closed.png"
OUTPUT = ROOT / "art" / "characters"
# Trim to the figure plus TRIM, then add MARGIN on the sides and top. The feet
# keep only TRIM below them, so the lobby can stand her on the floor.
TRIM = 8
MARGIN = 40
# In the trimmed figure's pixels (before MARGIN).
EYES = (298, 142, 427, 230)
HAIR_REGIONS = [(470, 140, 954, 900), (215, 190, 335, 700)]
HAIR_EXCLUDE = [(225, 380, 315, 450), (495, 385, 575, 455), (320, 270, 440, 345)]
HAIR_ROOT, HAIR_TIP = 230.0, 820.0
HEM_REGION = (90, 560, 830, 860)
# The hand on the hilt and the hilt itself must not sway with the cloth.
HEM_EXCLUDE = [(215, 720, 335, 845)]
HEM_ROOT, HEM_TIP = 560.0, 830.0


def trimmed(path: Path, box: tuple[int, int, int, int] | None = None) -> tuple[Image.Image, tuple[int, int, int, int]]:
	image = Image.open(path).convert("RGBA")
	alpha = np.array(image.getchannel("A"))
	# The generator leaves solid pixels at 254; make them fully opaque.
	alpha[alpha >= 250] = 255
	image.putalpha(Image.fromarray(alpha))
	if box is None:
		x0, y0, x1, y1 = image.getchannel("A").getbbox()
		box = (max(0, x0 - TRIM), max(0, y0 - TRIM), min(image.width, x1 + TRIM), min(image.height, y1 + TRIM))
	return image.crop(box), box


def framed(image: Image.Image) -> Image.Image:
	canvas = Image.new("RGBA", (image.width + MARGIN * 2, image.height + MARGIN), (0, 0, 0, 0))
	canvas.paste(image, (MARGIN, MARGIN))
	return canvas


def ramp(values: np.ndarray, start: float, end: float) -> np.ndarray:
	t = np.clip((values - start) / (end - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def region_mask(shape: tuple[int, int], boxes: list[tuple[int, int, int, int]]) -> np.ndarray:
	mask = np.zeros(shape, dtype=bool)
	for x0, y0, x1, y1 in boxes:
		mask[y0:y1, x0:x1] = True
	return mask


def motion(figure: Image.Image) -> Image.Image:
	rgba = np.array(figure).astype(np.float32) / 255.0
	r, g, b, a = rgba[..., 0], rgba[..., 1], rgba[..., 2], rgba[..., 3]
	light = (np.maximum(np.maximum(r, g), b) + np.minimum(np.minimum(r, g), b)) * 0.5
	saturation = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
	ys = np.arange(figure.height, dtype=np.float32)[:, None] * np.ones((1, figure.width), dtype=np.float32)
	shape = (figure.height, figure.width)
	# Lavender-white strands: light, nearly grey, never warmer than blue.
	hair = (a > 0.05) & (light > 0.55) & (saturation < 0.32) & (b + 0.04 >= r)
	hair &= region_mask(shape, HAIR_REGIONS) & ~region_mask(shape, HAIR_EXCLUDE)
	hair_weight = hair * ramp(ys, HAIR_ROOT, HAIR_TIP)
	# The dark cloth of the coat and skirt; the silver blade stays still.
	hem = (a > 0.05) & (light < 0.3) & region_mask(shape, [HEM_REGION]) & ~region_mask(shape, HEM_EXCLUDE)
	hem_weight = hem * ramp(ys, HEM_ROOT, HEM_TIP)
	channels = []
	for weight in (hair_weight, hem_weight):
		layer = Image.fromarray((weight * 255).astype(np.uint8))
		# Blur so neighbouring pixels move together instead of tearing apart.
		channels.append(layer.filter(ImageFilter.GaussianBlur(10)))
	empty = Image.new("L", figure.size, 0)
	return Image.merge("RGBA", (channels[0], channels[1], empty, Image.new("L", figure.size, 255)))


def blink(figure: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
	closed, _ = trimmed(CLOSED, box)
	feather = Image.new("L", figure.size, 0)
	x0, y0, x1, y1 = EYES
	feather.paste(255, (x0 + 12, y0 + 10, x1 - 12, y1 - 10))
	feather = feather.filter(ImageFilter.GaussianBlur(8))
	result = figure.copy()
	result.paste(closed, (0, 0), feather)
	return result


def main() -> None:
	figure, box = trimmed(SOURCE)
	framed(figure).save(OUTPUT / "mio_lobby.png", optimize=True)
	framed(motion(figure)).save(OUTPUT / "mio_lobby_motion.png", optimize=True)
	if CLOSED.exists():
		framed(blink(figure, box)).save(OUTPUT / "mio_lobby_blink.png", optimize=True)
	print("figure", figure.size, "framed", framed(figure).size)


if __name__ == "__main__":
	main()
