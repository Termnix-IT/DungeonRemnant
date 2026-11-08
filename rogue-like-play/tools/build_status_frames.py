"""Build the status page's painted frames from their generated pictures.

The pictures in art/ui/source/status_*.png were made with Codex's image
generation (see 開発メモ.md), painted on flat magenta (#FF00FF): the pedestal
that holds the four slots, the shelf of what a slot can hold, the tablet her
figures are carved on, and a board with the pedestal's crest (left) and the
shelf's pennant (right). This keys the magenta out, trims each part to its
picture and scales it to the size the game draws it, writing
art/ui/status/*.png. The frames are drawn nine-patch: the margins in
ui/theme/dungeon_theme.tres (EquipBarFrame, EquipShelfFrame,
StatusTabletFrame) follow the sizes printed here; update them whenever a
picture changes.

	python tools/build_status_frames.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from image_boards import background_mask, components

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source"
OUTPUT = ROOT / "art" / "ui" / "status"
# Each frame and how much it is scaled, so its corner ornaments come out about
# as wide as the game's other frames; the tablet's border is drawn thicker,
# so it is scaled further down to leave its rows of figures their room.
FRAMES = {
	"pedestal": ("status_pedestal.png", 0.4),
	"shelf": ("status_shelf.png", 0.4),
	"tablet": ("status_tablet.png", 0.32),
}
# The ornaments' drawn sizes: the crest this wide, the pennant this tall.
CREST_WIDTH = 132
PENNANT_HEIGHT = 50
# Edge pixels whose colour still leans to the key colour are pulled back to
# the frame's own dark (a fringe left by antialiasing against magenta).
SPILL = 60


def keyed(image: Image.Image) -> Image.Image:
	rgba = np.asarray(image.convert("RGBA")).copy()
	background = background_mask(image)
	rgba[:, :, 3] = np.where(background, 0, 255)
	r, g, b = (rgba[:, :, index].astype(np.int32) for index in range(3))
	spill = (np.minimum(r, b) - g > SPILL) & ~background
	rgba[spill, 0] = g[spill]
	rgba[spill, 2] = g[spill]
	out = Image.fromarray(rgba)
	return out.crop(out.getchannel("A").getbbox())


def scaled(image: Image.Image, factor: float) -> Image.Image:
	return image.resize((max(1, round(image.width * factor)), max(1, round(image.height * factor))), Image.LANCZOS)


# The two ornaments, left and right on their board: each the largest part on
# its half.
def ornaments(board: Image.Image) -> tuple[Image.Image, Image.Image]:
	rgba = np.asarray(board.convert("RGBA")).copy()
	foreground = ~background_mask(board)
	height, width = foreground.shape
	halves: list[Image.Image] = []
	for left in (True, False):
		parts = [pixels for pixels, (_cy, cx) in components(foreground) if (cx < width / 2) == left]
		if not parts:
			raise ValueError("An ornament is missing from status_ornaments.png")
		biggest = max(len(pixels) for pixels in parts)
		mask = np.zeros(height * width, dtype=bool)
		for pixels in parts:
			if len(pixels) >= biggest * 0.02:
				mask[pixels] = True
		cell = rgba.copy()
		cell[:, :, 3] = np.where(mask.reshape(height, width), 255, 0)
		image = Image.fromarray(cell)
		halves.append(keyed(image.crop(image.getchannel("A").getbbox())))
	return halves[0], halves[1]


def main() -> None:
	OUTPUT.mkdir(parents=True, exist_ok=True)
	for name, (source, factor) in FRAMES.items():
		frame = scaled(keyed(Image.open(SOURCE / source)), factor)
		frame.save(OUTPUT / f"{name}.png")
		print(f"{name}: {frame.width}x{frame.height}")
	crest, pennant = ornaments(Image.open(SOURCE / "status_ornaments.png"))
	crest = scaled(crest, CREST_WIDTH / crest.width)
	pennant = scaled(pennant, PENNANT_HEIGHT / pennant.height)
	crest.save(OUTPUT / "crest.png")
	pennant.save(OUTPUT / "pennant.png")
	print(f"crest: {crest.width}x{crest.height}, pennant: {pennant.width}x{pennant.height}")


if __name__ == "__main__":
	main()
