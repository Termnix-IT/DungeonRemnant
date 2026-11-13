"""Cut the bestiary's standing portraits from their painted sources.

Each source in art/enemies/codex/source/<visual id>.png is one foe painted
whole, turned three-quarters toward the image's left, on a transparent
canvas (or flat magenta, keyed out here). It is cut to its opaque extent
with a little margin and shrunk to at most HEIGHT px tall as
art/enemies/codex/<visual id>.png, which the bestiary stands on its stage
(EnemySprites.codex_portrait()). Its import makes mipmaps, since the
stage draws it smaller than this.

	python tools/build_codex_portraits.py [visual id ...]
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

from image_boards import key_out

ROOT = Path(__file__).resolve().parent.parent
FOLDER = ROOT / "art" / "enemies" / "codex"
# About the tallest the stage draws it at 1920x1080 (about 600 px).
HEIGHT = 640
# Clear pixels kept round the figure, as a share of the cut's height.
MARGIN = 0.02
# Alpha below this is the generator's faint haze, not the figure.
HAZE = 24


def is_magenta(image: Image.Image) -> bool:
	rgba = np.asarray(image.convert("RGBA")).astype(int)
	if rgba[..., 3].min() < 250:
		return False
	edge = np.concatenate([rgba[0], rgba[-1], rgba[:, 0], rgba[:, -1]])
	return bool(np.median(edge[:, 0]) > 200 and np.median(edge[:, 1]) < 80 and np.median(edge[:, 2]) > 200)


def build(source: Path) -> None:
	image = Image.open(source).convert("RGBA")
	if is_magenta(image):
		image = key_out(image, 6)
	pixels = np.asarray(image).copy()
	pixels[pixels[..., 3] < HAZE, 3] = 0
	image = Image.fromarray(pixels)
	box = image.getchannel("A").getbbox()
	if box is None:
		print(f"Skipped {source.name}: nothing opaque")
		return
	cut = image.crop(box)
	pad = round(cut.height * MARGIN)
	framed = Image.new("RGBA", (cut.width + pad * 2, cut.height + pad * 2))
	framed.paste(cut, (pad, pad))
	if framed.height > HEIGHT:
		width = max(2, round(framed.width * HEIGHT / framed.height))
		framed = framed.resize((width, HEIGHT), Image.LANCZOS)
	target = FOLDER / source.name
	framed.save(target)
	print(f"Saved {target.name} ({framed.width}x{framed.height})")


def main() -> None:
	wanted = set(sys.argv[1:])
	for source in sorted((FOLDER / "source").glob("*.png")):
		name = source.stem
		if wanted and name not in wanted:
			continue
		build(source)


if __name__ == "__main__":
	main()
