"""Build the painted art of the way from starting the game to setting out.

The originals are pictures Codex generated on flat magenta, kept in
art/hub/source/ (the requests are in docs/絵の制作記録/拠点とUIの絵.md):

  title_logo.png   the game's logo: an emblem over two lines of letters
  menu_pillar.png  the near stone pier the lobby's menu is written on
  menu_icons.png   five bronze medallions in a row, one for each menu entry
  view_parts.png   the window frame of a chapter's small view, and its seal

and the hall's painting itself (art/hub/lobby_hall.png). From them this
writes, cut off the magenta and sized for the game:

  art/hub/title/logo.png, emblem.png, app_icon.png
  art/hub/lobby/menu_pillar.png
  art/hub/lobby/icon_<entry>.png           (departure, upgrade, status, codex, settings)
  art/hub/sortie/view_frame.png, view_hole.png, view_seal.png
  art/hub/lobby_hall_far.png               (where the far view through the hall's gate is)

Run it from the Godot project's folder, then import:

  python tools/build_start_art.py
  python tools/build_start_art.py --measure   (prints where the pier's panel and ring are)
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from image_boards import key_out

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "hub" / "source"
HUB = ROOT / "art" / "hub"
ENTRIES = ["departure", "upgrade", "status", "codex", "settings"]
ICON_SIZE = 192
EMBLEM_SIZE = 256
APP_ICON_SIZE = 256
PILLAR_SAVED_HEIGHT = 1280
VIEW_WIDTH = 480
SEAL_WIDTH = 420
# The far view through the hall's gate: bluer than it is red, inside the
# gate's arch (shares of the painting).
FAR_SIZE = (384, 256)
FAR_BOX = (0.46, 0.035, 0.665, 0.455)


def solid(image: Image.Image) -> Image.Image:
	return image.getchannel("A").point(lambda value: 255 if value > 24 else 0)


def cropped(image: Image.Image) -> Image.Image:
	return image.crop(solid(image).getbbox())


def runs(there: np.ndarray, least: int) -> list[tuple[int, int]]:
	"""The stretches where something is painted, at least `least` long."""
	found = []
	start = None
	for index, painted in enumerate(there):
		if painted and start is None:
			start = index
		elif not painted and start is not None:
			if index - start >= least:
				found.append((start, index))
			start = None
	if start is not None:
		found.append((start, len(there)))
	return found


def build_logo() -> list[Path]:
	"""The logo whole, its emblem alone, and the game's icon made of the emblem."""
	logo = cropped(key_out(Image.open(SOURCE / "title_logo.png"), 2))
	target = HUB / "title" / "logo.png"
	logo.save(target)
	# The emblem stands clear above the letters: the first run of painted rows.
	rows = runs(np.asarray(solid(logo)).any(axis=1), 20)
	if len(rows) < 2:
		raise ValueError("the logo's emblem does not stand clear of its letters")
	emblem = cropped(logo.crop((0, rows[0][0], logo.width, rows[0][1])))
	side = max(emblem.size)
	square = Image.new("RGBA", (side, side))
	square.alpha_composite(emblem, ((side - emblem.width) // 2, (side - emblem.height) // 2))
	emblem_target = HUB / "title" / "emblem.png"
	square.resize((EMBLEM_SIZE, EMBLEM_SIZE), Image.LANCZOS).save(emblem_target)
	# The icon: the emblem on a dark disc with a bronze rim.
	big = APP_ICON_SIZE * 4
	icon = Image.new("RGBA", (big, big))
	draw = ImageDraw.Draw(icon)
	draw.ellipse((8, 8, big - 8, big - 8), fill=(96, 74, 42, 255))
	draw.ellipse((40, 40, big - 40, big - 40), fill=(16, 18, 26, 255))
	mark = square.resize((int(big * 0.7), int(big * 0.7)), Image.LANCZOS)
	icon.alpha_composite(mark, ((big - mark.width) // 2, (big - mark.height) // 2))
	icon_target = HUB / "title" / "app_icon.png"
	icon.resize((APP_ICON_SIZE, APP_ICON_SIZE), Image.LANCZOS).save(icon_target)
	return [target, emblem_target, icon_target]


def pillar() -> Image.Image:
	"""The pier cut off the magenta at its right."""
	pier = key_out(Image.open(SOURCE / "menu_pillar.png"), 2)
	box = solid(pier).getbbox()
	return pier.crop((0, 0, box[2], pier.height))


def build_pillar() -> list[Path]:
	target = HUB / "lobby" / "menu_pillar.png"
	pier = pillar()
	pier.resize((round(pier.width * PILLAR_SAVED_HEIGHT / pier.height), PILLAR_SAVED_HEIGHT), Image.LANCZOS).save(target)
	return [target]


def measure_pillar() -> str:
	"""Where the pier's bronze-edged panel and its ring are, as shares of its picture."""
	pier = pillar()
	rgb = np.asarray(pier.convert("RGB"), dtype=np.float32)
	w, h = pier.size
	# Bronze: much redder than it is blue, and not dark. The pier's right
	# edge, warm in the hall's light, is left out.
	bronze = ((rgb[..., 0] > rgb[..., 2] * 1.5) & (rgb[..., 0] > 110) & (rgb[..., 1] > 70))[:, : int(w * 0.8)]
	rows = np.where(bronze.sum(axis=1) > w * 0.4)[0]
	columns = np.where(((rgb[..., 0] > rgb[..., 2] * 1.5) & (rgb[..., 0] > 110))[rows.min() : rows.max()].sum(axis=0) > (rows.max() - rows.min()) * 0.5)[0]
	ring = np.argwhere(bronze[: rows.min() - 10])
	top, left = ring.min(axis=0)
	bottom, right = ring.max(axis=0)
	return "pier %dx%d  panel x %.4f..%.4f y %.4f..%.4f  ring centre (%.4f, %.4f) across %.4f of the width" % (
		w, h, columns.min() / w, columns.max() / w, rows.min() / h, rows.max() / h,
		(left + right) * 0.5 / w, (top + bottom) * 0.5 / h, (right - left) / w)


def build_icons() -> list[Path]:
	board = key_out(Image.open(SOURCE / "menu_icons.png"), 2)
	found = runs(np.asarray(solid(board)).any(axis=0), 20)
	if len(found) != len(ENTRIES):
		raise ValueError(f"the board holds {len(found)} medallions, not {len(ENTRIES)}")
	targets = []
	for entry, (left, right) in zip(ENTRIES, found):
		piece = cropped(board.crop((left, 0, right, board.height)))
		side = max(piece.size)
		square = Image.new("RGBA", (side, side))
		square.alpha_composite(piece, ((side - piece.width) // 2, (side - piece.height) // 2))
		target = HUB / "lobby" / f"icon_{entry}.png"
		square.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS).save(target)
		targets.append(target)
	return targets


def build_views() -> list[Path]:
	"""The window frame with its hole see-through, the hole's shape, and the seal."""
	board = key_out(Image.open(SOURCE / "view_parts.png"), 2)
	found = runs(np.asarray(solid(board)).any(axis=0), 20)
	if len(found) != 2:
		raise ValueError(f"the board holds {len(found)} things, not 2")
	frame = cropped(board.crop((found[0][0], 0, found[0][1], board.height)))
	seal = cropped(board.crop((found[1][0], 0, found[1][1], board.height)))
	# The hole: what is see-through and cannot be reached from the frame's edge.
	clear = np.asarray(solid(frame)) == 0
	outside = Image.fromarray((clear * 255).astype(np.uint8)).copy()
	ImageDraw.floodfill(outside, (0, 0), 128)
	for corner in [(frame.width - 1, 0), (0, frame.height - 1), (frame.width - 1, frame.height - 1)]:
		if outside.getpixel(corner) == 255:
			ImageDraw.floodfill(outside, corner, 128)
	hole = Image.fromarray(((np.asarray(outside) == 255) * 255).astype(np.uint8))
	# A little under the frame's inner edge, so no gap shows between them.
	hole = hole.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(1.2))
	tall = round(frame.height * VIEW_WIDTH / frame.width)
	frame_target = HUB / "sortie" / "view_frame.png"
	hole_target = HUB / "sortie" / "view_hole.png"
	seal_target = HUB / "sortie" / "view_seal.png"
	frame.resize((VIEW_WIDTH, tall), Image.LANCZOS).save(frame_target)
	hole.resize((VIEW_WIDTH, tall), Image.LANCZOS).save(hole_target)
	seal.resize((SEAL_WIDTH, round(seal.height * SEAL_WIDTH / seal.width)), Image.LANCZOS).save(seal_target)
	return [frame_target, hole_target, seal_target]


def build_far() -> list[Path]:
	"""Where the far view through the hall's gate is, soft at its edge."""
	hall = np.asarray(Image.open(HUB / "lobby_hall.png").convert("RGB"), dtype=np.float32) / 255.0
	red, blue = hall[..., 0], hall[..., 2]
	tall, wide = red.shape
	ys, xs = np.mgrid[0:tall, 0:wide]
	u, v = xs / wide, ys / tall
	inside = (u > FAR_BOX[0]) & (v > FAR_BOX[1]) & (u < FAR_BOX[2]) & (v < FAR_BOX[3])
	far = Image.fromarray((((blue > red * 1.25) & (blue > 0.16) & inside) * 255).astype(np.uint8))
	# Closed over the towers that stand dark against the far light, then
	# drawn in a little from the arch's stone.
	far = far.filter(ImageFilter.MaxFilter(41)).filter(ImageFilter.MinFilter(49)).filter(ImageFilter.GaussianBlur(6))
	target = HUB / "lobby_hall_far.png"
	far.resize(FAR_SIZE, Image.LANCZOS).save(target)
	return [target]


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--measure", action="store_true", help="print where the pier's panel and ring are, and write nothing")
	arguments = parser.parse_args()
	if arguments.measure:
		print(measure_pillar())
		return
	for folder in ["title", "lobby", "sortie"]:
		(HUB / folder).mkdir(exist_ok=True)
	for build in [build_logo, build_pillar, build_icons, build_views, build_far]:
		for target in build():
			with Image.open(target) as written:
				print(f"{target.relative_to(ROOT)}  {written.width}x{written.height}")


if __name__ == "__main__":
	main()
