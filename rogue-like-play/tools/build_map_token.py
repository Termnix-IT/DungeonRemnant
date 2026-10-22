"""Cut the route map's token, the hero's face in a round frame, from her
painted HUD portrait.

art/ui/source/painted/hud_portrait_normal.png is the HUD's portrait; this
crops a circle around her face (FACE, RADIUS in the portrait's pixels),
softens its edge and shrinks it to SIZE px as art/ui/route/token.png, which
RouteMapView draws inside its gold ring.

	python tools/build_map_token.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source" / "painted" / "hud_portrait_normal.png"
OUTPUT = ROOT / "art" / "ui" / "route" / "token.png"
FACE = (650, 560)
RADIUS = 370
SIZE = 128


def main() -> None:
	portrait = Image.open(SOURCE).convert("RGBA")
	box = (FACE[0] - RADIUS, FACE[1] - RADIUS, FACE[0] + RADIUS, FACE[1] + RADIUS)
	face = portrait.crop(box)
	# Her hair's transparent edges become the frame's dark ground.
	ground = Image.new("RGBA", face.size, (16, 14, 18, 255))
	ground.alpha_composite(face)
	mask = Image.new("L", face.size, 0)
	ImageDraw.Draw(mask).ellipse((2, 2, face.size[0] - 3, face.size[1] - 3), fill=255)
	ground.putalpha(mask.filter(ImageFilter.GaussianBlur(2)))
	OUTPUT.parent.mkdir(parents=True, exist_ok=True)
	ground.resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(OUTPUT)
	print(f"Saved {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
	main()
