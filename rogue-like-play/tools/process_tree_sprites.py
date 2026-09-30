"""Cut the forest's tree sprites from a generated 2x2 board.

art/tiles/source/trees.png holds four tree variants on a flat background.
Each becomes a TREE px pixel-art sprite with the enemies' 1px outline, set on
the frame's bottom edge, and the four are written side by side to
art/tiles/forest_trees.png for dungeon.gd to draw over forest wall cells.

	python tools/process_tree_sprites.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from build_ui_frames import pixel_part
from process_item_icons import cut_board

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "tiles" / "source" / "trees.png"
OUTPUT = ROOT / "art" / "tiles" / "forest_trees.png"
TREE = 64


def main() -> None:
	trees = cut_board(Image.open(SOURCE), 2, 2)
	strip = Image.new("RGBA", (TREE * len(trees), TREE))
	for index, source in enumerate(trees):
		sprite = pixel_part(source, (TREE, TREE))
		strip.alpha_composite(sprite, (index * TREE + (TREE - sprite.width) // 2, TREE - sprite.height))
	if any(strip.getchannel("A").histogram()[1:255]):
		raise ValueError("alpha must be binary")
	strip.save(OUTPUT)
	print(f"Saved {OUTPUT.relative_to(ROOT)} ({len(trees)} trees of {TREE}px)")


if __name__ == "__main__":
	main()
