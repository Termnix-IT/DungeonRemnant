"""Cut generated emblem boards into ability and upgrade emblems.

Each board in art/emblems/source/ is a grid of round medallions on a flat
background, in the order listed in BOARDS. Every medallion becomes
art/emblems/<key>.png with the item icons' treatment (48px pixel art, octree
palette, 1px dark outline, stored at 2x). Keys are the AbilityData.Effect
names in lower case, plus the upgrade-only vitality and mana; see
ui/emblem_icons.gd.

	python tools/process_emblems.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from process_item_icons import ICON, STORED_SCALE, cut_board, to_icon

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "emblems" / "source"
OUTPUT = ROOT / "art" / "emblems"
BOARDS = [
	("emblems_a.png", 2, 3, ["max_hp", "vitality", "kill_heal", "defense", "vision", "mana"]),
	("emblems_b.png", 2, 3, ["attack", "sword_damage", "spear_damage", "hammer_damage", "spear_range", "spear_pierce"]),
]


def main() -> None:
	for name, rows, columns, keys in BOARDS:
		path = SOURCE / name
		if not path.exists():
			print(f"Skipped {name}: not generated yet")
			continue
		for key, source in zip(keys, cut_board(Image.open(path), rows, columns), strict=True):
			emblem = to_icon(source)
			if any(emblem.getchannel("A").histogram()[1:255]):
				raise ValueError(f"{key}: alpha must be binary")
			emblem.resize((ICON * STORED_SCALE, ICON * STORED_SCALE), Image.Resampling.NEAREST).save(OUTPUT / f"{key}.png")
		print(f"Saved {len(keys)} emblems from {name}")


if __name__ == "__main__":
	main()
