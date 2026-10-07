"""Build the boss floor's passage art from its generated pictures.

art/tiles/source/<name>.png is one object painted on a flat magenta (#FF00FF)
background: the guardian's door (antechamber to boss hall), the stairs on to
the next floor (where the boss stood) and the door back to the base (the
escape exit). Each is keyed, trimmed, fitted inside one 48px tile as pixel art
with the sprites' 1px dark outline, and written to art/tiles/<name>.png at 2x
with nearest scaling, so it is drawn over the floor tile at one art pixel per
two texture pixels.

	python tools/build_passage_art.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from build_stage_dioramas import key_out
from process_enemy_sheet import add_outline, downscale

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "tiles" / "source"
OUTPUT = ROOT / "art" / "tiles"
PASSAGES = ["guardian_door", "descent_stairs", "return_door"]
TILE = 48
# The outline adds one pixel on each side, so the art fits inside TILE - 2.
FIT = TILE - 2
STORED_SCALE = 2
SPILL_REACH = 2


def build(name: str) -> Image.Image:
	keyed = key_out(Image.open(SOURCE / f"{name}.png"), SPILL_REACH)
	box = keyed.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
	keyed = keyed.crop(box)
	pixel_art = add_outline(downscale(keyed, FIT / max(keyed.size)))
	tile = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
	tile.alpha_composite(pixel_art, ((TILE - pixel_art.width) // 2, (TILE - pixel_art.height) // 2))
	return tile.resize((TILE * STORED_SCALE, TILE * STORED_SCALE), Image.Resampling.NEAREST)


if __name__ == "__main__":
	for passage in PASSAGES:
		build(passage).save(OUTPUT / f"{passage}.png")
		print("wrote", OUTPUT / f"{passage}.png")
