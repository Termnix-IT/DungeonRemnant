"""Cut the front rig's parts from Mio's generated illustration and its layers.

art/characters/mio_rig/source/ holds the front base illustration
(front_base.png) and edits of it that each keep one layer, with what the
base hides painted in (front_hair.png: the long back hair alone, front_legs.png:
the legs up to the hips, front_body.png: head, torso and skirt without arms
or legs, front_arms.png: the two arms alone, used only to find where the
arms are), two eye edits
(front_eyes_half.png, front_eyes_closed.png) and the sword on its own
(front_sword.png). This aligns each layer to the base (an edit drifts by a
few pixels), cuts the parts, shrinks them to the rig's size and packs them:

- art/characters/mio_rig/front_parts.png: the atlas, mipmapped in Godot.
- art/characters/mio_rig/front_parts.json: each part's rectangle in the
  atlas and its place in the figure, the soles, and how source pixels map to
  the figure, for tools/build_character_rig.gd.
- .godot/mio_rig_parts_check.png: the parts put back together beside the
  base and their difference, to see that nothing moved or went missing.

	python tools/build_mio_rig_parts.py
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "characters" / "mio_rig" / "source"
OUTPUT = ROOT / "art" / "characters" / "mio_rig"
CHECK = ROOT / ".godot" / "mio_rig_parts_check.png"
LAYERS = ["hair", "legs", "body", "arms", "eyes_half", "eyes_closed"]
# The figure (beret to soles) in the rig's own pixels: about twice the largest height it is
# shown at (115 px on a 1920x1080 screen), so mipmaps always shrink it.
FIGURE_HEIGHT = 320
# Around each part in the atlas, so mipmaps never bleed one into another.
PAD = 6
FAINT = 24
ATLAS_WIDTH = 1024
# Measured on the base illustration (source pixels). The centre line splits
# the left and right hair, arms and legs.
CENTER_X = 519
# Head above the chin; the torso from under the chin down to the bottom of
# the belt; the skirt from the top of the belt. Each cut is feathered over
# FEATHER px where the part in front covers it, so a turn never shows an edge.
CHIN_Y = 760
NECK_Y = 700
BELT_TOP_Y = 900
BELT_BOTTOM_Y = 965
FEATHER = 24
# Around the arms edit's sleeves, where the arms cut from the base may be;
# and the closing that fills the cuffs (odd sizes, source pixels).
ARM_REACH = 41
ARM_CLOSE = 15
EYES = (345, 578, 695, 682)
# The sword: its picture's grip and tip (source pixels of front_sword.png),
# and where its grip goes in the figure: her right hand, on the screen's
# left, the blade hanging down and out. Left and right in part and bone
# names are the screen's.
SWORD_GRIP = (512, 215)
SWORD_TIP = (512, 1478)
SWORD_HAND = (262, 1085)
SWORD_ANGLE = 34.0
SWORD_LENGTH = 430.0
# The slender blade would be a pixel or two wide in the dungeon; widen it.
SWORD_WIDTH = 1.5


def load(name: str) -> Image.Image:
	image = Image.open(SOURCE / f"front_{name}.png").convert("RGBA")
	alpha = np.array(image.getchannel("A"))
	# The generator leaves solid pixels at 254; make them fully opaque. Its
	# edits also leave a faint haze (alpha under FAINT) across the canvas,
	# which would widen every part's box and float a halo round it.
	alpha[alpha >= 250] = 255
	alpha[alpha < FAINT] = 0
	image.putalpha(Image.fromarray(alpha))
	return image


def shifted(image: Image.Image, dx: int, dy: int) -> Image.Image:
	canvas = Image.new("RGBA", image.size, (0, 0, 0, 0))
	canvas.paste(image, (dx, dy))
	return canvas


# The shift that best lays a layer over the base, judged on the pixels both
# show solidly: coarse on a quarter-size image, then refined.
def align(layer: Image.Image, base: Image.Image, reach: int = 48) -> tuple[int, int]:
	def arrays(image: Image.Image, factor: int) -> tuple[np.ndarray, np.ndarray]:
		small = image.resize((image.width // factor, image.height // factor), Image.BILINEAR)
		rgba = np.asarray(small).astype(np.float32) / 255.0
		return rgba[..., :3].mean(axis=2), rgba[..., 3]

	def cost(light_a, alpha_a, light_b, alpha_b, dx, dy) -> float:
		moved_light = np.roll(np.roll(light_a, dy, axis=0), dx, axis=1)
		moved_alpha = np.roll(np.roll(alpha_a, dy, axis=0), dx, axis=1)
		both = (moved_alpha > 0.8) & (alpha_b > 0.8)
		if both.sum() < 64:
			return float("inf")
		return float(np.abs(moved_light - light_b)[both].mean())

	best = (0, 0)
	for factor, span, centre in ((4, reach // 4, (0, 0)), (1, 5, None)):
		light_a, alpha_a = arrays(layer, factor)
		light_b, alpha_b = arrays(base, factor)
		cx, cy = (best[0] // factor, best[1] // factor) if centre is None else centre
		scores = {}
		for dy in range(cy - span, cy + span + 1):
			for dx in range(cx - span, cx + span + 1):
				scores[(dx, dy)] = cost(light_a, alpha_a, light_b, alpha_b, dx, dy)
		found = min(scores, key=scores.get)
		best = (found[0] * factor, found[1] * factor) if factor > 1 else found
	return best


def ramp(values: np.ndarray, start: float, end: float) -> np.ndarray:
	t = np.clip((values - start) / (end - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# A copy of the image keeping only the rows from top to bottom (None: no
# limit), faded over FEATHER px past each edge that has fade set.
def band(image: Image.Image, top: float | None, bottom: float | None, fade_top: bool = False, fade_bottom: bool = False,
		left: float | None = None, right: float | None = None) -> Image.Image:
	rgba = np.asarray(image).astype(np.float32)
	rows = np.arange(image.height, dtype=np.float32)[:, None]
	columns = np.arange(image.width, dtype=np.float32)[None, :]
	keep = np.ones((image.height, image.width), dtype=np.float32)
	if top is not None:
		keep *= ramp(rows, top - FEATHER, top) if fade_top else (rows >= top)
	if bottom is not None:
		keep *= 1.0 - ramp(rows, bottom, bottom + FEATHER) if fade_bottom else (rows < bottom)
	if left is not None:
		keep *= columns >= left
	if right is not None:
		keep *= columns < right
	rgba[..., 3] *= keep
	return Image.fromarray(rgba.astype(np.uint8))


# Shrink in premultiplied colour, so transparent pixels never darken an edge.
def shrink(image: Image.Image, scale: float) -> Image.Image:
	size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
	rgba = np.asarray(image).astype(np.float32) / 255.0
	alpha = rgba[..., 3]
	planes = [Image.fromarray(rgba[..., index] * alpha) for index in range(3)] + [Image.fromarray(alpha)]
	small = [np.asarray(plane.resize(size, Image.LANCZOS)) for plane in planes]
	small_alpha = np.clip(small[3], 0.0, 1.0)
	colour = np.stack([np.clip(small[index] / np.maximum(small_alpha, 1e-4), 0.0, 1.0) for index in range(3)], axis=2)
	out = np.dstack([colour, small_alpha])
	return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8))


def sword_in_figure(base: Image.Image) -> Image.Image:
	sword = load("sword")
	grip = np.array(SWORD_GRIP, dtype=np.float32)
	tip = np.array(SWORD_TIP, dtype=np.float32)
	length = float(np.linalg.norm(tip - grip))
	scale = SWORD_LENGTH / length
	sword = sword.resize((round(sword.width * scale * SWORD_WIDTH), round(sword.height * scale)), Image.LANCZOS)
	grip *= (scale * SWORD_WIDTH, scale)
	tip *= (scale * SWORD_WIDTH, scale)
	# Turn it so the blade hangs at SWORD_ANGLE from straight down, outward.
	current = np.degrees(np.arctan2(tip[0] - grip[0], tip[1] - grip[1]))
	turn = -SWORD_ANGLE - current
	canvas = Image.new("RGBA", base.size, (0, 0, 0, 0))
	offset = (round(SWORD_HAND[0] - grip[0]), round(SWORD_HAND[1] - grip[1]))
	canvas.paste(sword, offset, sword)
	return canvas.rotate(turn, resample=Image.BICUBIC, center=SWORD_HAND)


# The arms edit came back redrawn (sleeves of another shape, the hands
# higher), so the arms are cut from the base itself: what the base shows and
# the body layer does not, near where the edit put the arms, leaving out the
# lavender hair between them. Closing the mask fills the white cuffs, which
# are nearly the hair's colour.
def arms_from_base(base: Image.Image, body: Image.Image, arms: Image.Image) -> Image.Image:
	rgba = np.asarray(base).astype(np.float32) / 255.0
	light = rgba[..., :3].mean(axis=2)
	hair = (rgba[..., 2] - rgba[..., 1] > 0.035) & (light > 0.6)
	near = grow(np.asarray(arms.getchannel("A")) > 128, ARM_REACH)
	shown = (rgba[..., 3] > 0.05) & (np.asarray(body.getchannel("A")) < 128) & near
	closed = shrink_mask(grow(shown & ~hair, ARM_CLOSE), ARM_CLOSE) & shown
	out = rgba.copy()
	out[..., 3] *= closed
	return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8))


def grow(mask: np.ndarray, size: int) -> np.ndarray:
	return np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(size))) > 0


def shrink_mask(mask: np.ndarray, size: int) -> np.ndarray:
	return np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MinFilter(size))) > 0


def cut_parts(base: Image.Image, layers: dict[str, Image.Image]) -> dict[str, Image.Image]:
	hair, legs, body = layers["hair"], layers["legs"], layers["body"]
	arms = arms_from_base(base, body, layers["arms"])
	eyes = {"EyesOpen": base, "EyesHalf": layers["eyes_half"], "EyesClosed": layers["eyes_closed"]}
	x0, y0, x1, y1 = EYES
	parts = {
		"HairBackL": band(hair, None, None, right=CENTER_X),
		"HairBackR": band(hair, None, None, left=CENTER_X),
		"LegL": band(legs, None, None, right=CENTER_X),
		"LegR": band(legs, None, None, left=CENTER_X),
		"Skirt": band(body, BELT_TOP_Y, None),
		"Torso": band(body, NECK_Y, BELT_BOTTOM_Y, fade_bottom=True),
		"ArmL": band(arms, None, None, right=CENTER_X),
		"ArmR": band(arms, None, None, left=CENTER_X),
		"Sword": sword_in_figure(base),
		"Head": band(body, None, CHIN_Y, fade_bottom=True),
	}
	for name, source in eyes.items():
		parts[name] = band(source, y0, y1, left=x0, right=x1)
	return parts


# Shelves left to right, tallest first.
def pack(pieces: dict[str, Image.Image]) -> tuple[Image.Image, dict[str, list[int]]]:
	order = sorted(pieces, key=lambda name: -pieces[name].height)
	places: dict[str, list[int]] = {}
	x = y = shelf = 0
	for name in order:
		piece = pieces[name]
		if x + piece.width + PAD * 2 > ATLAS_WIDTH:
			x, y, shelf = 0, y + shelf, 0
		places[name] = [x + PAD, y + PAD, piece.width, piece.height]
		x += piece.width + PAD * 2
		shelf = max(shelf, piece.height + PAD * 2)
	height = 1 << int(np.ceil(np.log2(max(1, y + shelf))))
	atlas = Image.new("RGBA", (ATLAS_WIDTH, height), (0, 0, 0, 0))
	for name, (px, py, _, _) in places.items():
		atlas.paste(pieces[name], (px, py))
	return atlas, places


def main() -> None:
	base = load("base")
	layers = {}
	for name in LAYERS:
		layer = load(name)
		dx, dy = align(layer, base)
		print(f"front_{name}.png: moved by ({dx}, {dy})")
		layers[name] = shifted(layer, dx, dy)
	parts = cut_parts(base, layers)
	frame = base.getchannel("A").getbbox()
	for part in parts.values():
		box = part.getchannel("A").getbbox()
		if box:
			frame = (min(frame[0], box[0]), min(frame[1], box[1]), max(frame[2], box[2]), max(frame[3], box[3]))
	# The figure is from the top of the beret to the soles.
	soles = (layers["legs"].getchannel("A").getbbox() or frame)[3]
	scale = FIGURE_HEIGHT / (soles - base.getchannel("A").getbbox()[1])
	pieces: dict[str, Image.Image] = {}
	at: dict[str, list[int]] = {}
	for name, part in parts.items():
		box = part.getchannel("A").getbbox()
		if box is None:
			raise SystemExit(f"Part {name} is empty")
		# Snap the box to whole figure pixels so a part lands where it was cut.
		left = frame[0] + np.floor((box[0] - frame[0]) * scale) / scale
		top = frame[1] + np.floor((box[1] - frame[1]) * scale) / scale
		right = frame[0] + np.ceil((box[2] - frame[0]) * scale) / scale
		bottom = frame[1] + np.ceil((box[3] - frame[1]) * scale) / scale
		crop = part.crop((round(left), round(top), round(right), round(bottom)))
		pieces[name] = shrink(crop, scale)
		at[name] = [round((left - frame[0]) * scale), round((top - frame[1]) * scale)]
	atlas, places = pack(pieces)
	atlas.save(OUTPUT / "front_parts.png")
	layout = {
		"source_origin": [frame[0], frame[1]],
		"scale": scale,
		"figure_height": FIGURE_HEIGHT,
		"feet": [round((CENTER_X - frame[0]) * scale, 2), round((soles - frame[1]) * scale, 2)],
		"parts": {name: {"atlas": places[name], "at": at[name]} for name in parts},
	}
	(OUTPUT / "front_parts.json").write_text(json.dumps(layout, indent="\t") + "\n", encoding="utf-8", newline="\n")
	write_check(base, parts, frame)
	print(f"{len(parts)} parts, atlas {atlas.width}x{atlas.height}, scale {scale:.4f}")


# The parts drawn back in the rig's order beside the base and the difference.
def write_check(base: Image.Image, parts: dict[str, Image.Image], frame: tuple[int, int, int, int]) -> None:
	order = ["HairBackL", "HairBackR", "LegL", "LegR", "Skirt", "Torso", "Sword", "ArmL", "ArmR", "Head", "EyesOpen"]
	rebuilt = Image.new("RGBA", base.size, (0, 0, 0, 0))
	for name in order:
		rebuilt.alpha_composite(parts[name])
	a = np.asarray(base).astype(np.float32)
	b = np.asarray(rebuilt).astype(np.float32)
	# Compare premultiplied, so colour left in clear pixels does not count.
	a[..., :3] *= a[..., 3:] / 255.0
	b[..., :3] *= b[..., 3:] / 255.0
	difference = np.abs(a - b).max(axis=2)
	heat = Image.fromarray(np.clip(difference * 2.0, 0, 255).astype(np.uint8)).convert("RGBA")
	backdrop = Image.new("RGBA", base.size, (40, 44, 52, 255))
	panels = [Image.alpha_composite(backdrop, base), Image.alpha_composite(backdrop, rebuilt), heat]
	check = Image.new("RGBA", (base.width * 3, base.height), (0, 0, 0, 255))
	for index, panel in enumerate(panels):
		check.paste(panel, (index * base.width, 0))
	CHECK.parent.mkdir(exist_ok=True)
	check.crop((0, frame[1], check.width, frame[3])).save(CHECK)


if __name__ == "__main__":
	main()
