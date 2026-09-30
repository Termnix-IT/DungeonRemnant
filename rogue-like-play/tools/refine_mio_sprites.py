"""Give the approved 64px Mio dungeon frames the enemies' finish and a breath.

Reads the approved atlases in art/characters/mio_dungeon_chibi_64/ and writes
the same layouts to art/characters/mio_dungeon_refined/, so the design itself
never changes and the step can be re-run safely:

- every frame gets the enemies' 1px dark outline (see process_enemy_sheet.py);
- cardinal.png and diagonal.png: column 1 (the second idle frame) becomes the
  "breath in" pose of column 0, with the head and shoulders one pixel lower;
- idle_front.png: all 8 frames reuse frame 0, take the approved closed eyes
  from frames 4 and 5, and breathe on frames 1-3, so the blink is baked in and
  no separate eye overlay is needed.

	python tools/refine_mio_sprites.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from process_enemy_sheet import add_outline

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "characters" / "mio_dungeon_chibi_64"
OUTPUT = ROOT / "art" / "characters" / "mio_dungeon_refined"
CELL = 64
# Rows above this share of the body's height sink by one pixel on the breath;
# the beret, face and shoulders move while the skirt and feet stay planted.
BREATH_LINE = 0.55
EYE_RECT = (23, 29, 45, 38)
BLINK_FRAMES = (4, 5)
BREATH_FRAMES = (1, 2, 3)


def cells(atlas: Image.Image) -> list[list[Image.Image]]:
	return [[atlas.crop((x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL)) for x in range(atlas.width // CELL)] for y in range(atlas.height // CELL)]


def outline(frame: Image.Image) -> Image.Image:
	box = frame.getchannel("A").getbbox()
	if box is None:
		return frame
	result = Image.new("RGBA", frame.size)
	result.alpha_composite(add_outline(frame.crop(box)), (box[0] - 1, box[1] - 1))
	return result


def breathe(frame: Image.Image) -> Image.Image:
	box = frame.getchannel("A").getbbox()
	line = box[1] + round((box[3] - box[1]) * BREATH_LINE)
	pixels = np.asarray(frame).copy()
	upper = pixels[:line].copy()
	# Clear the old upper body first so the lowered one leaves no ghost row.
	pixels[:line] = 0
	pixels[1:line + 1] = np.where(upper[:, :, 3:4] > 0, upper, pixels[1:line + 1])
	return Image.fromarray(pixels)


def assemble(rows: list[list[Image.Image]]) -> Image.Image:
	atlas = Image.new("RGBA", (len(rows[0]) * CELL, len(rows) * CELL))
	for y, row in enumerate(rows):
		for x, frame in enumerate(row):
			atlas.alpha_composite(frame, (x * CELL, y * CELL))
	return atlas


def refine_direction_sheet(name: str) -> Image.Image:
	rows = cells(Image.open(SOURCE / name).convert("RGBA"))
	for row in rows:
		row[1] = breathe(row[0])
	return assemble([[outline(frame) for frame in row] for row in rows])


def refine_front_idle() -> Image.Image:
	source = [frame for row in cells(Image.open(SOURCE / "idle_front.png").convert("RGBA")) for frame in row]
	frames: list[Image.Image] = []
	for index in range(len(source)):
		frame = source[0].copy()
		if index in BLINK_FRAMES:
			frame.paste(source[index].crop(EYE_RECT), EYE_RECT[:2])
		if index in BREATH_FRAMES:
			frame = breathe(frame)
		frames.append(outline(frame))
	return assemble([frames[:4], frames[4:]])


def refine_front_walk() -> Image.Image:
	rows = cells(Image.open(SOURCE / "walk_front.png").convert("RGBA"))
	return assemble([[outline(frame) for frame in row] for row in rows])


def validate(atlas: Image.Image, name: str) -> None:
	if any(atlas.getchannel("A").histogram()[1:255]):
		raise ValueError(f"{name}: alpha must be binary")
	for y, row in enumerate(cells(atlas)):
		for x, frame in enumerate(row):
			box = frame.getchannel("A").getbbox()
			if box is None or box[0] < 1 or box[1] < 1 or box[2] > CELL - 1 or box[3] > CELL - 1:
				raise ValueError(f"{name}: frame {x},{y} touches the cell edge: {box}")


def main() -> None:
	OUTPUT.mkdir(parents=True, exist_ok=True)
	for name, atlas in [
		("cardinal.png", refine_direction_sheet("cardinal.png")),
		("diagonal.png", refine_direction_sheet("diagonal.png")),
		("idle_front.png", refine_front_idle()),
		("walk_front.png", refine_front_walk()),
	]:
		validate(atlas, name)
		atlas.save(OUTPUT / name)
		print(f"Saved mio_dungeon_refined/{name} {atlas.size}")


if __name__ == "__main__":
	main()
