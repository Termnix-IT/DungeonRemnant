"""Build the lobby speech bubble's backing from its generated picture.

art/ui/source/speech_bubble.png is a dark ink-wash strip on a transparent
background: plain and even through the middle, a bronze stud at each end and
a short brush-stroke tail on the right. This trims it to the shape, scales it
to HEIGHT pixels and writes art/ui/speech_bubble.png, which the theme's
SpeechSurface draws as a 9-slice: the ends (studs, tail) keep their size and
only the plain middle stretches with the line. Change the theme's
texture_margin_left/right together with LEFT_END and RIGHT_END.

It also writes art/ui/ink_plate.png, the same ink without a tail for hover
hints (InkTooltip): the stud end on the left, mirrored on the right, a plain
middle between. Its theme margins are PLATE_END pixels on each side.

	python tools/build_speech_bubble.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source" / "speech_bubble.png"
OUTPUT = ROOT / "art" / "ui" / "speech_bubble.png"
PLATE = ROOT / "art" / "ui" / "ink_plate.png"
PLATE_HEIGHT = 56
# The stud end and a little plain ink beyond it, in plate pixels.
PLATE_END = 56
PLATE_MIDDLE = 64
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
	small = shape.resize((round(shape.width * PLATE_HEIGHT / shape.height), PLATE_HEIGHT), Image.LANCZOS)
	end = small.crop((0, 0, PLATE_END, PLATE_HEIGHT))
	middle = small.crop((small.width // 2 - PLATE_MIDDLE // 2, 0, small.width // 2 + PLATE_MIDDLE // 2, PLATE_HEIGHT))
	plate = Image.new("RGBA", (PLATE_END * 2 + PLATE_MIDDLE, PLATE_HEIGHT), (0, 0, 0, 0))
	plate.paste(end, (0, 0))
	plate.paste(middle, (PLATE_END, 0))
	plate.paste(end.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (PLATE_END + PLATE_MIDDLE, 0))
	plate.save(PLATE, optimize=True)
	print("plate", plate.size, "margins", PLATE_END)


if __name__ == "__main__":
	main()
