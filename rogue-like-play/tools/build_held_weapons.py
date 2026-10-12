"""Build the weapons the hero holds in the dungeon from their item icons.

The item icons in art/items/weapon_<kind>.png (WeaponData.Kind: 0 sword,
1 spear, 2 hammer, 3 axe, 4 staff) are 48px pixel art stored at twice that
size, every one lying the same way: the grip at the bottom left, the tip at
the top right. The hero holds a weapon of each kind as its icon shrunk to
about half the art, so its pixels sit at her own sprite's density; every
weapon of a kind (a wooden or an iron sword alike) shows the kind's picture.
The long ones (spear, staff) stay a little larger. Writes
art/characters/held/<kind>.png; Player draws them by the grip.

	python tools/build_held_weapons.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "items"
OUTPUT = ROOT / "art" / "characters" / "held"
# Kind index, name and the size held, in pixels.
KINDS = [(0, "sword", 24), (1, "spear", 28), (2, "hammer", 24), (3, "axe", 24), (4, "staff", 28)]


def build() -> None:
	OUTPUT.mkdir(parents=True, exist_ok=True)
	for index, name, size in KINDS:
		icon = Image.open(SOURCE / f"weapon_{index}.png").convert("RGBA")
		# Box averaging keeps the outline whole where every other pixel would
		# drop it.
		held = icon.resize((size, size), Image.Resampling.BOX)
		held.save(OUTPUT / f"{name}.png")
		print(f"{name}.png {held.size}")


if __name__ == "__main__":
	build()
