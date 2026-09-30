"""Turn generated enemy boards into the game's right-facing sprite strip.

Reads art/enemies/source/<id>_idle.png (4 frames in one row) and, when present,
art/enemies/source/<id>_action.png (wind-up, strike, hurt, down), then writes
art/enemies/<id>.png: one row of square frames in that order. Backgrounds may be
a flat colour, a fake checkerboard or real transparency.

	python tools/process_enemy_sheet.py basic
	python tools/process_enemy_sheet.py boss_ruin_king
	python tools/process_enemy_sheet.py --all
"""

from __future__ import annotations

import argparse
from collections import Counter, deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "enemies" / "source"
OUTPUT = ROOT / "art" / "enemies"
FRAMES_PER_BOARD = 4
BOTTOM_MARGIN = 2
SIDE_MARGIN = 2
PALETTE_COLORS = 32
OUTLINE_COLOR = (22, 25, 38, 255)
BACKGROUND_TOLERANCE = 48
MIN_SPECK_SHARE = 0.004


# (frame size, idle body height) in pixels. Bodies are sized by height so a
# wide creature (a sword, a cape) is not shrunk to fit a tight frame; the frame
# leaves room for lunges. The hero's body is 56px tall on the same scale, so a
# humanoid matches her and small creatures stay visibly smaller.
FRAME_SIZES = {
	"basic": (96, 58),
	"proximity": (96, 40),
	"fast": (96, 42),
	"charge": (96, 50),
	"summoner": (96, 48),
	"turret": (96, 56),
	"boss": (176, 112),
	"torch": (48, 36),
}
DEFAULT_FRAME = (96, 52)


def frame_spec(sprite_id: str) -> tuple[int, int]:
	if sprite_id.startswith("boss"):
		return FRAME_SIZES["boss"]
	return FRAME_SIZES.get(sprite_id, DEFAULT_FRAME)


def frame_size_for(sprite_id: str) -> int:
	return frame_spec(sprite_id)[0]


def border_colours(rgb: np.ndarray) -> list[np.ndarray]:
	border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
	counts = Counter(tuple(int(v) // 8 for v in pixel) for pixel in border)
	colours: list[np.ndarray] = []
	for key, count in counts.most_common(4):
		if count < len(border) * 0.08:
			break
		members = [pixel for pixel in border if tuple(int(v) // 8 for v in pixel) == key]
		colours.append(np.mean(members, axis=0))
	return colours


def background_mask(image: Image.Image) -> np.ndarray:
	"""True where the pixel is background."""
	rgba = np.asarray(image.convert("RGBA")).astype(np.int32)
	alpha = rgba[:, :, 3]
	edge_alpha = np.concatenate([alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1]])
	if np.mean(edge_alpha < 128) > 0.5:
		return alpha < 128
	rgb = rgba[:, :, :3]
	near = np.zeros(alpha.shape, dtype=bool)
	saturated = False
	for colour in border_colours(rgb):
		near |= np.abs(rgb - colour).sum(axis=2) < BACKGROUND_TOLERANCE
		saturated = saturated or (colour.max() - colour.min()) > 120
	if saturated:
		# A chroma key colour never appears in the art, so enclosed gaps
		# (between legs, inside a ring) are background too.
		return near
	height, width = near.shape
	mask = np.zeros_like(near)
	queue: deque[tuple[int, int]] = deque()
	for x in range(width):
		queue.extend(((0, x), (height - 1, x)))
	for y in range(height):
		queue.extend(((y, 0), (y, width - 1)))
	while queue:
		y, x = queue.popleft()
		if mask[y, x] or not near[y, x]:
			continue
		mask[y, x] = True
		if y > 0:
			queue.append((y - 1, x))
		if y + 1 < height:
			queue.append((y + 1, x))
		if x > 0:
			queue.append((y, x - 1))
		if x + 1 < width:
			queue.append((y, x + 1))
	return mask


def split_frames(image: Image.Image) -> list[Image.Image]:
	background = background_mask(image)
	foreground = ~background
	# Eat the anti-aliased key-colour fringe before any resampling.
	eroded = Image.fromarray((foreground * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))
	foreground = np.asarray(eroded) > 0
	rgba = np.asarray(image.convert("RGBA")).copy()
	rgba[:, :, 3] = np.where(foreground, 255, 0)
	columns = foreground.any(axis=0)
	runs: list[list[int]] = []
	start = None
	for x, filled in enumerate(columns):
		if filled and start is None:
			start = x
		elif not filled and start is not None:
			runs.append([start, x])
			start = None
	if start is not None:
		runs.append([start, len(columns)])
	# Merge fragments (sparks, detached tails) into their nearest neighbour.
	while len(runs) > FRAMES_PER_BOARD:
		gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
		index = gaps.index(min(gaps))
		runs[index] = [runs[index][0], runs[index + 1][1]]
		del runs[index + 1]
	if len(runs) < FRAMES_PER_BOARD:
		step = image.width / FRAMES_PER_BOARD
		runs = [[round(i * step), round((i + 1) * step)] for i in range(FRAMES_PER_BOARD)]
	frames: list[Image.Image] = []
	for left, right in runs:
		cell = Image.fromarray(rgba[:, left:right])
		frames.append(drop_specks(cell))
	return frames


def drop_specks(cell: Image.Image) -> Image.Image:
	alpha = np.asarray(cell.getchannel("A")) > 0
	height, width = alpha.shape
	labels = np.zeros(alpha.shape, dtype=np.int32)
	sizes: list[int] = [0]
	for y in range(height):
		for x in range(width):
			if not alpha[y, x] or labels[y, x]:
				continue
			label = len(sizes)
			count = 0
			queue: deque[tuple[int, int]] = deque([(y, x)])
			labels[y, x] = label
			while queue:
				cy, cx = queue.popleft()
				count += 1
				for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
					if 0 <= ny < height and 0 <= nx < width and alpha[ny, nx] and not labels[ny, nx]:
						labels[ny, nx] = label
						queue.append((ny, nx))
			sizes.append(count)
	total = sum(sizes)
	if total == 0:
		raise ValueError("A frame is empty after removing the background.")
	keep = np.array([size >= total * MIN_SPECK_SHARE for size in sizes])
	keep[0] = False
	rgba = np.asarray(cell).copy()
	rgba[:, :, 3] = np.where(keep[labels], 255, 0)
	result = Image.fromarray(rgba)
	return result.crop(result.getchannel("A").getbbox())


def downscale(sprite: Image.Image, scale: float) -> Image.Image:
	target = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
	rgba = np.asarray(sprite).astype(np.float64)
	alpha = rgba[:, :, 3:4] / 255.0
	# Premultiply so no background colour bleeds into the edge pixels.
	premultiplied = Image.fromarray((rgba[:, :, :3] * alpha).astype(np.uint8))
	coverage = sprite.getchannel("A")
	colour = np.asarray(premultiplied.resize(target, Image.Resampling.BOX)).astype(np.float64)
	weight = np.asarray(coverage.resize(target, Image.Resampling.BOX)).astype(np.float64) / 255.0
	solid = weight >= 0.5
	colour = np.where(weight[:, :, None] > 0, colour / np.maximum(weight[:, :, None], 1e-6), 0)
	out = np.zeros((target[1], target[0], 4), dtype=np.uint8)
	out[:, :, :3] = np.clip(colour, 0, 255).astype(np.uint8)
	out[:, :, 3] = np.where(solid, 255, 0)
	return Image.fromarray(out)


def add_outline(sprite: Image.Image) -> Image.Image:
	padded = Image.new("RGBA", (sprite.width + 2, sprite.height + 2))
	padded.alpha_composite(sprite, (1, 1))
	alpha = padded.getchannel("A")
	ring = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(3)), alpha)
	result = Image.new("RGBA", padded.size)
	result.paste(Image.new("RGBA", padded.size, OUTLINE_COLOR), mask=ring)
	result.alpha_composite(padded)
	return result


def quantize(strip: Image.Image) -> Image.Image:
	alpha = strip.getchannel("A")
	flat = Image.new("RGB", strip.size, (0, 0, 0))
	flat.paste(strip.convert("RGB"), mask=alpha)
	# Octree keeps small saturated accents (glowing eyes, gems) that median cut
	# folds into the dominant body colours.
	reduced = flat.quantize(colors=PALETTE_COLORS, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGBA")
	reduced.putalpha(alpha)
	return reduced


def build_strip(sprite_id: str, source: Path = SOURCE) -> Image.Image:
	idle_path = source / f"{sprite_id}_idle.png"
	if not idle_path.exists():
		raise FileNotFoundError(idle_path)
	idle = split_frames(Image.open(idle_path))
	action_path = source / f"{sprite_id}_action.png"
	action = split_frames(Image.open(action_path)) if action_path.exists() else []
	frames = idle + action
	size, body_height = frame_spec(sprite_id)
	room_x = size - 2 - SIDE_MARGIN * 2
	room_y = size - 2 - BOTTOM_MARGIN
	# The idle frames fix one scale so the creature never changes size between
	# idle and action. Idle frames must fit at that scale; an action pose that
	# still overflows (a long lunge, a sprawled body) alone is shrunk to fit.
	scale = min(body_height / max(frame.height for frame in idle), room_x / max(frame.width for frame in idle), room_y / max(frame.height for frame in idle))
	strip = Image.new("RGBA", (size * len(frames), size))
	for index, frame in enumerate(frames):
		frame_scale = min(scale, room_x / frame.width, room_y / frame.height)
		if frame_scale < scale * 0.999:
			print(f"  frame {index}: pose shrunk to {frame_scale / scale:.0%} to fit the {size}px frame")
		small = downscale(frame, frame_scale)
		box = small.getchannel("A").getbbox()
		if box is None:
			raise ValueError(f"Frame {index} vanished while downscaling.")
		small = small.crop(box)
		x = index * size + (size - small.width) // 2
		y = size - BOTTOM_MARGIN - small.height
		strip.alpha_composite(small, (x, y))
	strip = quantize(strip)
	outlined = Image.new("RGBA", strip.size)
	for index in range(len(frames)):
		cell = strip.crop((index * size, 0, (index + 1) * size, size))
		box = cell.getchannel("A").getbbox()
		body = add_outline(cell.crop(box))
		outlined.alpha_composite(body, (index * size + box[0] - 1, box[1] - 1))
	return outlined


def validate(strip: Image.Image, sprite_id: str) -> None:
	size = frame_size_for(sprite_id)
	if strip.height != size or strip.width % size:
		raise ValueError(f"Unexpected strip size {strip.size}")
	if any(strip.getchannel("A").histogram()[1:255]):
		raise ValueError("Alpha must be fully transparent or fully opaque.")
	for index in range(strip.width // size):
		if strip.crop((index * size, 0, (index + 1) * size, size)).getchannel("A").getbbox() is None:
			raise ValueError(f"Frame {index} is empty.")


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("ids", nargs="*")
	parser.add_argument("--all", action="store_true", help="process every <id>_idle.png in the source folder")
	parser.add_argument("--source", type=Path, default=SOURCE)
	parser.add_argument("--output", type=Path, default=OUTPUT)
	args = parser.parse_args()
	ids = sorted(path.stem.removesuffix("_idle") for path in args.source.glob("*_idle.png")) if args.all else args.ids
	if not ids:
		parser.error("name at least one id or pass --all")
	for sprite_id in ids:
		strip = build_strip(sprite_id, args.source)
		validate(strip, sprite_id)
		args.output.mkdir(parents=True, exist_ok=True)
		strip.save(args.output / f"{sprite_id}.png")
		print(f"Saved {sprite_id}.png ({strip.width // strip.height} frames of {strip.height}px)")


if __name__ == "__main__":
	main()
