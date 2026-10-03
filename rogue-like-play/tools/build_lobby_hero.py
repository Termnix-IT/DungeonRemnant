"""Build the lobby heroine's textures from her generated illustration.

art/characters/source/ holds the transparent full-body illustration
(mio_lobby_source.png) and edits of it that change only her eyes:
mio_lobby_eyes_half.png, _closed, _left and _right. This writes, all
framed the same way (trimmed, with clear margins on the sides and top so
swaying hair never leaves the texture):

- art/characters/mio_lobby.png: everything but the long back hair.
- art/characters/mio_lobby_hair.png: the long back hair alone. It hangs
  behind her body, so nothing has to be painted in where it swings away.
- art/characters/mio_lobby_eyes.png: one cell per eye variant (half, closed,
  left, right), each the eye area with a feathered edge, so nothing else of
  the edits can differ from the illustration.
- art/characters/mio_lobby_pose_hilt.png, _pose_beret and _face_smile: the
  changed rectangle (PATCHES) of the edits mio_lobby_pose_hilt.png etc.,
  for the Random Idle gestures and the click smile; _pose_hilt_1/_2 and
  _pose_beret_1/_2 are the arm's in-between frames on the way there.
- art/characters/mio_lobby_motion.png: how far each body pixel may sway,
  read by ui/lobby_hero.gd. Red is the hair strands in front of her
  shoulder, green the coat and skirt hem; both grow towards the tips.

	python tools/build_lobby_hero.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "art" / "characters" / "source"
SOURCE = SOURCE_DIR / "mio_lobby_source.png"
EYE_VARIANTS = ["half", "closed", "left", "right"]
# Edits that change a larger area: a passing pose and an expression. Each is
# cut to its rectangle (trimmed figure pixels) and written as
# mio_lobby_<name>.png; ui/lobby_hero.gd places them at the same rectangles
# moved by MARGIN.
PATCHES = {
	"pose_hilt_1": (215, 300, 610, 770),
	"pose_hilt_2": (215, 300, 610, 770),
	"pose_hilt": (215, 300, 610, 770),
	"pose_beret_1": (415, 85, 690, 545),
	"pose_beret_2": (415, 85, 690, 545),
	"pose_beret": (415, 85, 690, 545),
	"face_smile": (295, 135, 455, 300),
}
OUTPUT = ROOT / "art" / "characters"
# Trim to the figure plus TRIM, then add MARGIN on the sides and top. The feet
# keep only TRIM below them, so the lobby can stand her on the floor.
TRIM = 8
MARGIN = 40
# In the trimmed figure's pixels (before MARGIN).
EYES = (298, 142, 427, 230)
# The long hair flowing down her left side, behind the sleeve and the coat.
BACK_HAIR_ZONE = (440, 240, 954, 940)
# Body parts inside that zone that are not dark cloth: the cuff, the skirt
# frill under the coat and her legs.
BODY_BOXES = [(470, 360, 580, 470), (440, 690, 620, 840), (440, 820, 640, 940)]
HAND = (420, 280, 580, 470)
# Where the body stops keeping the hair's pixels under the root.
ROOT_OVERLAP = 300.0
# How far the hair continues, hidden, under the coat and sleeve.
UNDER_REACH = 48
FRONT_HAIR = [(215, 190, 335, 700)]
FRONT_HAIR_EXCLUDE = [(225, 380, 315, 450)]
HAIR_ROOT, HAIR_TIP = 230.0, 820.0
HEM_REGION = (90, 560, 830, 860)
# The hand on the hilt and the hilt itself must not sway with the cloth.
HEM_EXCLUDE = [(215, 720, 335, 845)]
HEM_ROOT, HEM_TIP = 560.0, 830.0


def trimmed(path: Path, box: tuple[int, int, int, int] | None = None) -> tuple[Image.Image, tuple[int, int, int, int]]:
	image = Image.open(path).convert("RGBA")
	alpha = np.array(image.getchannel("A"))
	# The generator leaves solid pixels at 254; make them fully opaque.
	alpha[alpha >= 250] = 255
	image.putalpha(Image.fromarray(alpha))
	if box is None:
		x0, y0, x1, y1 = image.getchannel("A").getbbox()
		box = (max(0, x0 - TRIM), max(0, y0 - TRIM), min(image.width, x1 + TRIM), min(image.height, y1 + TRIM))
	return image.crop(box), box


def framed(image: Image.Image) -> Image.Image:
	canvas = Image.new("RGBA", (image.width + MARGIN * 2, image.height + MARGIN), (0, 0, 0, 0))
	canvas.paste(image, (MARGIN, MARGIN))
	return canvas


def ramp(values: np.ndarray, start: float, end: float) -> np.ndarray:
	t = np.clip((values - start) / (end - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def inside(shape: tuple[int, int], boxes: list[tuple[int, int, int, int]]) -> np.ndarray:
	mask = np.zeros(shape, dtype=bool)
	for x0, y0, x1, y1 in boxes:
		mask[y0:y1, x0:x1] = True
	return mask


def channels(figure: Image.Image) -> tuple[np.ndarray, ...]:
	rgba = np.array(figure).astype(np.float32) / 255.0
	r, g, b, a = rgba[..., 0], rgba[..., 1], rgba[..., 2], rgba[..., 3]
	light = (np.maximum(np.maximum(r, g), b) + np.minimum(np.minimum(r, g), b)) * 0.5
	return r, g, b, a, light


def grow(mask: np.ndarray, radius: float, threshold: int) -> np.ndarray:
	blurred = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))
	return np.array(blurred) > threshold


def back_hair(figure: Image.Image) -> np.ndarray:
	r, g, b, a, light = channels(figure)
	shape = a.shape
	# Her body here is dark cloth, the brown rim light on it, and the warm
	# hand and cuff; close the gaps between them into one region.
	core = (a > 0.5) & ((light < 0.3) | (((r - b) > 0.06) & (light < 0.62)) | (((r - b) > 0.03) & inside(shape, [HAND])))
	core |= inside(shape, BODY_BOXES) & (a > 0.5)
	body = grow(grow(core, 9, 40), 9, 215)
	# Keep a 2px seam on the body side so no cloth fringe swings with the hair.
	body = grow(body, 1.5, 20)
	hair = (a > 0.02) & inside(shape, [BACK_HAIR_ZONE]) & ~body
	cleaned = Image.fromarray((hair * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
	return np.array(cleaned).astype(np.float32) / 255.0


# The painting never shows the hair where the coat and sleeve cover it, so a
# swing would open a gap between them. Grow the hair's colours into the
# covered area, a pixel ring per step, so the layer continues under the body.
def hair_under_body(figure: Image.Image, hair: np.ndarray) -> Image.Image:
	rgba = np.array(figure).astype(np.float32) / 255.0
	colour = rgba[..., :3]
	r, g, b, a, light = channels(figure)
	shape = hair.shape
	# Grow only from clean lavender strands, not from edges tinted by the
	# coat's rim light, or orange streaks would spread under the cloth.
	filled = (hair > 0.5) & (a > 0.9) & (light > 0.6) & ((b - g) > 0.03) & ((b - r) > -0.02)
	covered = (a > 0.5) & (hair <= 0.5) & inside(shape, [BACK_HAIR_ZONE])
	result = colour * filled[..., None]
	for _ in range(UNDER_REACH):
		total = np.zeros_like(result)
		count = np.zeros(shape, dtype=np.float32)
		for dy in (-1, 0, 1):
			for dx in (-1, 0, 1):
				if dx == 0 and dy == 0:
					continue
				neighbour = np.roll(np.roll(filled, dy, axis=0), dx, axis=1)
				total += np.roll(np.roll(result, dy, axis=0), dx, axis=1) * neighbour[..., None]
				count += neighbour
		grow_now = covered & ~filled & (count > 0)
		result[grow_now] = total[grow_now] / count[grow_now][:, None]
		filled = filled | grow_now
	grown = filled & covered
	# Soften the grown colours so they read as hair in shadow, not streaks.
	soft = np.array(Image.fromarray((np.clip(result, 0.0, 1.0) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))).astype(np.float32) / 255.0
	result = np.where(grown[..., None], soft, colour)
	alpha = np.where(hair > 0.5, a * hair, grown.astype(np.float32))
	out = np.dstack([result, alpha])
	return Image.fromarray((np.clip(out, 0.0, 1.0) * 255).astype(np.uint8), "RGBA")


def layer(figure: Image.Image, weight: np.ndarray | float) -> Image.Image:
	rgba = np.array(figure).astype(np.float32)
	rgba[..., 3] *= weight
	return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def motion(figure: Image.Image) -> Image.Image:
	r, g, b, a, light = channels(figure)
	saturation = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
	shape = a.shape
	ys = np.arange(figure.height, dtype=np.float32)[:, None] * np.ones((1, figure.width), dtype=np.float32)
	# Lavender-white strands in front of her right shoulder.
	hair = (a > 0.05) & (light > 0.55) & (saturation < 0.32) & (b + 0.04 >= r)
	hair &= inside(shape, FRONT_HAIR) & ~inside(shape, FRONT_HAIR_EXCLUDE)
	hair_weight = hair * ramp(ys, HAIR_ROOT, HAIR_TIP)
	# The dark cloth of the coat and skirt; the silver blade stays still.
	hem = (a > 0.05) & (light < 0.3) & inside(shape, [HEM_REGION]) & ~inside(shape, HEM_EXCLUDE)
	hem_weight = hem * ramp(ys, HEM_ROOT, HEM_TIP)
	layers = []
	for weight in (hair_weight, hem_weight):
		image = Image.fromarray((weight * 255).astype(np.uint8))
		# Blur so neighbouring pixels move together instead of tearing apart.
		layers.append(image.filter(ImageFilter.GaussianBlur(10)))
	empty = Image.new("L", figure.size, 0)
	return Image.merge("RGBA", (layers[0], layers[1], empty, Image.new("L", figure.size, 255)))


# An edit can come back nudged by a few pixels. Find the shift that best lines
# up the face around the eyes (the eyes themselves differ on purpose).
def alignment(figure: Image.Image, edit: Image.Image, reach: int = 14, around: tuple[int, int, int, int] = EYES) -> tuple[int, int]:
	x0, y0, x1, y1 = around
	pad = 40
	x0, y0 = max(x0, pad + reach), max(y0, pad + reach)
	x1, y1 = min(x1, figure.width - pad - reach), min(y1, figure.height - pad - reach)
	original = np.array(figure.convert("RGB")).astype(np.float32)
	changed = np.array(edit.convert("RGB")).astype(np.float32)
	ring = np.ones((y1 - y0 + pad * 2, x1 - x0 + pad * 2), dtype=bool)
	ring[pad:-pad, pad:-pad] = False
	target = original[y0 - pad:y1 + pad, x0 - pad:x1 + pad]
	best = (0, 0)
	best_error = float("inf")
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			moved = changed[y0 - pad + dy:y1 + pad + dy, x0 - pad + dx:x1 + pad + dx]
			error = np.abs(moved - target).sum(axis=2)[ring].mean()
			if error < best_error:
				best, best_error = (dx, dy), error
	print("eyes", best, round(best_error, 1))
	return best


# The rectangle an edit changes, for choosing PATCHES: where it differs from
# the illustration once aligned, with room for the feathered edge.
def changed_area(figure: Image.Image, edit: Image.Image, shift: tuple[int, int], margin: int = 26) -> tuple[int, int, int, int]:
	original = np.array(figure).astype(np.float32)
	moved = np.array(edit.transform(edit.size, Image.AFFINE, (1, 0, shift[0], 0, 1, shift[1]))).astype(np.float32)
	difference = np.abs(original - moved).sum(axis=2)
	ys, xs = np.where(difference > 120)
	return (max(0, int(np.percentile(xs, 0.5)) - margin), max(0, int(np.percentile(ys, 0.5)) - margin), min(figure.width, int(np.percentile(xs, 99.5)) + margin), min(figure.height, int(np.percentile(ys, 99.5)) + margin))


def patch(figure: Image.Image, box: tuple[int, int, int, int], name: str, rect: tuple[int, int, int, int]) -> Image.Image:
	edit, _ = trimmed(SOURCE_DIR / f"mio_lobby_{name}.png", box)
	dx, dy = alignment(figure, edit, around=rect)
	print(name, "changed", changed_area(figure, edit, (dx, dy)))
	x0, y0, x1, y1 = rect
	return edit.crop((x0 + dx, y0 + dy, x1 + dx, y1 + dy))


def eye_atlas(box: tuple[int, int, int, int]) -> Image.Image:
	x0, y0, x1, y1 = EYES
	width, height = x1 - x0, y1 - y0
	feather = Image.new("L", (width, height), 0)
	feather.paste(255, (12, 10, width - 12, height - 10))
	feather = feather.filter(ImageFilter.GaussianBlur(8))
	atlas = Image.new("RGBA", (width * len(EYE_VARIANTS), height), (0, 0, 0, 0))
	figure, _ = trimmed(SOURCE, box)
	for index, name in enumerate(EYE_VARIANTS):
		edit, _ = trimmed(SOURCE_DIR / f"mio_lobby_eyes_{name}.png", box)
		dx, dy = alignment(figure, edit)
		cell = edit.crop((x0 + dx, y0 + dy, x1 + dx, y1 + dy))
		cell.putalpha(feather)
		atlas.paste(cell, (index * width, 0))
	return atlas


def main() -> None:
	figure, box = trimmed(SOURCE)
	hair = back_hair(figure)
	# Near the root the hair barely moves, so the body keeps those pixels too
	# and the two layers overlap there; a hard cut would show a seam.
	ys = np.arange(figure.height, dtype=np.float32)[:, None]
	overlap = 1.0 - ramp(ys, BACK_HAIR_ZONE[1] + 10.0, ROOT_OVERLAP)
	framed(layer(figure, 1.0 - hair * (1.0 - overlap))).save(OUTPUT / "mio_lobby.png", optimize=True)
	framed(hair_under_body(figure, hair)).save(OUTPUT / "mio_lobby_hair.png", optimize=True)
	framed(motion(figure)).save(OUTPUT / "mio_lobby_motion.png", optimize=True)
	eye_atlas(box).save(OUTPUT / "mio_lobby_eyes.png", optimize=True)
	for name, rect in PATCHES.items():
		patch(figure, box, name, rect).save(OUTPUT / f"mio_lobby_{name}.png", optimize=True)
	print("figure", figure.size, "framed", framed(figure).size)


if __name__ == "__main__":
	main()
