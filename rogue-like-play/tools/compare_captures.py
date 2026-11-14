"""Compare the screens the capture scripts took against a baseline.

The capture scripts (tests/capture_*.gd) write PNGs into .godot/. Before a
change to how the UI looks, keep the current ones as the baseline; after it,
capture again and compare. Each image is reported with the share of its
pixels that moved by more than a few levels and the largest move, and an
image of what moved (the new screen above, the old one dimmed below with the
moved pixels in red) is written to .godot/ui-diff/ for every image that
moved. The baseline lives in .godot/ui-baseline/ and is never committed.

Run from the Godot project root:

	python tools/compare_captures.py save                # keep hub_* and status_* as the baseline
	python tools/compare_captures.py save "boss_*"       # or the captures matching these names
	python tools/compare_captures.py                     # compare against the baseline

A changed share is not a failure: moving the look is the point of a UI
change. It shows where to look, and small moves on animated parts (the
hub's light, a breathing glow) are expected between any two captures.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
CAPTURES = ROOT / ".godot"
BASELINE = CAPTURES / "ui-baseline"
DIFFS = CAPTURES / "ui-diff"
DEFAULT_PATTERNS = ["hub_*.png", "status_*.png"]
# A pixel counts as moved when one of its channels moved by more than this
# (out of 255), above the rounding of two captures of the same screen.
THRESHOLD = 3


def save(patterns: list[str]) -> None:
	if BASELINE.exists():
		shutil.rmtree(BASELINE)
	BASELINE.mkdir(parents=True)
	kept = 0
	for pattern in patterns:
		pattern = pattern if pattern.endswith(".png") else pattern + ".png"
		for path in sorted(CAPTURES.glob(pattern)):
			shutil.copy2(path, BASELINE / path.name)
			kept += 1
	if kept == 0:
		sys.exit("No captures match %s in %s; run the capture scripts first." % (" ".join(patterns), CAPTURES.relative_to(ROOT).as_posix()))
	print("Kept %d captures as the baseline in %s" % (kept, BASELINE.relative_to(ROOT).as_posix()))


def compare() -> int:
	if not BASELINE.exists():
		sys.exit("No baseline: run `python tools/compare_captures.py save` before the change.")
	if DIFFS.exists():
		shutil.rmtree(DIFFS)
	DIFFS.mkdir(parents=True)
	moved_images = 0
	for old_path in sorted(BASELINE.glob("*.png")):
		new_path = CAPTURES / old_path.name
		if not new_path.exists():
			print("MISSING %s" % old_path.name)
			continue
		old = Image.open(old_path).convert("RGB")
		new = Image.open(new_path).convert("RGB")
		if old.size != new.size:
			print("SIZE    %s %s -> %s" % (old_path.name, old.size, new.size))
			continue
		difference = ImageChops.difference(old, new)
		strongest = max(high for _, high in difference.getextrema())
		mask = difference.convert("L").point(lambda level: 255 if level > THRESHOLD else 0)
		share = mask.histogram()[255] / (old.width * old.height) * 100
		if share == 0:
			print("same    %s" % old_path.name)
			continue
		moved_images += 1
		print("moved   %s  %.2f%% of pixels, largest %d/255" % (old_path.name, share, strongest))
		sheet = Image.new("RGB", (old.width, old.height * 2))
		sheet.paste(new, (0, 0))
		red = Image.new("RGB", old.size, (255, 0, 0))
		sheet.paste(Image.composite(red, old.point(lambda level: level // 3), mask), (0, old.height))
		sheet.save(DIFFS / old_path.name)
	print("%d of the baseline's captures moved; see %s" % (moved_images, DIFFS.relative_to(ROOT).as_posix()))
	return 0


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("command", nargs="?", choices=["save", "compare"], default="compare")
	parser.add_argument("patterns", nargs="*", help="capture names to keep with save (default: hub_* status_*)")
	args = parser.parse_args()
	if args.command == "save":
		save(args.patterns or DEFAULT_PATTERNS)
	else:
		sys.exit(compare())


if __name__ == "__main__":
	main()
