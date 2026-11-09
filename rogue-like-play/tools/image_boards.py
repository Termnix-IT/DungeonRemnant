"""Cut generated pictures off their flat backgrounds.

Shared by the tools that build painted art from boards Codex generates on a
flat key colour (magenta) or a fake checkerboard: background_mask() finds the
background, cut_board() splits a rows x columns board into one cut-out per
cell, and key_out() turns a picture painted on flat magenta into a soft-edged
cut-out. Not run on its own.
"""

from __future__ import annotations

from collections import Counter, deque

import numpy as np
from PIL import Image, ImageFilter

# How far (summed RGB) a pixel may be from a border colour and still count
# as background.
BACKGROUND_TOLERANCE = 48
# Parts smaller than this share of a cell's object (sparkles, a loose pixel)
# are dropped; a detached cord or crystal is kept with its object.
MIN_PART_SHARE = 0.01
KEY = np.array([1.0, 0.0, 1.0])
# Distance from the key colour below which a pixel is background, and above
# which it is wholly the picture; between them it fades.
KEY_CLEAR = 0.32
KEY_SOLID = 0.62


def key_out(image: Image.Image, reach: int) -> Image.Image:
	"""The picture with its flat magenta background made see-through.

	reach is how far in from the edge, in source pixels, the magenta that
	bled into the painting's rim is taken back out.
	"""
	rgb = np.asarray(image.convert("RGB"), dtype=np.float32) / 255.0
	# Magenta is strong red and blue with little green: measure how far a
	# pixel is from it, weighting the green that magenta lacks.
	distance = np.sqrt(((rgb - KEY) ** 2 * np.array([1.0, 1.6, 1.0])).sum(axis=2))
	alpha = np.clip((distance - KEY_CLEAR) / (KEY_SOLID - KEY_CLEAR), 0.0, 1.0)
	# Edge pixels are part magenta: take the key's share back out.
	share = (1.0 - alpha)[..., None]
	colour = np.clip((rgb - KEY * share) / np.maximum(alpha[..., None], 1e-3), 0.0, 1.0)
	# What magenta tint survives (red and blue above green) is pulled down.
	spill = np.clip(np.minimum(colour[..., 0], colour[..., 2]) - colour[..., 1], 0.0, None)
	edge = alpha < 0.98
	if reach > 0:
		# Grow the see-through region inwards to reach the tinted rim.
		clear = Image.fromarray(((alpha < 0.98) * 255).astype(np.uint8))
		edge = np.asarray(clear.filter(ImageFilter.MaxFilter(reach * 2 + 1))) > 0
	colour = np.where(edge[..., None], colour - spill[..., None] * np.array([1.0, 0.0, 1.0]), colour)
	result = np.dstack([np.clip(colour, 0.0, 1.0), alpha])
	return Image.fromarray((result * 255.0).round().astype(np.uint8), "RGBA")


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


def components(foreground: np.ndarray) -> list[tuple[np.ndarray, tuple[float, float]]]:
	"""Connected parts as (pixel index array, centre)."""
	height, width = foreground.shape
	labels = np.zeros(foreground.shape, dtype=np.int32)
	parts: list[tuple[np.ndarray, tuple[float, float]]] = []
	for y, x in zip(*np.nonzero(foreground)):
		if labels[y, x]:
			continue
		label = len(parts) + 1
		labels[y, x] = label
		queue: deque[tuple[int, int]] = deque([(y, x)])
		members: list[int] = []
		while queue:
			cy, cx = queue.popleft()
			members.append(cy * width + cx)
			for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
				if 0 <= ny < height and 0 <= nx < width and foreground[ny, nx] and not labels[ny, nx]:
					labels[ny, nx] = label
					queue.append((ny, nx))
		pixels = np.array(members)
		parts.append((pixels, (float((pixels // width).mean()), float((pixels % width).mean()))))
	return parts


def cut_board(board: Image.Image, rows: int, columns: int) -> list[Image.Image]:
	rgba = np.asarray(board.convert("RGBA")).copy()
	foreground = ~background_mask(board)
	height, width = foreground.shape
	cells: list[list[np.ndarray]] = [[] for _ in range(rows * columns)]
	# Objects may lean past the grid lines, so each part joins the cell that
	# holds its centre rather than being clipped at the boundary.
	for pixels, (cy, cx) in components(foreground):
		row = min(rows - 1, int(cy / height * rows))
		column = min(columns - 1, int(cx / width * columns))
		cells[row * columns + column].append(pixels)
	icons: list[Image.Image] = []
	for index, parts in enumerate(cells):
		total = sum(len(pixels) for pixels in parts)
		if total == 0:
			raise ValueError(f"Cell {index} is empty")
		mask = np.zeros(height * width, dtype=bool)
		for pixels in parts:
			if len(pixels) >= total * MIN_PART_SHARE:
				mask[pixels] = True
		mask = mask.reshape(height, width)
		cell = rgba.copy()
		cell[:, :, 3] = np.where(mask, 255, 0)
		image = Image.fromarray(cell)
		icons.append(image.crop(image.getchannel("A").getbbox()))
	return icons
