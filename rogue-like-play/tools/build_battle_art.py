"""Build the painted art of the battlefield and the fight.

The originals are pictures Codex generated on flat magenta (the requests are
in docs/絵の制作記録/地形とエフェクトの絵.md), kept beside what they are for:

  art/tiles/painted/source/props_<set>.png  four things that stand on a
                                            field's pillars, in a row (ruin,
                                            ember, crypt, abyss)
  art/tiles/painted/source/floor_decals.png six leavings that lie on the
                                            floor, three by two
  art/effects/painted/source/echo_shards.png the three experience shards
  art/effects/painted/source/boss_sigil.png the boss's sigil, white on black
  art/ui/source/cards.png                   a boon card's face and its back

and the textures the terrain atlases were built from
(art/tiles/painted/source/<theme>_floor.png, _wall.png, torch_sconce.png).
From them this writes, cut off the magenta and sized for the game:

  art/tiles/painted/props_<set>.png      four frames side by side, each
                                         thing on its frame's bottom middle
  art/tiles/painted/floor_decals.png     six frames, three by two
  art/tiles/painted/floors/<theme>_floor.jpg, _wall.jpg
                                         the paving and the wall's stone,
                                         whole (the floor's shader lays them)
  art/tiles/painted/wall_sconce.png      the far wall's torch holder
  art/effects/painted/echo_shards.png    three frames side by side
  art/effects/painted/boss_sigil.png     the sigil as light (white, its
                                         brightness its alpha)
  art/ui/cards/card_face.png, card_back.png

Run it from the Godot project's folder, then import:

  python tools/build_battle_art.py
  python tools/build_battle_art.py --measure   (prints where each set's fire burns)
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from image_boards import cut_board, key_out

ROOT = Path(__file__).resolve().parent.parent
TILES = ROOT / "art" / "tiles" / "painted"
EFFECTS = ROOT / "art" / "effects" / "painted"
UI = ROOT / "art" / "ui"
PROP_SETS = ["ruin", "ember", "crypt", "abyss"]
THEMES = ["slate", "moss", "ember", "sanctum", "grove", "crypt", "abyss"]
# A prop's frame, and how wide the widest thing of its board is drawn in it.
PROP_FRAME = (256, 448)
PROP_BASE = 228
DECAL_FRAME = 256
DECAL_FILL = 236
SHARD_FRAME = (144, 176)
SHARD_FILL = 168
SIGIL_SIZE = 768
CARD_SIZE = (480, 720)
FLOOR_SIZE = 1024
# How bright a theme's paving is on the whole before any light falls on it
# (its mean, 0 to 1), how far a dark one may be brought up to that, and how
# a colour's brightness is weighed.
FLOOR_LEVEL = 0.3
FLOOR_GAIN_MOST = 2.0
LUMA = np.array([0.299, 0.587, 0.114], dtype=np.float32)
WALL_SIZE = 512
SCONCE_WIDTH = 96
JPEG_QUALITY = 88


def solid(image: Image.Image) -> Image.Image:
	return image.getchannel("A").point(lambda value: 255 if value > 24 else 0)


def cropped(image: Image.Image) -> Image.Image:
	return image.crop(solid(image).getbbox())


def runs(there: np.ndarray, least: int) -> list[tuple[int, int]]:
	"""The stretches where something is painted, at least `least` long."""
	found = []
	start = None
	for index, painted in enumerate(there):
		if painted and start is None:
			start = index
		elif not painted and start is not None:
			if index - start >= least:
				found.append((start, index))
			start = None
	if start is not None:
		found.append((start, len(there)))
	return found


def in_a_row(board: Image.Image, count: int) -> list[Image.Image]:
	"""The things on a board side by side, each cut where the board is see-through from top to bottom."""
	found = runs(np.asarray(solid(board)).any(axis=0), 20)
	if len(found) != count:
		raise ValueError(f"the board holds {len(found)} things, not {count}")
	return [cropped(board.crop((left, 0, right, board.height))) for left, right in found]


def props(name: str) -> tuple[Image.Image, list[float]]:
	"""A board's four things on their frames, and how high each stands in its frame (a share of it)."""
	pieces = in_a_row(key_out(Image.open(TILES / "source" / f"props_{name}.png"), 2), 4)
	scale = min(PROP_BASE / max(piece.width for piece in pieces), (PROP_FRAME[1] - 6) / max(piece.height for piece in pieces))
	atlas = Image.new("RGBA", (PROP_FRAME[0] * len(pieces), PROP_FRAME[1]))
	tall = []
	for index, piece in enumerate(pieces):
		piece = piece.resize((max(1, round(piece.width * scale)), max(1, round(piece.height * scale))), Image.LANCZOS)
		atlas.alpha_composite(piece, (index * PROP_FRAME[0] + (PROP_FRAME[0] - piece.width) // 2, PROP_FRAME[1] - piece.height))
		tall.append(piece.height / PROP_FRAME[1])
	return atlas, tall


def build_props() -> list[Path]:
	targets = []
	for name in PROP_SETS:
		if not (TILES / "source" / f"props_{name}.png").exists():
			continue
		atlas, _tall = props(name)
		target = TILES / f"props_{name}.png"
		atlas.save(target)
		targets.append(target)
	return targets


def build_decals() -> list[Path]:
	pieces = cut_board(key_out(Image.open(TILES / "source" / "floor_decals.png"), 2), 2, 3)
	atlas = Image.new("RGBA", (DECAL_FRAME * 3, DECAL_FRAME * 2))
	for index, piece in enumerate(pieces):
		piece = cropped(piece)
		scale = DECAL_FILL / max(piece.size)
		piece = piece.resize((max(1, round(piece.width * scale)), max(1, round(piece.height * scale))), Image.LANCZOS)
		at = ((index % 3) * DECAL_FRAME + (DECAL_FRAME - piece.width) // 2, (index // 3) * DECAL_FRAME + (DECAL_FRAME - piece.height) // 2)
		atlas.alpha_composite(piece, at)
	target = TILES / "floor_decals.png"
	atlas.save(target)
	return [target]


def build_shards() -> list[Path]:
	pieces = in_a_row(key_out(Image.open(EFFECTS / "source" / "echo_shards.png"), 2), 3)
	scale = SHARD_FILL / max(piece.height for piece in pieces)
	atlas = Image.new("RGBA", (SHARD_FRAME[0] * 3, SHARD_FRAME[1]))
	for index, piece in enumerate(pieces):
		piece = piece.resize((max(1, round(piece.width * scale)), max(1, round(piece.height * scale))), Image.LANCZOS)
		atlas.alpha_composite(piece, (index * SHARD_FRAME[0] + (SHARD_FRAME[0] - piece.width) // 2, (SHARD_FRAME[1] - piece.height) // 2))
	target = EFFECTS / "echo_shards.png"
	atlas.save(target)
	return [target]


def build_sigil() -> list[Path]:
	source = EFFECTS / "source" / "boss_sigil.png"
	if not source.exists():
		return []
	grey = np.asarray(Image.open(source).convert("L").resize((SIGIL_SIZE, SIGIL_SIZE), Image.LANCZOS), dtype=np.float32) / 255.0
	# Its brightness is its light: the black of its ground is nothing.
	alpha = np.clip((grey - 0.06) / 0.7, 0.0, 1.0)
	light = np.dstack([np.ones_like(alpha), np.ones_like(alpha), np.ones_like(alpha), alpha])
	target = EFFECTS / "boss_sigil.png"
	Image.fromarray((light * 255.0).round().astype(np.uint8), "RGBA").save(target)
	return [target]


def build_cards() -> list[Path]:
	pieces = in_a_row(key_out(Image.open(UI / "source" / "cards.png"), 2), 2)
	(UI / "cards").mkdir(exist_ok=True)
	targets = []
	for name, piece in zip(["card_face", "card_back"], pieces):
		target = UI / "cards" / f"{name}.png"
		piece.resize(CARD_SIZE, Image.LANCZOS).save(target)
		targets.append(target)
	return targets


def build_stone() -> list[Path]:
	"""The paving and the wall's stone of each theme, whole, and the far wall's torch holder."""
	(TILES / "floors").mkdir(exist_ok=True)
	targets = []
	for theme in THEMES:
		# The themes' stones were painted at different depths of dark; under
		# one light they must start alike, or the darkest places go black.
		# Each theme's paving is brought up to FLOOR_LEVEL (never down), and
		# its wall by as much, so the two keep their relation.
		paving = np.asarray(Image.open(TILES / "source" / f"{theme}_floor.png").convert("RGB"), dtype=np.float32) / 255.0
		gain = float(np.clip(FLOOR_LEVEL / max(float((paving @ LUMA).mean()), 0.01), 1.0, FLOOR_GAIN_MOST))
		for kind, side in [("floor", FLOOR_SIZE), ("wall", WALL_SIZE)]:
			target = TILES / "floors" / f"{theme}_{kind}.jpg"
			stone = np.asarray(Image.open(TILES / "source" / f"{theme}_{kind}.png").convert("RGB"), dtype=np.float32) * gain
			Image.fromarray(np.clip(stone, 0.0, 255.0).round().astype(np.uint8), "RGB").resize((side, side), Image.LANCZOS).save(target, quality=JPEG_QUALITY)
			targets.append(target)
	sconce = Image.open(TILES / "source" / "torch_sconce.png").convert("RGBA")
	sconce = sconce.crop(sconce.getchannel("A").point(lambda value: 255 if value > 96 else 0).getbbox())
	target = TILES / "wall_sconce.png"
	sconce.resize((SCONCE_WIDTH, round(sconce.height * SCONCE_WIDTH / sconce.width)), Image.LANCZOS).save(target)
	return targets + [target]


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--measure", action="store_true", help="print how high each set's things stand in their frames, and write nothing")
	arguments = parser.parse_args()
	if arguments.measure:
		for name in PROP_SETS:
			if (TILES / "source" / f"props_{name}.png").exists():
				_atlas, tall = props(name)
				print(name, "stand", " ".join(f"{share:.3f}" for share in tall), "of their frames")
		return
	for build in [build_props, build_decals, build_shards, build_sigil, build_cards, build_stone]:
		for target in build():
			with Image.open(target) as written:
				print(f"{target.relative_to(ROOT)}  {written.width}x{written.height}")


if __name__ == "__main__":
	main()
