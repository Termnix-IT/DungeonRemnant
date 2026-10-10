"""Draw the dungeon HUD's hairline divider.

Writes art/ui/hud_rule.png: a bronze hairline that fades out at both ends,
stretched to a divider's width. (The HUD's ink plate that this script also
drew gave way to the painted plates of tools/build_hud_art.py.)

	python tools/generate_hud_ink.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "art" / "ui"

RULE_WIDTH = 256
RULE = (176, 142, 86)
RULE_ALPHA = 0.62


def smooth(value: float) -> float:
	value = max(0.0, min(1.0, value))
	return value * value * (3.0 - 2.0 * value)


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
	rule().save(OUTPUT / "hud_rule.png")


if __name__ == "__main__":
	main()
