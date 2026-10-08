"""Build the battle effects' frame strips from the third-party originals.

Each original stays untouched in art/third_party/<pack>/source/ (which Godot
does not import). This writes art/third_party/<pack>/<kind>.png: the effect's
frames, square, side by side left to right in play order, at the original
pixel size (StrikeEffect scales them with nearest sampling). The frame rate,
world scale and whether a strip turns with the attack live in
StrikeEffect.SHEETS.

	python tools/build_effect_sheets.py
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
THIRD_PARTY = ROOT / "art" / "third_party"


def strip(frames: list[Image.Image]) -> Image.Image:
	side = frames[0].height
	sheet = Image.new("RGBA", (side * len(frames), side), (0, 0, 0, 0))
	for index, frame in enumerate(frames):
		sheet.alpha_composite(frame, (index * side, 0))
	return sheet


def row(path: Path, side: int) -> list[Image.Image]:
	image = Image.open(path).convert("RGBA")
	return [image.crop((x, 0, x + side, side)) for x in range(0, image.width, side)]


def numbered(folder: Path) -> list[Image.Image]:
	return [Image.open(path).convert("RGBA") for path in sorted(folder.glob("*.png"))]


def pvfx(effect: str) -> list[Image.Image]:
	folder = THIRD_PARTY / "pvfx_foundry" / "source" / effect
	manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
	sheet = Image.open(folder / "sprite-sheet.png").convert("RGBA")
	frames = []
	for frame in sorted(manifest["frames"], key=lambda item: item["frame"]):
		cell = frame["sheet"]
		frames.append(sheet.crop((cell["x"], cell["y"], cell["x"] + cell["width"], cell["y"] + cell["height"])))
	return frames


# kind: (pack folder, frames)
EFFECTS = {
	"magic": ("devwizard_pixel_art_spells", lambda: row(THIRD_PARTY / "devwizard_pixel_art_spells" / "source" / "Arcane Bolt.png", 16)),
	"flame": ("foozle_pixel_magic_effects", lambda: numbered(THIRD_PARTY / "foozle_pixel_magic_effects" / "source" / "Fire_Ball")),
	"slash": ("pvfx_foundry", lambda: pvfx("crescent-slash")),
	"heavy": ("pvfx_foundry", lambda: pvfx("earth-rupture")),
	"hit": ("pvfx_foundry", lambda: pvfx("solar-shrapnel")),
	"heal": ("pvfx_foundry", lambda: pvfx("radiant-heal")),
	"death": ("pvfx_foundry", lambda: pvfx("smoke-puff")),
}


def main() -> None:
	for kind, (pack, frames) in EFFECTS.items():
		images = frames()
		out = THIRD_PARTY / pack / ("%s.png" % kind)
		strip(images).save(out)
		print("%-6s %2d frames of %dpx -> %s/%s.png" % (kind, len(images), images[0].height, pack, kind))


if __name__ == "__main__":
	main()
