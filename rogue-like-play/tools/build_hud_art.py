"""Build the dungeon HUD's painted parts from their generated pictures.

The pictures in art/ui/source/ were made with Codex's image generation (see
開発メモ.md): the key caps, the HUD plates and the talisman medallion, the
minimap's frame and markers, the message log's ink band and marks, the
notice band at the screen's top edge, the level-up cards and their rank
pips, the result's seals and the floor's aim marks. All but the log's ink
band (black ink on white paper) and the aim marks (light on black, added
onto the floor) are painted on flat magenta (#FF00FF). The prompts' passage
pictures are cut from the floor tiles' own painted pictures. This keys the
backdrop out, cuts each part, fills the plates' empty insides with the HUD's
translucent ink, and scales every part to the size the game draws it,
writing art/ui/hud/*.png. The nine-patch margins in
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
# The notice band: notice_band.png holds two bands, one above the other: the
# usual one with blue gems, and the warning one with flame crests (a monster
# house, the guardian's floor). Both are drawn this tall.
NOTICE_HEIGHT = 80
# The stairs, guardian-door and exit prompts show the passage they ask about,
# cut from the floor tiles' painted pictures in art/tiles/source/.
PASSAGES = {"stairs": "descent_stairs.png", "guardian": "guardian_door.png", "exit": "return_door.png"}
PASSAGE_SIZE = 96
# Level-up cards: three frames (a new ability, a rank raised, the chosen card)
# built exactly as wide as a card, so the gem ornament in the middle of the
# top edge never stretches; the chosen frame stays clear inside, laid over.
CARD_WIDTH = 272
CARD_FILL = (16, 15, 13, 235)
GLOW = (255, 196, 102)
# How far down from the top, and across the middle, the chosen frame's gem lies.
GEM_REACH = 70
PIP_WIDTH = 24
# The seal over a run's result, and the light marks on the floor while aiming
# (painted on black; the game adds them onto the floor), at twice the tile.
SEAL_SIZE = 240
AIM_SIZE = 96
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


def filled(frame: Image.Image, fill: tuple[int, int, int, int] = FILL) -> Image.Image:
	"""The frame with its see-through middle filled with the HUD's ink."""
	solid = frame.getchannel("A").point(lambda value: 255 if value > 8 else 0)
	ImageDraw.floodfill(solid, (frame.width // 2, frame.height // 2), 128)
	inside = solid.point(lambda value: 255 if value == 128 else 0)
	# Reach under the frame's soft inner edge so no seam of floor shows.
	inside = inside.filter(ImageFilter.MaxFilter(7))
	ink = Image.new("RGBA", frame.size, fill)
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


def gilded_glow(image: Image.Image) -> Image.Image:
	"""The soft glow of the chosen card, painted over magenta, keeps a pink
	cast after keying; its see-through pixels take the warm gold it was."""
	rgba = np.asarray(image).astype(np.float32)
	red, green, blue = rgba[..., 0], rgba[..., 1], rgba[..., 2]
	# Soft pixels, and any left pink or salmon: bronze and gold keep their
	# blue well under their green, so more than that is the backdrop's tint.
	pink = (blue > green * 0.8) & (red > green)
	soft = (rgba[..., 3] > 0) & ((rgba[..., 3] < 235) | pink)
	rgba[soft, 0:3] = GLOW
	# The frame is laid over a card that has its own gem (blue for a new
	# ability, amber for a raised one): its own gem is cut out so the card's
	# shows through instead of mixing with it.
	top = rgba[:GEM_REACH, rgba.shape[1] // 2 - GEM_REACH // 2:rgba.shape[1] // 2 + GEM_REACH // 2]
	gem = (top[..., 0] > 170) & (top[..., 2] < 110) & (top[..., 0] - top[..., 1] > 50)
	if gem.any():
		rows, columns = np.nonzero(gem)
		left = rgba.shape[1] // 2 - GEM_REACH // 2
		rgba[max(rows.min() - 2, 0):rows.max() + 3, left + columns.min() - 2:left + columns.max() + 3, 3] = 0
	return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def lit(name: str) -> list[Image.Image]:
	"""Light painted on black, cut into its marks: the black stays black (it
	adds nothing), and each mark is trimmed to a square round its centre."""
	glow = Image.open(SOURCE / name).convert("RGB")
	bright = np.asarray(glow.convert("L")) > 18
	marks: list[Image.Image] = []
	for left, right in runs(bright.any(axis=0), 24):
		column = bright[:, left:right]
		top, bottom = runs(column.any(axis=1), 24)[0][0], runs(column.any(axis=1), 24)[-1][1]
		side = max(right - left, bottom - top)
		middle = ((left + right) // 2, (top + bottom) // 2)
		box = (middle[0] - side // 2, middle[1] - side // 2, middle[0] + side // 2, middle[1] + side // 2)
		marks.append(glow.crop(box).convert("RGBA"))
	return marks


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
	[[new, raised, chosen]] = pieces(keyed("ability_cards.png"))
	for image, name, fill in ((new, "card_new", True), (raised, "card_raise", True), (chosen, "card_chosen", False)):
		card = scaled(image, CARD_WIDTH / image.width)
		save(filled(card, CARD_FILL) if fill else gilded_glow(card), name)
	[[empty, full]] = pieces(keyed("ability_pips.png"))
	for image, name in ((empty, "pip_empty"), (full, "pip_full")):
		save(scaled(image, PIP_WIDTH / image.width), name)
	[seals] = pieces(keyed("result_seals.png"))
	for image, name in zip(seals, ("seal_clear", "seal_return", "seal_defeat"), strict=True):
		save(fit(image, SEAL_SIZE), name)
	for image, name in zip(lit("aim_marks.png"), ("aim_range", "aim_target"), strict=True):
		save(image.resize((AIM_SIZE, AIM_SIZE), Image.Resampling.LANCZOS), name)
	for name, source in PASSAGES.items():
		painted = trim(key_out(Image.open(ROOT / "art" / "tiles" / "source" / source), SPILL_REACH))
		save(fit(painted, PASSAGE_SIZE), f"passage_{name}")
	[[usual], [warning]] = pieces(keyed("notice_band.png"))
	for band, name in ((usual, "notice_band"), (warning, "notice_band_warning")):
		save(scaled(band, NOTICE_HEIGHT / band.height), name)


if __name__ == "__main__":
	build()
