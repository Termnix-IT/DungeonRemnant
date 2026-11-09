"""Build the health bars' frames from their generated pictures.

art/ui/source/<name>_gauge.png is a frame painted on a flat magenta (#FF00FF)
background: an ornament at each end and a uniform dark channel between them.
The boss's has a crowned skull crest on the left and a spiked finial on the
right; the hero's has a bronze crest with a red heart gem and a small leaf
finial. This keys the magenta out, trims to the frame, scales it to the
gauge's height and writes art/ui/<name>_gauge.png. FramedGauge draws it as a
nine-patch that stretches only the channel, and lays the health fill inside
the channel; run this script with --measure to print the cap widths and
channel rows that ui/boss_gauge.gd and ui/action_hud/action_hud.gd hold as
constants, and update them whenever a picture changes.

	python tools/build_gauges.py               # every gauge
	python tools/build_gauges.py hero          # one gauge
	python tools/build_gauges.py --measure
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from image_boards import key_out

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source"
OUTPUT = ROOT / "art" / "ui"
# Each gauge's height in pixels once built.
HEIGHTS = {"boss": 72, "hero": 48}
SPILL_REACH = 2


def build(name: str) -> Image.Image:
	keyed = key_out(Image.open(SOURCE / f"{name}_gauge.png"), SPILL_REACH)
	box = keyed.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
	keyed = keyed.crop(box)
	height = HEIGHTS[name]
	width = round(keyed.width * height / keyed.height)
	return keyed.resize((width, height), Image.Resampling.LANCZOS)


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
	parser.add_argument("names", nargs="*", help=f"gauges to build: {', '.join(HEIGHTS)} (default all)")
	parser.add_argument("--measure", action="store_true")
	args = parser.parse_args()
	unknown = sorted(set(args.names) - set(HEIGHTS))
	if unknown:
		parser.error(f"unknown gauge: {', '.join(unknown)}")
	for name in args.names or list(HEIGHTS):
		frame = build(name)
		if args.measure:
			print(name)
			measure(frame)
		else:
			frame.save(OUTPUT / f"{name}_gauge.png")
			print("wrote", OUTPUT / f"{name}_gauge.png")
