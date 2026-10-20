"""Shrink the painted battle effects for combat/strike_effect.gd.

art/effects/painted/source/<kind>.png are stills at each effect's fullest:
light effects painted on black (drawn added, so black adds nothing) and the
death smoke on transparency. Each is shrunk to SIZE px square and written
to art/effects/painted/<kind>.png, mipmapped in Godot. Light effects are
written opaque with their black kept, darkened below NOISE_FLOOR so the
generator's near-black grain adds no haze round the effect.

	python tools/build_painted_effects.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "effects" / "painted" / "source"
OUTPUT = ROOT / "art" / "effects" / "painted"
# About twice the largest an effect is drawn (84 world px, 151 px at
# 1920x1080).
SIZE = 256
SMOKE = {"death"}
NOISE_FLOOR = 10


def main() -> None:
	for source in sorted(SOURCE.glob("*.png")):
		image = Image.open(source)
		if source.stem in SMOKE:
			image = image.convert("RGBA")
		else:
			rgb = np.asarray(image.convert("RGB")).astype(np.float32)
			# Pull the floor of the black down so faint grain adds nothing.
			rgb = np.clip((rgb - NOISE_FLOOR) * 255.0 / (255.0 - NOISE_FLOOR), 0, 255)
			image = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
		image.resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(OUTPUT / source.name)
		print(f"{source.stem}{' (smoke)' if source.stem in SMOKE else ''}")


if __name__ == "__main__":
	main()
