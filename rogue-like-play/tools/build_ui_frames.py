"""Build the Theme's 9-slice frames and button plates from generated ornaments.

art/ui/source/ornaments.png is a 2x2 board: bronze panel corner, gold panel
corner, bronze button end cap, gold button end cap (see BOARD). This script
cuts them out, shrinks them to pixel art with the enemies' outline, and
composes, in art/ui/:

- frame_panel.png, frame_card.png, frame_card_active.png: 96px frames with a
  corner piece in each corner (mirrored) joined by a thin rail;
- button_gold.png, button_gold_hover.png, button_gold_pressed.png: plates
  with an end cap at each side, for the primary and gold buttons.

Frames keep FRAME_MARGIN px corners and buttons their caps' width (19px); the Theme's
StyleBoxTexture margins must match (see ui/theme/dungeon_theme.tres).

	python tools/build_ui_frames.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageOps

from process_enemy_sheet import add_outline, downscale
from process_item_icons import cut_board

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source" / "ornaments.png"
OUTPUT = ROOT / "art" / "ui"
FRAME = 96
FRAME_MARGIN = 42
CORNER = 40
BUTTON_HEIGHT = 44
BUTTON_WIDTH = 96
CAP_HEIGHT = 36
# The plate matches the common 44px button exactly. Taller buttons stretch
# only the two middle rows, at the jewel's widest point, so the jewel grows
# into a tall cut gem instead of smearing.
BUTTON_MARGIN_TOP = 21
BUTTON_MARGIN_BOTTOM = 21
PALETTE_COLORS = 24
OUTLINE = (10, 11, 14, 255)

# Panel surfaces keep the Theme's approved colours and translucency.
SURFACES = {
	"frame_panel": ((36, 36, 36, 255), (122, 98, 58, 255)),
	"frame_card": ((30, 30, 30, 234), (110, 90, 56, 255)),
	"frame_card_active": ((40, 36, 26, 242), (214, 180, 112, 255)),
}
PLATES = {
	"button_gold": ((46, 37, 20, 255), (150, 118, 66, 255), (92, 72, 40, 255)),
	"button_gold_hover": ((64, 52, 30, 255), (214, 183, 123, 255), (120, 94, 52, 255)),
	"button_gold_pressed": ((38, 36, 26, 255), (150, 118, 66, 255), (60, 48, 28, 255)),
}


def pixel_part(source: Image.Image, size: tuple[int, int]) -> Image.Image:
	"""Fit a cut-out into `size` minus its outline, as outlined pixel art."""
	scale = min((size[0] - 2) / source.width, (size[1] - 2) / source.height)
	small = downscale(source, scale)
	small = small.crop(small.getchannel("A").getbbox())
	alpha = small.getchannel("A")
	flat = Image.new("RGB", small.size)
	flat.paste(small.convert("RGB"), mask=alpha)
	reduced = flat.quantize(colors=PALETTE_COLORS, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGBA")
	reduced.putalpha(alpha)
	return add_outline(reduced)


def frame(corner: Image.Image, surface: tuple, rail: tuple) -> Image.Image:
	image = Image.new("RGBA", (FRAME, FRAME), surface)
	pixels = image.load()
	for i in range(FRAME):
		for edge in ((i, 0), (i, FRAME - 1), (0, i), (FRAME - 1, i)):
			pixels[edge] = OUTLINE
		# A thin rail three pixels in joins the corner pieces along each side.
		for edge in ((i, 3), (i, FRAME - 4), (3, i), (FRAME - 4, i)):
			if 3 <= i <= FRAME - 4:
				pixels[edge] = rail
	for flip_x, flip_y in ((False, False), (True, False), (False, True), (True, True)):
		piece = corner
		if flip_x:
			piece = ImageOps.mirror(piece)
		if flip_y:
			piece = ImageOps.flip(piece)
		x = FRAME - piece.width if flip_x else 0
		y = FRAME - piece.height if flip_y else 0
		image.alpha_composite(piece, (x, y))
	return image


def plate(cap: Image.Image, fill: tuple, rim: tuple, shade: tuple) -> Image.Image:
	image = Image.new("RGBA", (BUTTON_WIDTH, BUTTON_HEIGHT), (0, 0, 0, 0))
	pixels = image.load()
	inset = (BUTTON_HEIGHT - CAP_HEIGHT) // 2
	for x in range(cap.width // 2, BUTTON_WIDTH - cap.width // 2):
		for y in range(inset, BUTTON_HEIGHT - inset):
			edge = y in (inset, BUTTON_HEIGHT - inset - 1)
			pixels[x, y] = OUTLINE if edge else (rim if y == inset + 1 else (shade if y == BUTTON_HEIGHT - inset - 2 else fill))
	top = (BUTTON_HEIGHT - cap.height) // 2
	image.alpha_composite(cap, (0, top))
	image.alpha_composite(ImageOps.mirror(cap), (BUTTON_WIDTH - cap.width, top))
	return image


def main() -> None:
	parts = cut_board(Image.open(SOURCE), 2, 2)
	corners = {"bronze": pixel_part(parts[0], (CORNER, CORNER)), "gold": pixel_part(parts[1], (CORNER, CORNER))}
	caps = {"bronze": pixel_part(parts[2], (CAP_HEIGHT, CAP_HEIGHT)), "gold": pixel_part(parts[3], (CAP_HEIGHT, CAP_HEIGHT))}
	for name, (surface, rail) in SURFACES.items():
		frame(corners["gold" if name.endswith("active") else "bronze"], surface, rail).save(OUTPUT / f"{name}.png")
	for name, colours in PLATES.items():
		plate(caps["gold" if name.endswith("hover") else "bronze"], *colours).save(OUTPUT / f"{name}.png")
	print(f"corner {corners['bronze'].size}, cap {caps['bronze'].size}; saved frames and button plates to art/ui/")


if __name__ == "__main__":
	main()
