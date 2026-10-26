"""Write the rig descriptions of the enemies drawn as one bent picture.

For each enemy in build_rig_parts.ENEMY_MESHES whose base exists, this reads
the outline of art/enemies/rig/source/<id>_base.png and writes
art/enemies/rig/<id>_rig.json for tools/build_character_rig.gd: bones laid
out over the outline by its kind of body, the picture as one mesh weighted
along them, and the motions every enemy rig has (idle, walk, attack_sword
with its blow at 0.09 s, hurt, down, brace). Movements are shares of the
outline's size, so a rat and a boss move alike for their size. Every rig
faces right; the enemy mirrors it.

	python tools/write_enemy_rigs.py [id ...]

Then cut the parts (python tools/build_rig_parts.py enemies) and build each
rig. Positions are source pixels; rotations degrees, positive turning the
top towards the right (forward).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

from build_rig_parts import ENEMY_MESHES

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "enemies" / "rig" / "source"
OUTPUT = ROOT / "art" / "enemies" / "rig"
IMPACT = 0.09
# World px each enemy stands, from the sole to the top: the heights their
# retired pixel strips' bodies had (the strip at 0.8 of its pixels), so the painted
# enemies keep the sizes they were designed at. The fallback boss, which had
# no strip, stands as tall as the named bosses.
HEIGHTS = {
	"proximity": 30.4, "fast": 34.4, "charge": 40.8, "summoner": 39.2, "turret": 43.2,
	# Chapter two's kin stand as tall as the chapter-one foes they are kin of.
	"moss_sentinel": 60.0, "gale_rat": 34.4, "spore_swell": 30.4,
	# Chapter three's crowd: a skeleton as tall as a sentinel, a wisp a little
	# taller than a swell, for its flames.
	"skeleton": 60.0, "wisp": 38.0,
	"boss_stone_gate": 87.2, "boss_gale_warden": 89.6, "boss_cannon_watcher": 87.2,
	"boss_summoning_priest": 89.6, "boss_ruin_king": 88.8, "boss_root_warden": 91.2,
	"boss_gale_wolf_king": 92.0, "boss_spore_cannon": 90.4, "boss_swarm_lord": 92.0,
	"boss_ancient_tree_king": 89.6, "boss": 88,
}


def outline(name: str) -> tuple[float, float, float, float]:
	alpha = Image.open(SOURCE / f"{name}_base.png").convert("RGBA").getchannel("A")
	return alpha.point(lambda v: 255 if v > 24 else 0).getbbox()


def bone(name: str, at: list[float], parent: str | None = None, **extra) -> dict:
	entry = {"name": name}
	if parent:
		entry["parent"] = parent
	entry["at"] = [round(at[0]), round(at[1])]
	entry.update(extra)
	return entry


def keys(*pairs) -> list:
	return [[time, value] for time, value in pairs]


def move(dx: float, dy: float) -> list[float]:
	return [round(dx), round(dy)]


def upright(x0, y0, x1, y1) -> dict:
	w, h, cx = x1 - x0, y1 - y0, (x0 + x1) / 2
	bones = [bone("Root", [cx, y1]), bone("Body", [cx, y1 - 0.3 * h], "Root"),
		bone("Top", [cx, y1 - 0.65 * h], "Body", tip=[round(cx), y0])]
	part = {"name": "Body", "bones": ["Root", "Body", "Top"], "grid": [6, 8], "weights": "along", "tip": [round(cx), y0]}
	animations = {
		"idle": {"length": 2.4, "loop": True, "tracks": {
			"Body:scale": keys((0.0, [1, 1]), (1.2, [1.015, 1.03]), (2.4, [1, 1])),
			"Top:rotation": keys((0.0, 0), (1.2, 1.5), (2.4, 0))}},
		"walk": {"length": 0.4, "loop": True, "tracks": {
			"Root:position": keys((0.0, move(0, 0)), (0.1, move(0, -0.04 * h)), (0.2, move(0, 0)), (0.3, move(0, -0.04 * h)), (0.4, move(0, 0))),
			"Root:rotation": keys((0.0, 0), (0.1, 2), (0.2, 0), (0.3, -2), (0.4, 0))}},
		"attack_sword": {"length": 0.45, "impact": IMPACT, "tracks": {
			"Root:position": keys((0.0, move(0, 0)), (0.05, move(-0.05 * w, 0)), (IMPACT, move(0.08 * w, 0)), (0.18, move(0.06 * w, 0)), (0.45, move(0, 0))),
			"Body:rotation": keys((0.0, 0), (0.05, -4), (IMPACT, 6), (0.18, 5), (0.45, 0)),
			"Top:rotation": keys((0.0, 0), (0.05, -12), (IMPACT, 16), (0.18, 12), (0.45, 0))}},
		"hurt": {"length": 0.3, "tracks": {
			"Root:position": keys((0.0, move(0, 0)), (0.06, move(-0.06 * w, 0)), (0.3, move(0, 0))),
			"Body:scale": keys((0.0, [1, 1]), (0.06, [1.05, 0.95]), (0.3, [1, 1])),
			"Top:rotation": keys((0.0, 0), (0.06, -10), (0.3, 0))}},
		# Topples backward about its feet and stays down.
		"down": {"length": 0.4, "tracks": {
			"Root:rotation": keys((0.0, 0), (0.12, -15), (0.4, -85)),
			"Top:rotation": keys((0.0, 0), (0.4, -8))}},
		"brace": {"length": 0.8, "loop": True, "tracks": {
			"Body:scale": keys((0.0, [1.04, 0.95]), (0.4, [1.05, 0.94]), (0.8, [1.04, 0.95])),
			"Top:rotation": keys((0.0, -9), (0.4, -11), (0.8, -9))}},
	}
	return {"bones": bones, "parts": [part], "animations": animations}


def blob(x0, y0, x1, y1) -> dict:
	w, h, cx = x1 - x0, y1 - y0, (x0 + x1) / 2
	bones = [bone("Root", [cx, y1]), bone("Body", [cx, y1 - 0.5 * h], "Root", tip=[round(cx), y0])]
	part = {"name": "Body", "bones": ["Root", "Body"], "grid": [7, 5], "weights": "along", "tip": [round(cx), y0]}
	animations = {
		"idle": {"length": 1.8, "loop": True, "tracks": {
			"Root:scale": keys((0.0, [1, 1]), (0.9, [1.06, 0.93]), (1.8, [1, 1])),
			"Body:rotation": keys((0.0, 0), (0.9, 2), (1.8, 0))}},
		"walk": {"length": 0.4, "loop": True, "tracks": {
			"Root:scale": keys((0.0, [1.1, 0.88]), (0.1, [0.94, 1.08]), (0.2, [1.1, 0.88]), (0.3, [0.94, 1.08]), (0.4, [1.1, 0.88])),
			"Root:position": keys((0.0, move(0, 0)), (0.1, move(0, -0.12 * h)), (0.2, move(0, 0)), (0.3, move(0, -0.12 * h)), (0.4, move(0, 0)))}},
		"attack_sword": {"length": 0.45, "impact": IMPACT, "tracks": {
			"Root:scale": keys((0.0, [1, 1]), (0.05, [1.12, 0.85]), (IMPACT, [0.9, 1.12]), (0.18, [1.05, 0.95]), (0.45, [1, 1])),
			"Root:position": keys((0.0, move(0, 0)), (0.05, move(-0.04 * w, 0)), (IMPACT, move(0.12 * w, 0)), (0.18, move(0.08 * w, 0)), (0.45, move(0, 0))),
			"Body:rotation": keys((0.0, 0), (0.05, -6), (IMPACT, 12), (0.18, 8), (0.45, 0))}},
		"hurt": {"length": 0.3, "tracks": {
			"Root:scale": keys((0.0, [1, 1]), (0.06, [1.15, 0.8]), (0.3, [1, 1])),
			"Root:position": keys((0.0, move(0, 0)), (0.06, move(-0.05 * w, 0)), (0.3, move(0, 0)))}},
		# Flattens into the floor and stays there.
		"down": {"length": 0.35, "tracks": {
			"Root:scale": keys((0.0, [1, 1]), (0.1, [1.15, 0.7]), (0.35, [1.3, 0.22]))}},
		"brace": {"length": 0.6, "loop": True, "tracks": {
			"Root:scale": keys((0.0, [1.08, 0.9]), (0.3, [1.11, 0.87]), (0.6, [1.08, 0.9]))}},
	}
	return {"bones": bones, "parts": [part], "animations": animations}


def beast(x0, y0, x1, y1) -> dict:
	w, h, cx = x1 - x0, y1 - y0, (x0 + x1) / 2
	middle = y1 - 0.45 * h
	bones = [bone("Root", [cx, y1]), bone("Hind", [x0 + 0.25 * w, middle], "Root"),
		bone("Fore", [x0 + 0.6 * w, middle], "Hind"), bone("Head", [x0 + 0.82 * w, middle], "Fore", tip=[x1, round(middle)])]
	part = {"name": "Body", "bones": ["Hind", "Fore", "Head"], "grid": [8, 5], "weights": "along", "tip": [x1, round(middle)]}
	animations = {
		"idle": {"length": 1.6, "loop": True, "tracks": {
			"Fore:scale": keys((0.0, [1, 1]), (0.8, [1.0, 1.035]), (1.6, [1, 1])),
			"Head:rotation": keys((0.0, 0), (0.8, 2.5), (1.6, 0))}},
		"walk": {"length": 0.4, "loop": True, "tracks": {
			"Root:position": keys((0.0, move(0, 0)), (0.1, move(0, -0.06 * h)), (0.2, move(0, 0)), (0.3, move(0, -0.06 * h)), (0.4, move(0, 0))),
			"Hind:rotation": keys((0.0, 0), (0.1, 2), (0.2, 0), (0.3, -2), (0.4, 0)),
			"Head:rotation": keys((0.0, 0), (0.1, -3), (0.2, 0), (0.3, 3), (0.4, 0))}},
		"attack_sword": {"length": 0.45, "impact": IMPACT, "tracks": {
			"Root:position": keys((0.0, move(0, 0)), (0.05, move(-0.06 * w, 0)), (IMPACT, move(0.14 * w, 0)), (0.18, move(0.1 * w, 0)), (0.45, move(0, 0))),
			"Hind:rotation": keys((0.0, 0), (0.05, 3), (IMPACT, -3), (0.18, -2), (0.45, 0)),
			"Head:rotation": keys((0.0, 0), (0.05, -8), (IMPACT, 10), (0.18, 8), (0.45, 0))}},
		"hurt": {"length": 0.3, "tracks": {
			"Root:position": keys((0.0, move(0, 0)), (0.06, move(-0.06 * w, 0)), (0.3, move(0, 0))),
			"Head:rotation": keys((0.0, 0), (0.06, -12), (0.3, 0))}},
		# Slumps onto the floor, the head dropping, and stays down.
		"down": {"length": 0.4, "tracks": {
			"Root:scale": keys((0.0, [1, 1]), (0.15, [1.03, 0.8]), (0.4, [1.06, 0.55])),
			"Head:rotation": keys((0.0, 0), (0.4, 20))}},
		# Lowers the head and draws back for a charge.
		"brace": {"length": 0.6, "loop": True, "tracks": {
			"Root:position": keys((0.0, move(-0.04 * w, 0)), (0.3, move(-0.05 * w, 0)), (0.6, move(-0.04 * w, 0))),
			"Hind:rotation": keys((0.0, 4), (0.3, 5), (0.6, 4)),
			"Head:rotation": keys((0.0, 6), (0.3, 8), (0.6, 6))}},
	}
	return {"bones": bones, "parts": [part], "animations": animations}


KINDS = {"upright": upright, "blob": blob, "beast": beast}


def write(name: str) -> None:
	rig = {
		"name": "".join(piece.capitalize() for piece in name.split("_")) + "Rig",
		"layout": f"res://art/enemies/rig/{name}_parts.json",
		"atlas": f"res://art/enemies/rig/{name}_parts.png",
		"output": f"res://art/enemies/rig/{name}_rig.tscn",
		# No sword; the lean turns the body.
		"lean_bone": "Body" if ENEMY_MESHES[name] != "beast" else "Fore",
	}
	rig["height"] = HEIGHTS[name]
	rig.update(KINDS[ENEMY_MESHES[name]](*outline(name)))
	(OUTPUT / f"{name}_rig.json").write_text(json.dumps(rig, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
	print(f"Wrote {name}_rig.json ({ENEMY_MESHES[name]})")


def main() -> None:
	names = sys.argv[1:] or [name for name in ENEMY_MESHES if (SOURCE / f"{name}_base.png").exists()]
	for name in names:
		write(name)


if __name__ == "__main__":
	main()
