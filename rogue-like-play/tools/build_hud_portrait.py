"""Shrink the painted HUD faces for ui/hud_portrait.gd.

art/ui/source/painted/hud_portrait_<face>.png are bust portraits of the
heroine on transparency, the blink, hurt and weary faces edited from the
normal one so the rest stays in place. Each is cut to the same square, set by
the normal face (the figure's width, from the top of the beret down), and
shrunk to SIZE px as art/ui/hud_portrait_<face>.png, mipmapped in Godot.

	python tools/build_hud_portrait.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source" / "painted"
OUTPUT = ROOT / "art" / "ui"
FACES = ["normal", "blink", "hurt", "weary"]
# Twice the 96 px the plate shows a face at.
SIZE = 192
# Room above the beret, as a share of the square.
HEADROOM = 0.03
# How much of the figure's width the square spans; under 1 crops the
# shoulders' outer edges so the face is larger.
WIDTH_SHARE = 0.86


def main() -> None:
	normal = Image.open(SOURCE / "hud_portrait_normal.png").convert("RGBA")
	left, top, right, _bottom = normal.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
	side = round((right - left) * WIDTH_SHARE)
	centre = (left + right) // 2
	box_top = max(0, top - round(side * HEADROOM))
	box = (centre - side // 2, box_top, centre - side // 2 + side, box_top + side)
	for face in FACES:
		path = SOURCE / f"hud_portrait_{face}.png"
		if not path.exists():
			print(f"Skipped {face}: not generated yet")
			continue
		image = Image.open(path).convert("RGBA")
		if image.size != normal.size:
			image = image.resize(normal.size, Image.Resampling.LANCZOS)
		premultiplied = image.crop(box).convert("RGBa")
		premultiplied.resize((SIZE, SIZE), Image.Resampling.LANCZOS).convert("RGBA").save(OUTPUT / f"hud_portrait_{face}.png")
		print(f"face {face}")


if __name__ == "__main__":
	main()
