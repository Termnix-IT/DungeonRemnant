"""Build the dungeon terrain atlases from generated 3x2 tile boards.

Each board in art/tiles/source/<theme>.png holds, left to right and top to
bottom: floor, cracked floor, floor with detail, wall top, pillar, stairs. The
output keeps the atlas layout dungeon.gd reads (21 tiles of 48px in one row):
floor 0, stairs 1, pillar 2, floor variants 3-4, then the 16 wall tiles indexed
by the up/right/down/left connection mask. Wall edges without a neighbouring
wall get a dark gap and a bevel, drawn here so the art only needs one wall.

	python tools/build_terrain_atlas.py --all
	python tools/build_terrain_atlas.py moss

Running tools/generate_terrain_atlas.gd afterwards overwrites these files with
the flat placeholder atlases.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "tiles" / "source"
OUTPUT = ROOT / "art" / "tiles"
TILE = 48
WALL_TILE_START = 5
WALL_TILE_COUNT = 16
GAP = 4
RIM_LIGHT = 1.3
RIM_SHADE = 0.6
BEVEL = 3
# Trim each board cell so a neighbouring tile never bleeds into this one.
CELL_INSET = 0.02
PALETTE_COLORS = 64
THEMES = {
	"slate": "dungeon_terrain.png",
	"moss": "dungeon_terrain_moss.png",
	"ember": "dungeon_terrain_ember.png",
	"sanctum": "dungeon_terrain_sanctum.png",
}


def cut_tiles(board: Image.Image) -> list[Image.Image]:
	board = board.convert("RGB")
	cell_w = board.width / 3
	cell_h = board.height / 2
	tiles: list[Image.Image] = []
	for row in range(2):
		for column in range(3):
			left = column * cell_w + cell_w * CELL_INSET
			top = row * cell_h + cell_h * CELL_INSET
			box = (round(left), round(top), round(left + cell_w * (1 - 2 * CELL_INSET)), round(top + cell_h * (1 - 2 * CELL_INSET)))
			tiles.append(board.crop(box).resize((TILE, TILE), Image.Resampling.BOX))
	return tiles


def shade(colour: np.ndarray, factor: float) -> tuple[int, int, int]:
	if factor >= 1.0:
		return tuple(int(v) for v in np.clip(colour + (255 - colour) * (factor - 1.0), 0, 255))
	return tuple(int(v) for v in np.clip(colour * factor, 0, 255))


def wall_tile(wall: Image.Image, floor: Image.Image, mask: int) -> Image.Image:
	floor_pixels = np.asarray(floor).reshape(-1, 3).astype(np.float64)
	void = shade(np.percentile(floor_pixels, 5, axis=0), 0.45)
	up, right, down, left = (mask & 1, mask & 2, mask & 4, mask & 8)
	top = 0 if up else GAP
	bottom = TILE if down else TILE - GAP
	start = 0 if left else GAP
	end = TILE if right else TILE - GAP
	stone = np.asarray(wall).astype(np.float64)
	canvas = stone.copy()
	# Open edges get a lit or shaded rim cut from the stone itself, so the
	# block keeps its texture instead of gaining a flat painted line.
	if not up:
		canvas[GAP:GAP + BEVEL, start:end] = stone[GAP:GAP + BEVEL, start:end] * RIM_LIGHT
	if not left:
		canvas[top:bottom, GAP:GAP + BEVEL] = stone[top:bottom, GAP:GAP + BEVEL] * RIM_LIGHT
	if not down:
		canvas[TILE - GAP - BEVEL:TILE - GAP, start:end] = stone[TILE - GAP - BEVEL:TILE - GAP, start:end] * RIM_SHADE
	if not right:
		canvas[top:bottom, TILE - GAP - BEVEL:TILE - GAP] = stone[top:bottom, TILE - GAP - BEVEL:TILE - GAP] * RIM_SHADE
	canvas = np.clip(canvas, 0, 255).astype(np.uint8)
	if not up:
		canvas[:GAP] = void
	if not down:
		canvas[TILE - GAP:] = void
	if not left:
		canvas[:, :GAP] = void
	if not right:
		canvas[:, TILE - GAP:] = void
	return Image.fromarray(canvas)


def build_atlas(board: Image.Image) -> Image.Image:
	floor, cracked, detailed, wall, pillar, stairs = cut_tiles(board)
	ordered = [floor, stairs, pillar, cracked, detailed]
	ordered += [wall_tile(wall, floor, mask) for mask in range(WALL_TILE_COUNT)]
	atlas = Image.new("RGB", (TILE * len(ordered), TILE))
	for index, tile in enumerate(ordered):
		atlas.paste(tile, (index * TILE, 0))
	# One shared palette keeps the painted detail reading as pixel art.
	return atlas.quantize(colors=PALETTE_COLORS, dither=Image.Dither.NONE).convert("RGBA")


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("themes", nargs="*", help=" / ".join(THEMES))
	parser.add_argument("--all", action="store_true", help="build every theme with a board in the source folder")
	parser.add_argument("--source", type=Path, default=SOURCE)
	parser.add_argument("--output", type=Path, default=OUTPUT)
	args = parser.parse_args()
	themes = [name for name in THEMES if (args.source / f"{name}.png").exists()] if args.all else args.themes
	if not themes:
		parser.error("name a theme or pass --all with boards in the source folder")
	unknown = [name for name in themes if name not in THEMES]
	if unknown:
		parser.error(f"unknown theme {unknown}; expected one of {list(THEMES)}")
	for theme in themes:
		atlas = build_atlas(Image.open(args.source / f"{theme}.png"))
		if atlas.size != (TILE * (WALL_TILE_START + WALL_TILE_COUNT), TILE):
			raise ValueError(f"Unexpected atlas size {atlas.size}")
		args.output.mkdir(parents=True, exist_ok=True)
		atlas.save(args.output / THEMES[theme])
		print(f"Saved {THEMES[theme]} from {theme}.png")


if __name__ == "__main__":
	main()
