"""Build the lobby speech bubble's backing from its generated picture.

art/ui/source/speech_bubble.png is a dark ink-wash strip on a transparent
background: plain and even through the middle, a bronze stud at each end and
a short brush-stroke tail on the right. This trims it to the shape, scales it
to HEIGHT pixels and writes art/ui/speech_bubble.png, which the theme's
SpeechSurface draws as a 9-slice: the ends (studs, tail) keep their size and
only the plain middle stretches with the line. Change the theme's
texture_margin_left/right together with LEFT_END and RIGHT_END.

	python tools/build_speech_bubble.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source" / "speech_bubble.png"
OUTPUT = ROOT / "art" / "ui" / "speech_bubble.png"
HEIGHT = 80
# Shares of the trimmed width held by each end; the middle stretches.
LEFT_END = 0.13
RIGHT_END = 0.21


def main() -> None:
	image = Image.open(SOURCE).convert("RGBA")
	solid = image.getchannel("A").point(lambda value: 255 if value > 48 else 0)
	shape = image.crop(solid.getbbox())
	width = round(shape.width * HEIGHT / shape.height)
	shape.resize((width, HEIGHT), Image.LANCZOS).save(OUTPUT, optimize=True)
	print("size", (width, HEIGHT), "margins", round(width * LEFT_END), round(width * RIGHT_END))


if __name__ == "__main__":
	main()
