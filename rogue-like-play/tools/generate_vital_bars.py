"""Draw the HUD gauge textures used by the Theme's vital bar styles.

Writes to art/ui/:
- vital_frame.png: a bronze-rimmed socket for HP and MP (9-slice, 5px
  margins), with a rivet at each end and a dark inset;
- vital_frame_thin.png: the same socket, slimmer, for the EXP bar;
- vital_<name>.png: fills, a vertical gradient with a lit top row and a
  shaded bottom row, stretched to the bar's width.

The Theme draws the frame as the trail's background with expand margins,
so the HUD's fixed bar rectangles and the tests that read them stay put.

	python tools/generate_vital_bars.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "art" / "ui"

OUTLINE = (10, 11, 14, 255)
RIM_DARK = (92, 70, 38, 255)
RIM = (150, 116, 64, 255)
RIM_LIGHT = (214, 178, 112, 255)
RIVET = (232, 204, 142, 255)
INSET = (6, 8, 11, 255)
INSET_SHADOW = (2, 3, 5, 255)

# Fill colours: (top highlight, upper body, lower body, bottom shade).
FILLS = {
	"health": ((255, 150, 128), (214, 64, 52), (170, 38, 34), (96, 18, 20)),
	"health_trail": ((255, 222, 170), (246, 170, 96), (214, 130, 70), (140, 78, 40)),
	"mana": ((200, 196, 255), (128, 122, 232), (96, 90, 200), (52, 48, 124)),
	"mana_trail": ((236, 238, 255), (200, 204, 255), (170, 176, 240), (110, 114, 170)),
	"experience": ((170, 208, 255), (84, 140, 220), (64, 110, 190), (34, 60, 112)),
}


def frame(width: int, height: int, rim: int) -> Image.Image:
	"""A rim `rim` pixels wide around a dark inset; outline outermost."""
	image = Image.new("RGBA", (width, height), OUTLINE)
	pixels = image.load()
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			edge = min(x - 1, y - 1, width - 2 - x, height - 2 - y)
			if edge >= rim - 1:
				# Inset: a darker top row reads as depth under the rim.
				pixels[x, y] = INSET_SHADOW if y == rim else INSET
			elif y == 1 or (x == 1 and y < height - 2):
				pixels[x, y] = RIM_LIGHT
			elif y == height - 2 or x == width - 2:
				pixels[x, y] = RIM_DARK
			else:
				pixels[x, y] = RIM
	# A rivet on each end cap, centred vertically.
	middle = height // 2
	for x in (2, width - 3):
		for y in (middle - 1, middle):
			pixels[x, y] = RIVET
	return image


def fill(colours: tuple) -> Image.Image:
	top, upper, lower, bottom = colours
	height = 12
	image = Image.new("RGBA", (4, height))
	pixels = image.load()
	for y in range(height):
		if y == 0:
			colour = top
		elif y == height - 1:
			colour = bottom
		else:
			t = (y - 1) / (height - 3)
			colour = tuple(round(upper[i] + (lower[i] - upper[i]) * t) for i in range(3))
		for x in range(4):
			pixels[x, y] = (*colour, 255)
	return image


def main() -> None:
	OUTPUT.mkdir(parents=True, exist_ok=True)
	frame(24, 14, 4).save(OUTPUT / "vital_frame.png")
	frame(20, 10, 3).save(OUTPUT / "vital_frame_thin.png")
	for name, colours in FILLS.items():
		fill(colours).save(OUTPUT / f"vital_{name}.png")
	print(f"Saved vital gauge textures to {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
	main()
