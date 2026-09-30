"""Cut the hub home cards' illustrations from a generated board.

art/hub/source/home_cards.png is a 2x3 grid of wide painted panels on a flat
magenta background, in the order of CARDS (the last cell stays empty). Each
panel is trimmed a few pixels inside its edge, so no key-colour fringe
remains, and saved as art/hub/cards/<name>.png.

	python tools/cut_card_art.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from process_enemy_sheet import background_mask

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "hub" / "source" / "home_cards.png"
OUTPUT = ROOT / "art" / "hub" / "cards"
ROWS = 3
COLUMNS = 2
CARDS = ["stairs", "weapons", "chests", "shop", "books"]
TRIM = 3


def main() -> None:
	board = Image.open(SOURCE).convert("RGB")
	painted = ~background_mask(board)
	height, width = painted.shape
	OUTPUT.mkdir(parents=True, exist_ok=True)
	for index, name in enumerate(CARDS):
		row, column = divmod(index, COLUMNS)
		# Panels may not line up with an even grid, so each one is found by
		# walking out from its cell's centre to the magenta gutter.
		cy = (2 * row + 1) * height // (2 * ROWS)
		cx = (2 * column + 1) * width // (2 * COLUMNS)
		if not painted[cy, cx]:
			raise ValueError(f"{name}: cell centre is not painted")
		left, right, top, bottom = cx, cx, cy, cy
		while left > 0 and painted[cy, left - 1]:
			left -= 1
		while right < width - 1 and painted[cy, right + 1]:
			right += 1
		while top > 0 and painted[top - 1, cx]:
			top -= 1
		while bottom < height - 1 and painted[bottom + 1, cx]:
			bottom += 1
		box = (left + TRIM, top + TRIM, right + 1 - TRIM, bottom + 1 - TRIM)
		board.crop(box).save(OUTPUT / f"{name}.png")
		print(f"Saved cards/{name}.png {box[2] - box[0]}x{box[3] - box[1]}")


if __name__ == "__main__":
	main()
