"""Build the Theme's 9-slice frames and button plates from generated ornaments.

art/ui/source/ornaments.png is a 2x2 board: bronze panel corner, gold panel
corner, bronze button end cap, gold button end cap (see BOARD). This script
cuts them out, shrinks them to pixel art with the enemies' outline, and
composes, in art/ui/:

- frame_panel.png, frame_card.png, frame_card_active.png: 96px frames with a
  corner piece in each corner (mirrored) joined by a thin rail;
- button_gold.png, button_gold_hover.png, button_gold_pressed.png: plates
  with an end cap at each side, for the primary and gold buttons;
- surface_*.png: the small 9-slice surfaces inside the frames (see
  SURFACE_STYLES), drawn here without the ornament board.

The frames' fill is a faint graphite grain that repeats every FRAME_TILE px,
so the Theme tiles it (axis stretch TILE_FIT) and the grain keeps one scale
at every panel size, with a soft shadow under the rail on every side. The
surfaces give the panel contents three steps of depth: cards are raised
(lit top edge, fill darkening downward, shaded foot), hover and selection are
raised brighter or warm, and detail wells and list grounds are sunk (shadow
under the top edge, faint lit foot).

Frames keep FRAME_MARGIN px corners and buttons their caps' width (19px); the Theme's
StyleBoxTexture margins must match (see ui/theme/dungeon_theme.tres).

	python tools/build_ui_frames.py
"""

from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageOps

from process_enemy_sheet import add_outline, downscale
from process_item_icons import cut_board

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source" / "ornaments.png"
OUTPUT = ROOT / "art" / "ui"
FRAME_MARGIN = 42
# The tiled middle of each frame; the grain repeats with this period.
FRAME_TILE = 108
FRAME = FRAME_MARGIN * 2 + FRAME_TILE
GRAIN = 7.0
RAIL_SHADOW = 16
RAIL_SHADOW_DEPTH = 0.4
SURFACE = 24
SURFACE_MARGIN = 6
SURFACE_RADIUS = 3
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
# name: (fill top, fill bottom, border, top edge, bottom edge, raised).
# Raised surfaces light their top edge and shade their foot; sunk ones do
# the opposite, so the eye reads cards above the panel and wells below it.
SURFACE_STYLES = {
	"surface_raised": ((52, 52, 51, 255), (40, 40, 39, 255), (70, 70, 68, 255), (92, 92, 88, 255), (18, 18, 18, 255), True),
	"surface_hover": ((62, 62, 60, 255), (48, 48, 46, 255), (84, 84, 80, 255), (108, 108, 102, 255), (20, 20, 20, 255), True),
	"surface_selected": ((58, 50, 32, 255), (40, 35, 22, 255), (184, 150, 89, 255), (222, 190, 128, 255), (92, 72, 40, 255), True),
	"surface_sunk": ((20, 20, 20, 250), (28, 28, 28, 250), (14, 14, 14, 255), (8, 8, 8, 255), (58, 58, 56, 255), False),
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


def grain(seed: int) -> list[list[float]]:
	"""Soft value noise in -1..1 that wraps every FRAME_TILE px."""
	rng = random.Random(seed)
	field = [[0.0] * FRAME_TILE for _ in range(FRAME_TILE)]
	for cell, weight in ((18, 0.7), (6, 0.3)):
		count = FRAME_TILE // cell
		lattice = [[rng.uniform(-1, 1) for _ in range(count)] for _ in range(count)]
		for y in range(FRAME_TILE):
			for x in range(FRAME_TILE):
				gx, gy = x / cell, y / cell
				x0, y0 = int(gx) % count, int(gy) % count
				x1, y1 = (x0 + 1) % count, (y0 + 1) % count
				tx, ty = gx - int(gx), gy - int(gy)
				tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
				top = lattice[y0][x0] * (1 - tx) + lattice[y0][x1] * tx
				bottom = lattice[y1][x0] * (1 - tx) + lattice[y1][x1] * tx
				field[y][x] += (top * (1 - ty) + bottom * ty) * weight
	return field


def frame(corner: Image.Image, surface: tuple, rail: tuple) -> Image.Image:
	image = Image.new("RGBA", (FRAME, FRAME), surface)
	pixels = image.load()
	noise = grain(7)
	for y in range(FRAME):
		for x in range(FRAME):
			# Coordinates wrap on the tile, so the tiled edges and the corners
			# continue the same grain; the rail's shadow depends only on the
			# distance to the nearest side, so it tiles along each side.
			tone = noise[(y - FRAME_MARGIN) % FRAME_TILE][(x - FRAME_MARGIN) % FRAME_TILE] * GRAIN
			depth = min(x, y, FRAME - 1 - x, FRAME - 1 - y) - 4
			if 0 <= depth < RAIL_SHADOW:
				shade = 1.0 - RAIL_SHADOW_DEPTH * (1.0 - depth / RAIL_SHADOW) ** 2
			else:
				shade = 1.0
			pixels[x, y] = tuple(max(0, min(255, round((channel + tone) * shade))) for channel in surface[:3]) + (surface[3],)
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


def lerp(a: tuple, b: tuple, t: float) -> tuple:
	return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(4))


def surface_tile(fill_top: tuple, fill_bottom: tuple, border: tuple, top_edge: tuple, bottom_edge: tuple, raised: bool) -> Image.Image:
	"""A small 9-slice surface: rounded corners, 1px border, a fill graded top
	to bottom (the stretched middle keeps the gradient), and a lit or shaded
	edge row just inside the top and bottom borders."""
	image = Image.new("RGBA", (SURFACE, SURFACE), (0, 0, 0, 0))
	pixels = image.load()
	last = SURFACE - 1
	for y in range(SURFACE):
		for x in range(SURFACE):
			# Rounded corners: skip pixels outside the radius.
			cx = SURFACE_RADIUS - x if x < SURFACE_RADIUS else (x - (last - SURFACE_RADIUS) if x > last - SURFACE_RADIUS else 0)
			cy = SURFACE_RADIUS - y if y < SURFACE_RADIUS else (y - (last - SURFACE_RADIUS) if y > last - SURFACE_RADIUS else 0)
			if cx * cx + cy * cy > SURFACE_RADIUS * SURFACE_RADIUS:
				continue
			if x in (0, last) or y in (0, last) or cx * cx + cy * cy > (SURFACE_RADIUS - 1) ** 2:
				pixels[x, y] = border
			elif y == 1:
				pixels[x, y] = top_edge
			elif y == last - 1:
				pixels[x, y] = bottom_edge
			elif not raised and y == 2:
				# A sunk well's top also casts a second, softer row of shadow.
				pixels[x, y] = lerp(top_edge, fill_top, 0.5)
			else:
				pixels[x, y] = lerp(fill_top, fill_bottom, (y - 2) / (SURFACE - 5))
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
	for name, style in SURFACE_STYLES.items():
		surface_tile(*style).save(OUTPUT / f"{name}.png")
	for name, colours in PLATES.items():
		plate(caps["gold" if name.endswith("hover") else "bronze"], *colours).save(OUTPUT / f"{name}.png")
	print(f"corner {corners['bronze'].size}, cap {caps['bronze'].size}; saved frames and button plates to art/ui/")


if __name__ == "__main__":
	main()
