"""Cut the painted emblem boards into ability and upgrade emblems.

Each board in art/emblems/painted/source/ is a grid of round medallions on
flat magenta, in the order listed in BOARDS. Every medallion is cut out (its
edge pulled in by EDGE_TRIM px so no magenta fringe stays), centred in a
square and shrunk to SIZE px as art/emblems/<key>.png, which Godot imports
with mipmaps and the UI draws with mipmapped linear filtering. Keys are the
AbilityData.Effect names in lower case, plus the upgrade-only vitality and
mana; see ui/emblem_icons.gd.

	python tools/process_emblems.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter

from build_painted_objects import square
from process_item_icons import cut_board

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "emblems" / "painted" / "source"
OUTPUT = ROOT / "art" / "emblems"
# Twice the largest an emblem is drawn (96 px on the level-up card).
SIZE = 192
FILL = 0.96
# The cut's edge holds a little of the key colour; pull it in (odd).
EDGE_TRIM = 5
BOARDS = [
	("emblems_a.png", 2, 3, ["max_hp", "vitality", "kill_heal", "defense", "vision", "mana"]),
	("emblems_b.png", 2, 3, ["attack", "sword_damage", "spear_damage", "hammer_damage", "spear_range", "spear_pierce"]),
]


def cut(source: Image.Image) -> Image.Image:
	alpha = source.getchannel("A").filter(ImageFilter.MinFilter(EDGE_TRIM)).filter(ImageFilter.GaussianBlur(1.0))
	source.putalpha(alpha)
	return source.crop(alpha.getbbox())


def main() -> None:
	for name, rows, columns, keys in BOARDS:
		path = SOURCE / name
		if not path.exists():
			print(f"Skipped {name}: not generated yet")
			continue
		for key, source in zip(keys, cut_board(Image.open(path), rows, columns), strict=True):
			square(cut(source), SIZE, FILL).save(OUTPUT / f"{key}.png")
		print(f"Saved {len(keys)} emblems from {name}")


if __name__ == "__main__":
	main()
