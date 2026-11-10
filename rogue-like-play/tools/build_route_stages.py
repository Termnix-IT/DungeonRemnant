"""Build the route map's stages and objects from their generated pictures.

art/ui/route/source/plate_<chapter>.png is an oval platform of the chapter's
ground seen a little from above, and prop_<name>.png an object standing on
its base (an event's: altar, curse, merchant, shelf, spring; the start's
signpost: sign), each on a flat magenta (#FF00FF) background. This keys the
magenta out, trims each to what is painted, scales a stage to PLATE_WIDTH
and an object to PROP_HEIGHT (about twice the size RouteNode draws them) and
writes art/ui/route/<name>.png.

With --measure it prints, for each stage, where the middle of its top lies
down the picture and the top's half width: a cylinder seen from above is
widest from the top's middle down, so the first row that nearly reaches the
widest is the top's middle. RouteNode holds these as PLATE_TOP,
TOP_HALF_HEIGHT and TOP_HALF_WIDTH; update them when a picture changes.

	python tools/build_route_stages.py              # everything
	python tools/build_route_stages.py plate_gale_woods prop_sign
	python tools/build_route_stages.py --measure
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
PLATES = ["plate_ash_corridor", "plate_gale_woods", "plate_amethyst_mausoleum", "plate_abyss_of_echoes"]
PROPS = ["prop_altar", "prop_curse", "prop_merchant", "prop_shelf", "prop_spring", "prop_sign"]
PLATE_WIDTH = 440
PROP_HEIGHT = 260
# A row reaching this share of the widest counts as the widest.
NEAR_WIDEST = 0.985


def keyed(name: str) -> Image.Image:
	image = key_out(Image.open(SOURCE / f"{name}.png"), 2)
	box = image.getchannel("A").point(lambda value: 255 if value > 24 else 0).getbbox()
	return image.crop(box)


def build(name: str) -> Path:
	image = keyed(name)
	if name.startswith("plate_"):
		size = (PLATE_WIDTH, round(image.height * PLATE_WIDTH / image.width))
	else:
		size = (round(image.width * PROP_HEIGHT / image.height), PROP_HEIGHT)
	target = OUTPUT / f"{name}.png"
	image.resize(size, Image.Resampling.LANCZOS).save(target)
	return target


def measure(name: str) -> str:
	alpha = np.asarray(keyed(name).getchannel("A")) > 128
	widths = alpha.sum(axis=1)
	widest = widths.max()
	middle = int(np.argmax(widths >= widest * NEAR_WIDEST))
	height, width = alpha.shape
	return f"{name}: PLATE_TOP {middle / height:.3f}  TOP_HALF_HEIGHT {middle / height:.3f}  TOP_HALF_WIDTH {widest / width * 0.5:.3f}  aspect {height / width:.3f}"


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("names", nargs="*", choices=PLATES + PROPS)
	parser.add_argument("--measure", action="store_true")
	arguments = parser.parse_args()
	names = arguments.names or PLATES + PROPS
	for name in names:
		if arguments.measure:
			if name.startswith("plate_"):
				print(measure(name))
			continue
		target = build(name)
		with Image.open(target) as built:
			print(f"{target.relative_to(ROOT)}: {built.width}x{built.height}")


if __name__ == "__main__":
	main()
