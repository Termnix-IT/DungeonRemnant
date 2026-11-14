"""Turn the generated parchment and leather into the status book's grain.

Reads art/ui/source/grimoire/paper_<variant>.png and leather_<variant>.png
(flat faces from Codex's image generation) and writes art/ui/grimoire/paper.png
and leather.png, which the book's shader (ui/grimoire/grimoire_book.gdshader)
lays over the two pages and the cover.

The outputs keep only the faces' detail, not their colour: the shader mixes
the theme's page_dark and page_light (cover_dark and cover_light) by the
grain, so the book's colours stay the theme's and its words keep the contrast
test_ui_theme checks. So each face is
- flattened: a blurred copy is divided out, removing any light falloff the
  generation left, which would read as a lit patch on the page;
- turned to grey and normalised to a mid grey with a set spread (CONTRAST);
  values are clipped to 0..1, the range the shader mixes over;
- scaled to the size it is shown at on the 1920x1080 screen.

The paper is laid once across the whole spread (it does not tile); the
leather is mirrored where it repeats, so neither needs to be seamless.

	python tools/build_grimoire_art.py [paper variant] [leather variant]
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source" / "grimoire"
OUTPUT = ROOT / "art" / "ui" / "grimoire"

# Radius of the blur divided out to flatten the light, as a share of the width.
FLATTEN = 0.12
# Output sizes: the spread's two pages at 1920x1080, and a leather tile.
PAPER_SIZE = (1608, 790)
LEATHER_SIZE = (768, 512)
# The spread of the grain round mid grey (one standard deviation). The paper
# is kept quiet so the ink reads everywhere; the leather can be rougher.
PAPER_CONTRAST = 0.15
LEATHER_CONTRAST = 0.22


def grain(path: Path, size: tuple[int, int], contrast: float) -> Image.Image:
	face = Image.open(path).convert("RGB")
	# Cover the output's shape from the middle of the face.
	scale = max(size[0] / face.width, size[1] / face.height)
	face = face.resize((round(face.width * scale), round(face.height * scale)), Image.LANCZOS)
	left = (face.width - size[0]) // 2
	top = (face.height - size[1]) // 2
	face = face.crop((left, top, left + size[0], top + size[1]))
	grey = np.asarray(face.convert("L"), dtype=np.float64) / 255.0
	blurred = np.asarray(face.convert("L").filter(ImageFilter.GaussianBlur(size[0] * FLATTEN)), dtype=np.float64) / 255.0
	flat = grey / np.maximum(blurred, 1e-3)
	flat = (flat - flat.mean()) / max(flat.std(), 1e-6)
	out = np.clip(0.5 + flat * contrast, 0.0, 1.0)
	return Image.fromarray(np.round(out * 255.0).astype(np.uint8), "L")


def main() -> None:
	paper = sys.argv[1] if len(sys.argv) > 1 else "a"
	leather = sys.argv[2] if len(sys.argv) > 2 else "a"
	OUTPUT.mkdir(parents=True, exist_ok=True)
	grain(SOURCE / f"paper_{paper}.png", PAPER_SIZE, PAPER_CONTRAST).save(OUTPUT / "paper.png")
	grain(SOURCE / f"leather_{leather}.png", LEATHER_SIZE, LEATHER_CONTRAST).save(OUTPUT / "leather.png")
	print(f"wrote paper ({paper}) and leather ({leather}) to {OUTPUT.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
	main()
