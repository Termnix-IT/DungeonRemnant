"""Build a painted dungeon terrain atlas from generated textures.

art/tiles/painted/source/<theme>_floor.png and _wall.png are seamless
textures (seen from above); _pillar.png and _stairs.png are objects on a
transparent background. This writes art/tiles/painted/<theme>_terrain.png,
CELL px cells, COLUMNS to a row, that dungeon.gd shows at the 48 px grid
with mipmapped linear filtering. Tile index i is at column i % COLUMNS,
row i / COLUMNS:

- 0 floor, 1 stairs, 2 pillar, 3-4 floor (the pixel atlas's slots, kept so
  tile indices mean the same), 5-20 the wall for each up/right/down/left
  connection mask, 21-36 the floor texture cut into PERIOD x PERIOD cells,
  then for each further wall position (WALL_PERIOD x WALL_PERIOD cells,
  the first being 5-20) its 16 masks.

The floor is one texture spread over PERIOD x PERIOD cells, and the wall's
over WALL_PERIOD x WALL_PERIOD, so neighbouring cells continue each other:
the floor shows no grid, and a run of wall keeps its stones' size. Stairs and the pillar
stand on the floor's first cell. Walls keep the pixel atlas's rules: the
stone darker and flatter than the floor, a lit rim on the top and left open
edges, a shaded rim on the bottom and right, and a dark gap where a wall
meets the floor.

	python tools/build_painted_terrain.py slate
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "tiles" / "painted" / "source"
OUTPUT = ROOT / "art" / "tiles" / "painted"
# Twice the 48 px cell, a little above its largest size on screen (86 px at
# 1920x1080), so mipmaps always shrink it.
CELL = 96
PERIOD = 4
WALL_PERIOD = 2
WALL_TILE_COUNT = 16
COLUMNS = 16
GAP = 8
BEVEL = 6
RIM_LIGHT = 1.3
RIM_SHADE = 0.6
WALL_TONE = 0.62
WALL_CONTRAST = 0.8
# Objects on their floor cell, as a share of the cell.
PILLAR_SIZE = 0.9
STAIRS_SIZE = 0.96


def load(theme: str, part: str) -> Image.Image:
	return Image.open(SOURCE / f"{theme}_{part}.png").convert("RGBA")


def floor_cells(floor: Image.Image) -> list[Image.Image]:
	sheet = floor.convert("RGB").resize((CELL * PERIOD, CELL * PERIOD), Image.Resampling.LANCZOS)
	return [sheet.crop((x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL)).convert("RGBA")
		for y in range(PERIOD) for x in range(PERIOD)]


def shade(colour: np.ndarray, factor: float) -> np.ndarray:
	return np.clip(colour * factor, 0, 255)


def wall_cells(wall: Image.Image) -> list[Image.Image]:
	sheet = wall.convert("RGB").resize((CELL * WALL_PERIOD, CELL * WALL_PERIOD), Image.Resampling.LANCZOS)
	return [sheet.crop((x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL))
		for y in range(WALL_PERIOD) for x in range(WALL_PERIOD)]


def wall_tile(wall: Image.Image, floor: Image.Image, mask: int) -> Image.Image:
	floor_pixels = np.asarray(floor.convert("RGB")).reshape(-1, 3).astype(np.float64)
	void = shade(np.percentile(floor_pixels, 5, axis=0), 0.45).astype(np.uint8)
	up, right, down, left = (mask & 1, mask & 2, mask & 4, mask & 8)
	top = 0 if up else GAP
	bottom = CELL if down else CELL - GAP
	start = 0 if left else GAP
	end = CELL if right else CELL - GAP
	stone = np.asarray(wall).astype(np.float64)
	mean = stone.reshape(-1, 3).mean(axis=0)
	stone = (mean + (stone - mean) * WALL_CONTRAST) * WALL_TONE
	canvas = stone.copy()
	if not up:
		canvas[GAP:GAP + BEVEL, start:end] = stone[GAP:GAP + BEVEL, start:end] * RIM_LIGHT
	if not left:
		canvas[top:bottom, GAP:GAP + BEVEL] = stone[top:bottom, GAP:GAP + BEVEL] * RIM_LIGHT
	if not down:
		canvas[CELL - GAP - BEVEL:CELL - GAP, start:end] = stone[CELL - GAP - BEVEL:CELL - GAP, start:end] * RIM_SHADE
	if not right:
		canvas[top:bottom, CELL - GAP - BEVEL:CELL - GAP] = stone[top:bottom, CELL - GAP - BEVEL:CELL - GAP] * RIM_SHADE
	canvas = np.clip(canvas, 0, 255).astype(np.uint8)
	if not up:
		canvas[:GAP] = void
	if not down:
		canvas[CELL - GAP:] = void
	if not left:
		canvas[:, :GAP] = void
	if not right:
		canvas[:, CELL - GAP:] = void
	return Image.fromarray(canvas).convert("RGBA")


# An object (trimmed to its pixels) centred on a floor cell at size times
# the cell, a soft contact shadow under it.
def on_floor(floor: Image.Image, thing: Image.Image, size: float, shadow: bool) -> Image.Image:
	box = thing.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
	thing = thing.crop(box)
	scale = CELL * size / max(thing.width, thing.height)
	thing = thing.resize((max(1, round(thing.width * scale)), max(1, round(thing.height * scale))), Image.Resampling.LANCZOS)
	out = floor.copy()
	x = (CELL - thing.width) // 2
	y = (CELL - thing.height) // 2
	if shadow:
		blot = Image.new("L", (CELL, CELL), 0)
		ImageDraw.Draw(blot).ellipse((x + thing.width * 0.08, y + thing.height * 0.62, x + thing.width * 0.92, y + thing.height * 1.02), fill=150)
		blot = blot.filter(ImageFilter.GaussianBlur(CELL * 0.05))
		dark = Image.new("RGBA", (CELL, CELL), (6, 8, 12, 255))
		dark.putalpha(blot)
		out.alpha_composite(dark)
	out.alpha_composite(thing, (x, y))
	return out


def build(theme: str) -> Image.Image:
	floors = floor_cells(load(theme, "floor"))
	walls = wall_cells(load(theme, "wall"))
	first = floors[0]
	stairs = on_floor(first, load(theme, "stairs"), STAIRS_SIZE, False)
	pillar = on_floor(first, load(theme, "pillar"), PILLAR_SIZE, True)
	tiles = [first, stairs, pillar, first, first]
	tiles += [wall_tile(walls[0], first, mask) for mask in range(WALL_TILE_COUNT)]
	tiles += floors
	for wall in walls[1:]:
		tiles += [wall_tile(wall, first, mask) for mask in range(WALL_TILE_COUNT)]
	rows = (len(tiles) + COLUMNS - 1) // COLUMNS
	atlas = Image.new("RGBA", (CELL * COLUMNS, CELL * rows))
	for index, tile in enumerate(tiles):
		atlas.paste(tile, ((index % COLUMNS) * CELL, (index // COLUMNS) * CELL))
	return atlas


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("themes", nargs="+")
	args = parser.parse_args()
	OUTPUT.mkdir(parents=True, exist_ok=True)
	for theme in args.themes:
		atlas = build(theme)
		atlas.save(OUTPUT / f"{theme}_terrain.png")
		print(f"Saved {theme}_terrain.png ({atlas.width}x{atlas.height})")


if __name__ == "__main__":
	main()
