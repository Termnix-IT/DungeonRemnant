"""Build the boss health bar's frame from its generated picture.

art/ui/source/boss_gauge.png is the frame painted on a flat magenta
(#FF00FF) background: a crowned skull crest on the left, a spiked finial on
the right and a uniform dark channel between them. This keys the magenta out,
trims to the frame, scales it to HEIGHT pixels tall and writes
art/ui/boss_gauge.png. BossGauge draws it as a nine-patch that stretches only
the channel, and lays the health fill inside the channel; run this script
with --measure to print the cap widths and channel rows that ui/boss_gauge.gd
holds as constants, and update them whenever the picture changes.

	python tools/build_boss_gauge.py
	python tools/build_boss_gauge.py --measure
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from build_stage_dioramas import key_out

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source" / "boss_gauge.png"
OUTPUT = ROOT / "art" / "ui" / "boss_gauge.png"
HEIGHT = 72
SPILL_REACH = 2


def build() -> Image.Image:
	keyed = key_out(Image.open(SOURCE), SPILL_REACH)
	box = keyed.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
	keyed = keyed.crop(box)
	width = round(keyed.width * HEIGHT / keyed.height)
	return keyed.resize((width, HEIGHT), Image.Resampling.LANCZOS)


def measure(frame: Image.Image) -> None:
	rgba = np.asarray(frame).astype(np.int32)
	middle = frame.width // 2
	# The channel is the run of dark, opaque rows through the middle column.
	dark = (rgba[:, middle, 3] > 200) & (rgba[:, middle, :3].max(axis=1) < 40)
	half = frame.height // 2
	top = bottom = half
	while top > 0 and dark[top - 1]:
		top -= 1
	while bottom < frame.height and dark[bottom]:
		bottom += 1
	centre = (top + bottom) // 2
	# The caps end where the channel row turns dark on each side.
	line = (rgba[centre, :, 3] > 200) & (rgba[centre, :, :3].max(axis=1) < 40)
	# Walk out from the middle so the crest's dark outlines do not count.
	left = right = middle
	while left > 0 and line[left - 1]:
		left -= 1
	while right < frame.width and line[right]:
		right += 1
	print(f"size {frame.size}")
	print(f"channel rows {top}..{bottom}, columns {left}..{right}")
	print(f"left cap {left}px, right cap {frame.width - right}px")


if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("--measure", action="store_true")
	args = parser.parse_args()
	frame = build()
	if args.measure:
		measure(frame)
	else:
		frame.save(OUTPUT)
		print("wrote", OUTPUT)
