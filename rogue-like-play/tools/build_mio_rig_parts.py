"""Cut Mio's rig parts, one facing at a time, from her generated illustrations.

art/characters/mio_rig/source/ holds, for each facing drawn (front, back,
left, front_left, back_left; the right-hand facings are these mirrored), a
base illustration (<facing>_base.png) and edits of it that each keep one
layer, with what the base hides painted in: <facing>_hair.png (the long hair
alone), _legs.png (the legs up to the hips), _body.png (head, torso and skirt
without arms or legs, and without the flower and ribbon where they are cut
apart), _arms.png (the arms alone, used only to find where the arms are),
and for faces the eye edits _eyes_half.png and _eyes_closed.png. The sword
(front_sword.png) is drawn once. This aligns each layer to its base (an edit
drifts by a few pixels), cuts the parts as FACINGS says, shrinks them to the
rig's size and packs them:

- art/characters/mio_rig/<facing>_parts.png: the atlas, mipmapped in Godot.
- art/characters/mio_rig/<facing>_parts.json: each part's rectangle in the
  atlas and its place in the figure, the soles, and how source pixels map to
  the figure, for tools/build_character_rig.gd.
- .godot/mio_rig_<facing>_parts_check.png: the parts put back together in the
  rig's drawing order beside the base and their difference.

	python tools/build_mio_rig_parts.py [facing ...]

With no facing, every facing whose base exists is built. A facing whose
layers are not all made yet is cut as its base in one piece (WHOLE_PARTS).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "characters" / "mio_rig" / "source"
OUTPUT = ROOT / "art" / "characters" / "mio_rig"
CHECKS = ROOT / ".godot"
# The figure (beret to soles) in the rig's own pixels: about twice the
# largest height it is shown at (115 px on a 1920x1080 screen), so mipmaps
# always shrink it.
FIGURE_HEIGHT = 320
# Around each part in the atlas, so mipmaps never bleed one into another.
PAD = 6
FAINT = 24
ATLAS_WIDTH = 1024
# Where a part in front covers a cut, the cut fades over FEATHER px, so a
# turn never shows an edge.
FEATHER = 24
# Around the arms edit's sleeves, where the arms cut from the base may be;
# and the closing that fills the cuffs (odd sizes, source pixels).
ARM_REACH = 41
ARM_CLOSE = 15
# The sword's picture: its grip and tip (source pixels of front_sword.png).
SWORD_GRIP = (512, 215)
SWORD_TIP = (512, 1478)
# The slender blade would be a pixel or two wide in the dungeon; widen it.
SWORD_WIDTH = 1.5

# Each facing's cuts, measured on its base (source pixels). A part is
# (source, region): the source is a layer, "arms" (the arms cut from the
# base), "ornament" (the flower and ribbon cut from the base), "sword", or
# "eyes:<layer>" (the eye box of that layer); the region keeps the rows from
# top to bottom and the columns from left to right, fading the edges named in
# "fade". center_x is the line between the soles. Left and right in part
# names are the screen's.
FACINGS: dict[str, dict] = {
	"front": {
		"center_x": 519,
		"layers": ["hair", "legs", "body", "arms", "eyes_half", "eyes_closed"],
		"eyes": (345, 578, 695, 682),
		# Her right hand, on the screen's left, the blade hanging down and out.
		"sword": {"hand": (262, 1085), "angle": 34.0, "length": 430.0},
		"parts": {
			"HairBackL": ("hair", {"right": 519}),
			"HairBackR": ("hair", {"left": 519}),
			"LegL": ("legs", {"right": 519}),
			"LegR": ("legs", {"left": 519}),
			# Head above the chin; the torso from under the chin down to the
			# bottom of the belt; the skirt from the top of the belt.
			"Skirt": ("body", {"top": 900}),
			"Torso": ("body", {"top": 700, "bottom": 965, "fade": ["bottom"]}),
			"ArmL": ("arms", {"right": 519}),
			"ArmR": ("arms", {"left": 519}),
			"Sword": ("sword", {}),
			"Head": ("body", {"bottom": 760, "fade": ["bottom"]}),
			"EyesOpen": ("eyes:base", {}),
			"EyesHalf": ("eyes:eyes_half", {}),
			"EyesClosed": ("eyes:eyes_closed", {}),
		},
	},
	# Turned toward the screen's left: her right hand, on the screen's left,
	# holds the sword ahead of her; the flower and ribbon are cut apart so the
	# mirrored front_right can hide them.
	"front_left": {
		"center_x": 515,
		"layers": ["hair", "legs", "body", "arms", "eyes_half", "eyes_closed"],
		"eyes": (295, 560, 565, 672),
		"ornament": (620, 410, 885, 780),
		"sword": {"hand": (240, 1080), "angle": 30.0, "length": 430.0},
		"parts": {
			"HairBackL": ("hair", {"right": 515}),
			"HairBackR": ("hair", {"left": 515}),
			"LegL": ("legs", {"right": 515}),
			"LegR": ("legs", {"left": 515}),
			"Skirt": ("body", {"top": 905}),
			"Torso": ("body", {"top": 700, "bottom": 965, "fade": ["bottom"]}),
			"ArmL": ("arms", {"right": 470}),
			"ArmR": ("arms", {"left": 470}),
			"Sword": ("sword", {}),
			"Head": ("body", {"bottom": 760, "fade": ["bottom"]}),
			"Ornament": ("ornament", {}),
			"EyesOpen": ("eyes:base", {}),
			"EyesHalf": ("eyes:eyes_half", {}),
			"EyesClosed": ("eyes:eyes_closed", {}),
		},
	},
	# A full side view facing the screen's left: the near (left) hand holds
	# the sword ahead of her; the far arm is behind the body.
	"left": {
		"center_x": 515,
		"layers": ["hair", "legs", "body", "arms", "eyes_half", "eyes_closed"],
		"eyes": (380, 555, 510, 660),
		"ornament": (560, 395, 805, 760),
		"sword": {"hand": (553, 1085), "angle": 25.0, "length": 430.0},
		"parts": {
			"HairBack": ("hair", {}),
			"LegFar": ("legs", {"right": 497}),
			"LegNear": ("legs", {"left": 497}),
			"Skirt": ("body", {"top": 905}),
			"Torso": ("body", {"top": 700, "bottom": 965, "fade": ["bottom"]}),
			"Head": ("body", {"bottom": 760, "fade": ["bottom"]}),
			"Ornament": ("ornament", {}),
			"EyesOpen": ("eyes:base", {}),
			"EyesHalf": ("eyes:eyes_half", {}),
			"EyesClosed": ("eyes:eyes_closed", {}),
			"Sword": ("sword", {}),
			"ArmNear": ("arms", {}),
		},
	},
	# From behind: the long hair hangs over the back, so it is drawn over the
	# body; her right hand, on the screen's right, holds the sword.
	"back": {
		"center_x": 513,
		"layers": ["hair", "legs", "body", "arms"],
		"sword": {"hand": (773, 1013), "angle": -30.0, "length": 430.0},
		"parts": {
			"LegL": ("legs", {"right": 513}),
			"LegR": ("legs", {"left": 513}),
			"Skirt": ("body", {"top": 905}),
			"Torso": ("body", {"top": 700, "bottom": 965, "fade": ["bottom"]}),
			"HairBackL": ("hair", {"right": 513}),
			"HairBackR": ("hair", {"left": 513}),
			"ArmL": ("arms", {"right": 513}),
			"Sword": ("sword", {}),
			"ArmR": ("arms", {"left": 513}),
			"Head": ("body", {"bottom": 740, "fade": ["bottom"]}),
		},
	},
	# From behind, turned toward the screen's left: the near (left) hand, on
	# the screen's left, holds the sword; the flower and ribbon are cut apart
	# for the mirrored back_right.
	"back_left": {
		"center_x": 495,
		"layers": ["hair", "legs", "body", "arms"],
		"ornament": (335, 355, 595, 700),
		"sword": {"hand": (200, 1067), "angle": 30.0, "length": 430.0},
		"parts": {
			"ArmFar": ("arms", {"left": 600}),
			"LegL": ("legs", {"right": 495}),
			"LegR": ("legs", {"left": 495}),
			"Skirt": ("body", {"top": 905}),
			"Torso": ("body", {"top": 700, "bottom": 965, "fade": ["bottom"]}),
			"HairBack": ("hair", {}),
			"Sword": ("sword", {}),
			"ArmNear": ("arms", {"right": 600}),
			"Head": ("body", {"bottom": 740, "fade": ["bottom"]}),
			"Ornament": ("ornament", {}),
		},
	},
}
# A facing whose layers are not made yet is cut as one picture of its base
# (on the hip) and the sword, so all eight facings can be seen and switched
# before the layers come. It cannot hide the flower when mirrored.
WHOLE_PARTS = {"Whole": ("base", {}), "Sword": ("sword", {})}


def load(name: str) -> Image.Image:
	image = Image.open(SOURCE / f"{name}.png").convert("RGBA")
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


# A copy of the image keeping only the region's rows and columns, faded over
# FEATHER px past each edge named in its "fade".
def band(image: Image.Image, region: dict) -> Image.Image:
	rgba = np.asarray(image).astype(np.float32)
	rows = np.arange(image.height, dtype=np.float32)[:, None]
	columns = np.arange(image.width, dtype=np.float32)[None, :]
	keep = np.ones((image.height, image.width), dtype=np.float32)
	fade = region.get("fade", [])
	if "top" in region:
		top = region["top"]
		keep *= ramp(rows, top - FEATHER, top) if "top" in fade else (rows >= top)
	if "bottom" in region:
		bottom = region["bottom"]
		keep *= 1.0 - ramp(rows, bottom, bottom + FEATHER) if "bottom" in fade else (rows < bottom)
	if "left" in region:
		keep *= columns >= region["left"]
	if "right" in region:
		keep *= columns < region["right"]
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


# The sword turned so its blade hangs at the angle from straight down,
# outward, with its grip in the hand.
def sword_in_figure(base: Image.Image, placing: dict) -> Image.Image:
	sword = load("front_sword")
	grip = np.array(SWORD_GRIP, dtype=np.float32)
	tip = np.array(SWORD_TIP, dtype=np.float32)
	scale = placing["length"] / float(np.linalg.norm(tip - grip))
	sword = sword.resize((round(sword.width * scale * SWORD_WIDTH), round(sword.height * scale)), Image.LANCZOS)
	grip *= (scale * SWORD_WIDTH, scale)
	tip *= (scale * SWORD_WIDTH, scale)
	current = np.degrees(np.arctan2(tip[0] - grip[0], tip[1] - grip[1]))
	hand = placing["hand"]
	canvas = Image.new("RGBA", base.size, (0, 0, 0, 0))
	canvas.paste(sword, (round(hand[0] - grip[0]), round(hand[1] - grip[1])), sword)
	return canvas.rotate(-placing["angle"] - current, resample=Image.BICUBIC, center=hand)


# The arms edits come back redrawn (sleeves of another shape, the hands
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
	return masked(rgba, closed)


# The flower and ribbon, cut from the base inside their box where the body
# layer (painted without them) differs, so the mirrored facings can hide them.
def ornament_from_base(base: Image.Image, body: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
	rgba = np.asarray(base).astype(np.float32) / 255.0
	under = np.asarray(body).astype(np.float32) / 255.0
	change = np.abs(rgba[..., :3] * rgba[..., 3:] - under[..., :3] * under[..., 3:]).max(axis=2) > 0.12
	inside = np.zeros(change.shape, dtype=bool)
	inside[box[1]:box[3], box[0]:box[2]] = True
	shown = (rgba[..., 3] > 0.05) & inside
	closed = shrink_mask(grow(change & shown, 9), 9) & shown
	return masked(rgba, closed)


def masked(rgba: np.ndarray, mask: np.ndarray) -> Image.Image:
	out = rgba.copy()
	out[..., 3] *= mask
	return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8))


def grow(mask: np.ndarray, size: int) -> np.ndarray:
	return np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(size))) > 0


def shrink_mask(mask: np.ndarray, size: int) -> np.ndarray:
	return np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MinFilter(size))) > 0


def cut_parts(facing: dict, base: Image.Image, layers: dict[str, Image.Image]) -> dict[str, Image.Image]:
	sources = dict(layers, base=base)
	if "arms" in layers:
		sources["arms"] = arms_from_base(base, layers["body"], layers["arms"])
	if "ornament" in facing:
		sources["ornament"] = ornament_from_base(base, layers["body"], facing["ornament"])
	parts = {}
	for name, (source, region) in facing["parts"].items():
		if source == "sword":
			parts[name] = sword_in_figure(base, facing["sword"])
		elif source.startswith("eyes:"):
			x0, y0, x1, y1 = facing["eyes"]
			parts[name] = band(sources[source[5:]], {"top": y0, "bottom": y1, "left": x0, "right": x1})
		else:
			parts[name] = band(sources[source], region)
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


def build(name: str) -> None:
	facing = dict(FACINGS[name])
	base = load(f"{name}_base")
	missing = [layer for layer in facing["layers"] if not (SOURCE / f"{name}_{layer}.png").exists()]
	if missing:
		print(f"{name}: no {', '.join(missing)} yet; cut as one picture")
		facing["layers"] = []
		facing["parts"] = WHOLE_PARTS
		facing.pop("ornament", None)
	layers = {}
	for layer_name in facing["layers"]:
		layer = load(f"{name}_{layer_name}")
		dx, dy = align(layer, base)
		print(f"{name}_{layer_name}.png: moved by ({dx}, {dy})")
		layers[layer_name] = shifted(layer, dx, dy)
	parts = cut_parts(facing, base, layers)
	frame = base.getchannel("A").getbbox()
	for part in parts.values():
		box = part.getchannel("A").getbbox()
		if box:
			frame = (min(frame[0], box[0]), min(frame[1], box[1]), max(frame[2], box[2]), max(frame[3], box[3]))
	# The figure is from the top of the beret to the soles.
	soles = (layers["legs"] if "legs" in layers else base).getchannel("A").getbbox()[3]
	scale = FIGURE_HEIGHT / (soles - base.getchannel("A").getbbox()[1])
	pieces: dict[str, Image.Image] = {}
	at: dict[str, list[int]] = {}
	for part_name, part in parts.items():
		box = part.getchannel("A").getbbox()
		if box is None:
			raise SystemExit(f"{name}: part {part_name} is empty")
		# Snap the box to whole figure pixels so a part lands where it was cut.
		left = frame[0] + np.floor((box[0] - frame[0]) * scale) / scale
		top = frame[1] + np.floor((box[1] - frame[1]) * scale) / scale
		right = frame[0] + np.ceil((box[2] - frame[0]) * scale) / scale
		bottom = frame[1] + np.ceil((box[3] - frame[1]) * scale) / scale
		crop = part.crop((round(left), round(top), round(right), round(bottom)))
		pieces[part_name] = shrink(crop, scale)
		at[part_name] = [round((left - frame[0]) * scale), round((top - frame[1]) * scale)]
	atlas, places = pack(pieces)
	atlas.save(OUTPUT / f"{name}_parts.png")
	layout = {
		"source_origin": [frame[0], frame[1]],
		"scale": scale,
		"figure_height": FIGURE_HEIGHT,
		"feet": [round((facing["center_x"] - frame[0]) * scale, 2), round((soles - frame[1]) * scale, 2)],
		"parts": {part_name: {"atlas": places[part_name], "at": at[part_name]} for part_name in parts},
	}
	(OUTPUT / f"{name}_parts.json").write_text(json.dumps(layout, indent="\t") + "\n", encoding="utf-8", newline="\n")
	write_check(name, base, parts, frame)
	print(f"{name}: {len(parts)} parts, atlas {atlas.width}x{atlas.height}, scale {scale:.4f}")


# The parts drawn back in the rig's order (the visible ones) beside the base
# and the difference.
def write_check(name: str, base: Image.Image, parts: dict[str, Image.Image], frame: tuple[int, int, int, int]) -> None:
	rig = json.loads((OUTPUT / f"{name}_rig.json").read_text(encoding="utf-8")) if (OUTPUT / f"{name}_rig.json").exists() else None
	order = [part["name"] for part in rig["parts"] if part.get("visible", True) and part["name"] in parts] if rig else list(parts)
	rebuilt = Image.new("RGBA", base.size, (0, 0, 0, 0))
	for part_name in order:
		rebuilt.alpha_composite(parts[part_name])
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
	CHECKS.mkdir(exist_ok=True)
	check.crop((0, frame[1], check.width, frame[3])).save(CHECKS / f"mio_rig_{name}_parts_check.png")


def main() -> None:
	names = sys.argv[1:] or [name for name in FACINGS if (SOURCE / f"{name}_base.png").exists()]
	for name in names:
		build(name)


if __name__ == "__main__":
	main()
