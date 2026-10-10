"""Build the dungeon HUD's painted parts from their generated pictures.

The pictures in art/ui/source/ were made with Codex's image generation (see
開発メモ.md): the key caps, the HUD plates and the talisman medallion, the
minimap's frame and markers, and the message log's ink band and marks. All
but the ink band are painted on flat magenta (#FF00FF); the band is black ink
on white paper. This keys the backdrop out, cuts each part, fills the plates'
empty insides with the HUD's translucent ink, and scales every part to the
size the game draws it, writing art/ui/hud/*.png. The nine-patch margins in
ui/theme/dungeon_theme.tres follow the sizes printed here; update them
whenever a picture changes.

	python tools/build_hud_art.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from build_stage_dioramas import key_out

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source"
OUTPUT = ROOT / "art" / "ui" / "hud"
SPILL_REACH = 2
# The ink the HUD has always sat on: a warm near-black the floor shows through.
FILL = (13, 12, 11, 200)
# Key caps: drawn this tall (two pixels more than a line of 16px text).
CAP_HEIGHT = 30
# Plates are scaled so the corner brackets come out this many pixels wide.
PLATE_SCALE = 0.42
# The map frame is laid over the map (its compass sits on the map's corner),
# so its middle stays clear; the panel under the map gives the ink.
MAP_SCALE = 0.21
MEDALLION_SIZE = 44
# The minimap draws each marker at its built size; the hero largest.
MARKER_SIZES = {"stairs": 15, "enemy": 13, "item": 11, "player": 17}
MARKER_ORDER = ["stairs", "enemy", "item", "player"]
LOG_MARK_SIZE = 18
LOG_MARKS = ["victory", "harm", "floor", "supply", "news"]
# The ink band is scaled to this height; its frayed ends overhang the log.
BAND_HEIGHT = 150
BAND_ALPHA = 0.84


def keyed(name: str) -> Image.Image:
	return key_out(Image.open(SOURCE / name), SPILL_REACH)


def trim(image: Image.Image) -> Image.Image:
	box = image.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
	return image.crop(box)


def runs(filled: np.ndarray, gap: int) -> list[tuple[int, int]]:
	"""The spans of filled lines, joining spans parted by fewer than gap."""
	spans: list[list[int]] = []
	for index in np.flatnonzero(filled):
		if spans and index - spans[-1][1] <= gap:
			spans[-1][1] = index + 1
		else:
			spans.append([int(index), int(index) + 1])
	return [(start, end) for start, end in spans]


def pieces(image: Image.Image, gap: int = 12) -> list[list[Image.Image]]:
	"""The parts of a picture, row by row, each trimmed to what it holds.

	Parts are found by the clear rows and columns between them, so a part
	may reach past an even share of the picture (the crossed swords do)."""
	alpha = np.asarray(image.getchannel("A")) > 8
	found: list[list[Image.Image]] = []
	for top, bottom in runs(alpha.any(axis=1), gap):
		band = alpha[top:bottom]
		found.append([trim(image.crop((left, top, right, bottom))) for left, right in runs(band.any(axis=0), gap)])
	return found


def scaled(image: Image.Image, factor: float) -> Image.Image:
	size = (max(1, round(image.width * factor)), max(1, round(image.height * factor)))
	return image.resize(size, Image.Resampling.LANCZOS)


def fit(image: Image.Image, extent: int) -> Image.Image:
	"""Scaled to fit a square of extent pixels, centred on a clear square."""
	factor = extent / max(image.size)
	small = scaled(image, factor)
	square = Image.new("RGBA", (extent, extent))
	square.alpha_composite(small, ((extent - small.width) // 2, (extent - small.height) // 2))
	return square


def filled(frame: Image.Image) -> Image.Image:
	"""The frame with its see-through middle filled with the HUD's ink."""
	solid = frame.getchannel("A").point(lambda value: 255 if value > 8 else 0)
	ImageDraw.floodfill(solid, (frame.width // 2, frame.height // 2), 128)
	inside = solid.point(lambda value: 255 if value == 128 else 0)
	# Reach under the frame's soft inner edge so no seam of floor shows.
	inside = inside.filter(ImageFilter.MaxFilter(7))
	ink = Image.new("RGBA", frame.size, FILL)
	under = Image.new("RGBA", frame.size)
	under.paste(ink, mask=inside)
	under.alpha_composite(frame)
	return under


def ink_band() -> Image.Image:
	paper = np.asarray(Image.open(SOURCE / "log_band.png").convert("L"), dtype=np.float32) / 255.0
	darkness = 1.0 - paper
	# The brushed middle is the darkest even run; it becomes BAND_ALPHA.
	peak = np.percentile(darkness[darkness > 0.2], 60)
	alpha = np.clip(darkness / max(peak, 1e-3), 0.0, 1.0) * BAND_ALPHA
	alpha[darkness < 0.04] = 0.0
	rgba = np.zeros(paper.shape + (4,), dtype=np.uint8)
	rgba[..., 0:3] = FILL[:3]
	rgba[..., 3] = (alpha * 255.0).round().astype(np.uint8)
	band = trim(Image.fromarray(rgba, "RGBA"))
	return scaled(band, BAND_HEIGHT / band.height)


def save(image: Image.Image, name: str) -> None:
	OUTPUT.mkdir(parents=True, exist_ok=True)
	image.save(OUTPUT / f"{name}.png")
	print(f"{name}.png {image.size}")


def build() -> None:
	[[normal, active]] = pieces(keyed("key_caps.png"))
	for image, name in ((normal, "key_cap"), (active, "key_cap_active")):
		save(scaled(image, CAP_HEIGHT / image.height), name)
	[[normal, active], [medallion]] = pieces(keyed("hud_plates.png"))
	save(filled(scaled(normal, PLATE_SCALE)), "plate")
	save(filled(scaled(active, PLATE_SCALE)), "plate_active")
	save(fit(medallion, MEDALLION_SIZE), "medallion")
	save(scaled(trim(keyed("map_frame.png")), MAP_SCALE), "map_frame")
	icons = [icon for row in pieces(keyed("map_markers.png")) for icon in row]
	for name, icon in zip(MARKER_ORDER, icons, strict=True):
		save(fit(icon, MARKER_SIZES[name]), f"map_{name}")
	[marks] = pieces(keyed("log_marks.png"))
	for name, icon in zip(LOG_MARKS, marks, strict=True):
		save(fit(icon, LOG_MARK_SIZE), f"log_{name}")
	save(ink_band(), "log_band")


if __name__ == "__main__":
	build()
