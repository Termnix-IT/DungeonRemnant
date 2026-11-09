"""Build the route map's roads from their generated pictures.

art/ui/route/source/road_<chapter>.png is a straight road painted from
above, running across the whole picture on a flat magenta (#FF00FF)
background. RouteMapView repeats a road along each path with a Line2D, so the
road has to join itself end to end. This keys the magenta out, trims the
picture to the road's band, cross-fades its ends so the right end runs on
into the left (the generator does not join them exactly), scales it to
HEIGHT and writes art/ui/route/road_<chapter>.png.

	python tools/build_route_roads.py                 # every chapter
	python tools/build_route_roads.py gale_woods      # one chapter
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from image_boards import key_out

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "route" / "source"
OUTPUT = ROOT / "art" / "ui" / "route"
CHAPTERS = ["ash_corridor", "gale_woods", "amethyst_mausoleum", "abyss_of_echoes"]
# The road's height once built; the Line2D draws it about a quarter of this.
HEIGHT = 128
# The share of the width cross-faded to join the ends.
OVERLAP = 0.2
# A row belongs to the band when this share of it is painted.
BAND_COVER = 0.02


def build(chapter: str) -> Path:
	keyed = key_out(Image.open(SOURCE / f"road_{chapter}.png"), 2)
	pixels = np.asarray(keyed, dtype=np.float32) / 255.0
	cover = (pixels[..., 3] > 0.5).mean(axis=1)
	rows = np.nonzero(cover > BAND_COVER)[0]
	band = pixels[rows[0]:rows[-1] + 1]
	width = band.shape[1]
	overlap = int(width * OVERLAP)
	tile = band[:, :width - overlap].copy()
	# The first `overlap` columns fade from the picture's right end into its
	# own left, so the tile's last column runs on into its first.
	weight = (np.arange(overlap, dtype=np.float32) / overlap)[None, :, None]
	ends = band[:, width - overlap:]
	starts = band[:, :overlap]
	# Mixed with premultiplied alpha, so a see-through edge brings no colour.
	alpha = ends[..., 3:] * (1.0 - weight) + starts[..., 3:] * weight
	colour = ends[..., :3] * ends[..., 3:] * (1.0 - weight) + starts[..., :3] * starts[..., 3:] * weight
	tile[:, :overlap, :3] = np.where(alpha > 1e-4, colour / np.maximum(alpha, 1e-4), 0.0)
	tile[:, :overlap, 3:] = alpha
	image = Image.fromarray((np.clip(tile, 0.0, 1.0) * 255.0).round().astype(np.uint8), "RGBA")
	scaled = image.resize((round(image.width * HEIGHT / image.height), HEIGHT), Image.Resampling.LANCZOS)
	target = OUTPUT / f"road_{chapter}.png"
	scaled.save(target)
	return target


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("chapters", nargs="*", choices=CHAPTERS)
	chosen = parser.parse_args().chapters or CHAPTERS
	for chapter in chosen:
		target = build(chapter)
		with Image.open(target) as built:
			print(f"{target.relative_to(ROOT)}: {built.width}x{built.height}")


if __name__ == "__main__":
	main()
