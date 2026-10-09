"""Turn the generated stone face into the hub slabs' tiled texture.

Reads art/ui/source/slab_stone_<variant>.png (a square stone face from Codex's
image generation, meant to tile) and writes art/ui/slab_stone.png, which
SlabStyle tiles over the dark slabs at low strength (`grain` and `grain_tint`
in ui/theme/dungeon_theme.tres).

The output keeps only the stone's detail, not its overall tone: the slab's own
fill decides how dark it is. So the face is
- made seamless: a generated tile can still show a faint seam, so the tile is
  blended with itself shifted by half its size across a soft cross, which
  moves any seam away from the edges and fades it out;
- flattened: a blurred copy is divided out, removing any light falloff or
  vignette that would show as a grid of bright and dark squares when tiled;
- desaturated towards the hall's warm graphite and normalised to a mid grey
  with a set standard deviation (CONTRAST, as a share of the mean), so the
  Theme's grain_tint, which multiplies it down to the slab's darkness, alone
  sets how dark the stone is;
- scaled to TILE px, the size it repeats at on the 1600x900 base.

	python tools/build_slab_texture.py [a|b] [contrast]
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source"
OUTPUT = ROOT / "art" / "ui" / "slab_stone.png"

TILE = 384
# Radius of the blur divided out to flatten the light, as a share of the size.
FLATTEN = 0.08
# Grey the detail sits on, and its spread as a share of it. On a slab this
# dark only a large relative spread shows at all.
MID = 0.5
CONTRAST = 0.5
# How much of the stone's own colour stays (0 is grey); the rest is the
# hall's warm graphite tint.
KEEP_COLOUR = 0.25
TINT = np.array([1.0, 0.94, 0.86])


def seamless(image: np.ndarray) -> np.ndarray:
	size = image.shape[0]
	shifted = np.roll(np.roll(image, size // 2, axis=0), size // 2, axis=1)
	# 1 at the tile's centre, 0 at its edges: the original is kept in the
	# middle and the shifted copy, whose seam runs through the middle, at the
	# edges, where it wraps onto its own continuation.
	ramp = 1.0 - np.abs(np.linspace(-1.0, 1.0, size))
	ramp = np.clip(ramp * 2.0, 0.0, 1.0)
	weight = np.minimum.outer(ramp, ramp)[..., None]
	return image * weight + shifted * (1.0 - weight)


def flatten(image: np.ndarray) -> np.ndarray:
	size = image.shape[0]
	tiled = np.tile(image, (3, 3, 1))
	blurred = Image.fromarray(np.clip(tiled * 255.0, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(size * FLATTEN))
	light = np.asarray(blurred, dtype=np.float64)[size:size * 2, size:size * 2] / 255.0
	return image / np.maximum(light, 0.02) * light.mean(axis=(0, 1))


def main() -> None:
	variant = sys.argv[1] if len(sys.argv) > 1 else "a"
	contrast = float(sys.argv[2]) if len(sys.argv) > 2 else CONTRAST
	image = np.asarray(Image.open(SOURCE / f"slab_stone_{variant}.png").convert("RGB"), dtype=np.float64) / 255.0
	side = min(image.shape[0], image.shape[1])
	image = image[:side, :side]
	image = flatten(seamless(image))
	grey = image.mean(axis=2, keepdims=True)
	image = grey * (1.0 - KEEP_COLOUR) * TINT + image * KEEP_COLOUR
	luminance = image.mean(axis=2, keepdims=True)
	scale = MID * contrast / max(luminance.std(), 1e-6)
	image = MID + (image - luminance.mean()) * scale
	# Scaled as a 3x3 tiling and cut from the middle, so the filter reads
	# across the wrapped edges and the tile stays seamless.
	tiled = Image.fromarray(np.clip(np.tile(image, (3, 3, 1)) * 255.0, 0, 255).astype(np.uint8)).resize((TILE * 3, TILE * 3), Image.LANCZOS)
	tiled.crop((TILE, TILE, TILE * 2, TILE * 2)).save(OUTPUT)
	print(f"Wrote {OUTPUT.relative_to(ROOT)} from slab_stone_{variant}.png")


if __name__ == "__main__":
	main()
