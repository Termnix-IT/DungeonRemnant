"""Shrink the painted weapons into the pictures the hero's hand holds.

Each source in art/characters/mio_rig/source/weapon_<id>.png is one weapon
painted upright on a transparent 512x1536 canvas, its head at the top. It is
cut to its opaque extent and shrunk to HEIGHT px as
art/characters/mio_rig/weapon_<id>.png, which a Moveset names as its `art`
and WeaponMount lays along the rig's sword. Moveset.art_grip is measured on
the cut picture (the share of its height from the head to the middle of the
grip), so a new source needs its grip measured again.

	python tools/build_weapon_art.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FOLDER = ROOT / "art" / "characters" / "mio_rig"
WEAPONS = ["spear", "hammer"]
# About four times the tallest it is drawn in the fight.
HEIGHT = 384


def main() -> None:
	for weapon in WEAPONS:
		source = Image.open(FOLDER / "source" / f"weapon_{weapon}.png").convert("RGBA")
		cut = source.crop(source.getchannel("A").getbbox())
		width = max(2, round(cut.width * HEIGHT / cut.height))
		cut.resize((width, HEIGHT), Image.LANCZOS).save(FOLDER / f"weapon_{weapon}.png")
		print(f"Saved weapon_{weapon}.png ({width}x{HEIGHT})")


if __name__ == "__main__":
	main()
