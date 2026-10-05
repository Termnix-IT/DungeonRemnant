"""Build the stage-select map's dioramas from their generated pictures.

art/hub/source/diorama_<stage>.png is the dungeon on an oval floating island,
painted on a flat magenta (#FF00FF) background. This keys the magenta out
with a soft edge, removes the magenta that bled into the edge pixels, trims
to the island with a small margin, scales to SIZE pixels square and writes
art/hub/dioramas/<stage>.png, which StageData.diorama points at.

	python tools/build_stage_dioramas.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "hub" / "source"
OUTPUT = ROOT / "art" / "hub" / "dioramas"
STAGES = ["ancient_ruins", "forest", "unknown"]
SIZE = 640
MARGIN = 0.03
KEY = np.array([1.0, 0.0, 1.0])
# Distance from the key colour below which a pixel is background, and above
# which it is wholly the island; between them it fades.
CLEAR = 0.32
SOLID = 0.62
# How far in from the edge, in source pixels, magenta that the painting
# itself picked up (leaves tinted pink) is taken out; the forest has no
# violet of its own, so it is cleaned deep. The sealed dungeon is
# violet on purpose, so it keeps its colour.
# From this reach on, violet within the picture is the backdrop's too.
LEAF_REACH = 60
SPILL_REACH = {"ancient_ruins": 10, "forest": 60, "unknown": 0}


def key_out(image: Image.Image, reach: int) -> Image.Image:
	rgb = np.asarray(image.convert("RGB"), dtype=np.float32) / 255.0
	# Magenta is strong red and blue with little green: measure how far a
	# pixel is from it, weighting the green that magenta lacks.
	distance = np.sqrt(((rgb - KEY) ** 2 * np.array([1.0, 1.6, 1.0])).sum(axis=2))
	alpha = np.clip((distance - CLEAR) / (SOLID - CLEAR), 0.0, 1.0)
	# Edge pixels are part magenta: take the key's share back out.
	share = (1.0 - alpha)[..., None]
	colour = np.clip((rgb - KEY * share) / np.maximum(alpha[..., None], 1e-3), 0.0, 1.0)
	# What magenta tint survives (red and blue above green) is pulled down.
	spill = np.clip(np.minimum(colour[..., 0], colour[..., 2]) - colour[..., 1], 0.0, None)
	edge = alpha < 0.98
	if reach > 0:
		# Grow the see-through region inwards to reach the tinted rim.
		clear = Image.fromarray(((alpha < 0.98) * 255).astype(np.uint8))
		edge = np.asarray(clear.filter(ImageFilter.MaxFilter(reach * 2 + 1))) > 0
	colour = np.where(edge[..., None], colour - spill[..., None] * np.array([1.0, 0.0, 1.0]), colour)
	if reach >= LEAF_REACH:
		# Leaves shaded violet by the backdrop's bounce turn to the green
		# they would have been: red and blue no higher than the green.
		violet = (colour[..., 0] > colour[..., 1]) & (colour[..., 2] > colour[..., 1])
		green = colour[..., 1:2]
		cooled = np.concatenate([np.minimum(colour[..., 0:1], green * 0.9), green, np.minimum(colour[..., 2:3], green * 1.05)], axis=2)
		colour = np.where(violet[..., None], cooled, colour)
		# Indigo is the same bounce on teal leaves: blue no higher than green.
		colour[..., 2] = np.minimum(colour[..., 2], colour[..., 1] * 1.05)
	result = np.dstack([np.clip(colour, 0.0, 1.0), alpha])
	return Image.fromarray((result * 255.0).round().astype(np.uint8), "RGBA")


def build(stage: str) -> None:
	keyed = key_out(Image.open(SOURCE / f"diorama_{stage}.png"), SPILL_REACH[stage])
	box = keyed.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
	keyed = keyed.crop(box)
	side = int(max(keyed.size) * (1.0 + MARGIN * 2))
	square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
	square.paste(keyed, ((side - keyed.width) // 2, (side - keyed.height) // 2))
	OUTPUT.mkdir(parents=True, exist_ok=True)
	square.resize((SIZE, SIZE), Image.LANCZOS).save(OUTPUT / f"{stage}.png")


if __name__ == "__main__":
	for name in STAGES:
		build(name)
		print("wrote", OUTPUT / f"{name}.png")
