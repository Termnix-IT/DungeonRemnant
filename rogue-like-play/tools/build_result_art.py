"""Build the paintings behind the run's result.

The originals are pictures Codex generated, kept in art/ui/result/source/
(the requests are in docs/絵の制作記録/拠点とUIの絵.md):

  result_victory.png  the last hall's great door open on the dawn
  result_defeat.png   her sword left standing in a broken floor, in the dark
  result_retreat.png  the corridor she turns back along, its way out far off

From them this writes art/ui/result/victory.png, defeat.png and retreat.png:
each cut to the screen's 16:9 (the rows named in CUTS), sized to 1920x1080,
and with the side the words stand on (the left) settled a little darker so
they read over it. The result's screen (RunEndView) lights and moves them
with its shader; nothing of that is painted in here.

Run it from the Godot project's folder, then import:

  python tools/build_result_art.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RESULT = ROOT / "art" / "ui" / "result"
SOURCE = RESULT / "source"
SIZE = (1920, 1080)
# The first row of each painting kept (of its 1024; 864 rows make 16:9).
CUTS = {"victory": 40, "defeat": 126, "retreat": 60}
# How far the left is settled (0: untouched), and where it ends (a share of
# the width).
SETTLE = {"victory": (0.12, 0.5), "defeat": (0.0, 0.5), "retreat": (0.1, 0.48)}


def build(name: str) -> Path:
	painting = Image.open(SOURCE / f"result_{name}.png").convert("RGB")
	width, height = painting.size
	rows = round(width * SIZE[1] / SIZE[0])
	top = min(CUTS[name], height - rows)
	cut = painting.crop((0, top, width, top + rows)).resize(SIZE, Image.LANCZOS)
	amount, reach = SETTLE[name]
	if amount > 0.0:
		pixels = np.asarray(cut, dtype=np.float32)
		along = np.linspace(0.0, 1.0, SIZE[0], dtype=np.float32)[None, :, None]
		ease = np.clip(1.0 - along / reach, 0.0, 1.0)
		ease = ease * ease * (3.0 - 2.0 * ease)
		pixels *= 1.0 - amount * ease
		cut = Image.fromarray(np.clip(pixels, 0.0, 255.0).astype(np.uint8))
	target = RESULT / f"{name}.png"
	cut.save(target, optimize=True)
	return target


def main() -> None:
	for name in CUTS:
		target = build(name)
		print(f"{target.relative_to(ROOT)}: {SIZE[0]}x{SIZE[1]}")


if __name__ == "__main__":
	main()
