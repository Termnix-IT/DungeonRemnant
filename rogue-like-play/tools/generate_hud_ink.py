"""Draw the dungeon HUD's ink plate and its hairline divider.

Writes to art/ui/:
- hud_ink.png: a warm graphite plate whose edges dissolve into the dark like
  spread ink (9-slice, 56px margins). The solid core starts INSET pixels in
  from the image edge; the Theme's expand margin of the same size lays that
  fade outside the panel rectangle, so text placed near a panel's edge still
  sits on the full-strength plate.
- hud_rule.png: a bronze hairline that fades out at both ends, stretched to a
  divider's width.

The edge wobble comes from a fixed seed, so rerunning the script reproduces
the same images.

	python tools/generate_hud_ink.py
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "art" / "ui"

SIZE = 160
# Must match HudInk's expand margins in ui/theme/dungeon_theme.tres.
INSET = 40
# How far beyond the panel edge the ink still shows.
FADE = 34
# Same warm, blue-free graphite as the hub panels.
PLATE = (17, 16, 15)
CORE_ALPHA = 0.86
WOBBLE = 7.0
SEED = 20261007

RULE_WIDTH = 256
RULE = (176, 142, 86)
RULE_ALPHA = 0.62


def smooth(value: float) -> float:
	value = max(0.0, min(1.0, value))
	return value * value * (3.0 - 2.0 * value)


def wobble_curve(rng: random.Random, length: int, knots: int) -> list[float]:
	"""Smooth 1D noise in [-1, 1] that starts and ends at 0, so 9-slice seams meet."""
	points = [0.0] + [rng.uniform(-1.0, 1.0) for _ in range(knots - 1)] + [0.0]
	curve = []
	for index in range(length):
		position = index / (length - 1) * knots
		left = min(int(position), knots - 1)
		t = smooth(position - left)
		curve.append(points[left] * (1.0 - t) + points[left + 1] * t)
	return curve


def ink_plate() -> Image.Image:
	rng = random.Random(SEED)
	# One wobble per side, indexed along that side.
	top, bottom, left, right = (wobble_curve(rng, SIZE, 6) for _ in range(4))
	image = Image.new("RGBA", (SIZE, SIZE))
	pixels = image.load()
	inner_max = SIZE - 1 - INSET
	for y in range(SIZE):
		for x in range(SIZE):
			dx = max(INSET - x, 0, x - inner_max)
			dy = max(INSET - y, 0, y - inner_max)
			# Push the edge in or out along each side for a brushed outline.
			shift = 0.0
			if dx > 0:
				shift += (left[y] if x < INSET else right[y]) * WOBBLE
			if dy > 0:
				shift += (top[x] if y < INSET else bottom[x]) * WOBBLE
			distance = max(math.hypot(dx, dy) + shift, 0.0)
			strength = 1.0 - smooth(distance / FADE)
			# A faint grain keeps the core from reading as a flat fill.
			grain = 1.0 + rng.uniform(-0.035, 0.035)
			alpha = CORE_ALPHA * strength * grain
			pixels[x, y] = (*PLATE, round(max(0.0, min(1.0, alpha)) * 255))
	return image


def rule() -> Image.Image:
	image = Image.new("RGBA", (RULE_WIDTH, 1))
	pixels = image.load()
	for x in range(RULE_WIDTH):
		from_center = abs(x - (RULE_WIDTH - 1) / 2) / ((RULE_WIDTH - 1) / 2)
		alpha = RULE_ALPHA * (1.0 - smooth((from_center - 0.35) / 0.65))
		pixels[x, 0] = (*RULE, round(alpha * 255))
	return image


def main() -> None:
	OUTPUT.mkdir(parents=True, exist_ok=True)
	ink_plate().save(OUTPUT / "hud_ink.png")
	rule().save(OUTPUT / "hud_rule.png")


if __name__ == "__main__":
	main()
