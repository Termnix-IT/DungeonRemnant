"""Cut the painted emblem boards into ability and upgrade emblems.

Each board in art/emblems/painted/source/ is a grid of round medallions on
flat magenta, in the order listed in BOARDS. Every medallion is cut out (its
edge pulled in by EDGE_TRIM px so no magenta fringe stays), centred in a
square and shrunk to SIZE px as art/emblems/<key>.png, which Godot imports
with mipmaps and the UI draws with mipmapped linear filtering. The data
names its emblem by key (BoonData.emblem, MetaUpgrade.emblem); see
ui/emblem_icons.gd. The first two boards were drawn for the turn-based
game's abilities; c and d hold the boons' and the lasting upgrades' own,
and e to g the upgrade tree's nodes and the seals of its branches to come.
Boards h to k hold combat upgrades, special moves, events and chapter seals.

	python tools/process_emblems.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter

from build_painted_objects import square
from image_boards import cut_board

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
	("emblems_c.png", 2, 3, ["thunder_blade", "chain_lightning", "whirlwind", "afterimage", "shockwave", "great_charge"]),
	("emblems_d.png", 2, 2, ["hellfire", "blade_speed", "double_dash", "parting_blessing"]),
	("emblems_e.png", 2, 3, ["echo_lantern", "firm_guard", "steady_recovery", "last_stand", "healing_lore", "dash_recovery"]),
	("emblems_f.png", 2, 3, ["triple_dash", "light_step", "gem_magnet", "quick_study", "reroll", "fourth_card"]),
	("emblems_g.png", 2, 3, ["rising_heal", "rising_burst", "rising_ward", "rising_haste", "seal_skill", "seal_special"]),
	("emblems_h.png", 2, 3, ["brute_force", "follow_up", "long_reach", "rending_charge", "life_feast", "riposte"]),
	("emblems_i.png", 2, 3, ["keen_art", "gale_step", "discharge", "thunder_step", "aftershock", "flame_art"]),
	("emblems_j.png", 2, 3, ["thunder_flash", "swallow_cut", "blaze_ring", "skill_drill", "echo_burst", "sky_rend"]),
	("emblems_k.png", 2, 3, ["special_surge", "special_mastery", "event_merchant", "event_altar", "event_curse", "seal_chapter"]),
	("emblems_l.png", 1, 2, ["weapon_spear", "weapon_hammer"]),
	("emblems_m.png", 1, 1, ["weapon_sword"]),
	("emblems_n.png", 2, 3, ["spirit_blade", "crescent_cut", "shatter_crystal", "spreading_flame", "thunder_charge", "wisp_step"]),
	("emblems_o.png", 1, 2, ["wisp_shot", "event_shelf"]),
	("emblems_p.png", 2, 3, ["thunder_art", "healing_form", "gale_blade", "thunder_riposte", "echo_edge", "combo_mastery"]),
	("emblems_q.png", 1, 3, ["thunder_circle", "crimson_lotus", "event_spring"]),
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
