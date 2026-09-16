"""Build a clean, padded 6x4 pixel-animation atlas from a generated source board."""

from __future__ import annotations

import argparse
from collections import deque
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


COLUMNS = 6
ROWS = 4
FRAME_SIZE = 80
OUTER_MARGIN = 2
OUTLINE_WIDTH = 1
OUTLINE_COLOR = (22, 25, 38, 255)
EXPECTED_SPRITES = COLUMNS * ROWS


@dataclass
class Component:
	pixels: list[int]
	bbox: tuple[int, int, int, int]
	center: tuple[float, float]


def is_background(pixel: tuple[int, int, int]) -> bool:
	"""Match neutral checkerboard shades without treating lavender hair as background."""
	low = min(pixel)
	high = max(pixel)
	return low >= 110 and high - low <= 14


def remove_connected_background(image: Image.Image) -> Image.Image:
	rgb = image.convert("RGB")
	width, height = rgb.size
	transparent = bytearray(width * height)
	queue: deque[tuple[int, int]] = deque()
	for x in range(width):
		queue.append((x, 0))
		queue.append((x, height - 1))
	for y in range(height):
		queue.append((0, y))
		queue.append((width - 1, y))

	while queue:
		x, y = queue.popleft()
		index = y * width + x
		if transparent[index] or not is_background(rgb.getpixel((x, y))):
			continue
		transparent[index] = 1
		if x > 0:
			queue.append((x - 1, y))
		if x + 1 < width:
			queue.append((x + 1, y))
		if y > 0:
			queue.append((x, y - 1))
		if y + 1 < height:
			queue.append((x, y + 1))

	rgba = rgb.convert("RGBA")
	alpha = Image.new("L", (width, height), 255)
	alpha.putdata([0 if value else 255 for value in transparent])
	rgba.putalpha(alpha)
	return rgba


def find_components(image: Image.Image) -> list[Component]:
	alpha = image.getchannel("A")
	width, height = image.size
	visited = bytearray(width * height)
	components: list[Component] = []
	for start_y in range(height):
		for start_x in range(width):
			start = start_y * width + start_x
			if visited[start] or alpha.getpixel((start_x, start_y)) == 0:
				continue
			queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
			visited[start] = 1
			pixels: list[int] = []
			min_x = max_x = start_x
			min_y = max_y = start_y
			total_x = total_y = 0
			while queue:
				x, y = queue.popleft()
				pixels.append(y * width + x)
				min_x = min(min_x, x)
				max_x = max(max_x, x)
				min_y = min(min_y, y)
				max_y = max(max_y, y)
				total_x += x
				total_y += y
				for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
					if nx < 0 or nx >= width or ny < 0 or ny >= height:
						continue
					index = ny * width + nx
					if visited[index] or alpha.getpixel((nx, ny)) == 0:
						continue
					visited[index] = 1
					queue.append((nx, ny))
			components.append(Component(
				pixels,
				(min_x, min_y, max_x + 1, max_y + 1),
				(total_x / len(pixels), total_y / len(pixels)),
			))
	return components


def select_sprite_components(image: Image.Image) -> list[Component]:
	components = sorted(find_components(image), key=lambda value: len(value.pixels), reverse=True)
	if len(components) < EXPECTED_SPRITES:
		raise ValueError(f"Found only {len(components)} connected components; expected {EXPECTED_SPRITES} sprites.")
	selected = components[:EXPECTED_SPRITES]
	selected.sort(key=lambda value: value.center[1])
	ordered: list[Component] = []
	for row in range(ROWS):
		row_components = selected[row * COLUMNS:(row + 1) * COLUMNS]
		row_components.sort(key=lambda value: value.center[0])
		ordered.extend(row_components)
	return ordered


def isolate_component(source: Image.Image, component: Component) -> Image.Image:
	width, height = source.size
	mask = Image.new("L", source.size, 0)
	mask_data = bytearray(width * height)
	for index in component.pixels:
		mask_data[index] = 255
	mask.putdata(mask_data)
	isolated = source.copy()
	isolated.putalpha(mask)
	return isolated.crop(component.bbox)


def resize_sprite(sprite: Image.Image, scale: float) -> Image.Image:
	target = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
	color = sprite.convert("RGB").resize(target, Image.Resampling.BOX)
	color = color.quantize(colors=48, dither=Image.Dither.NONE).convert("RGBA")
	alpha = sprite.getchannel("A").resize(target, Image.Resampling.LANCZOS)
	alpha = alpha.point(lambda value: 255 if value >= 144 else 0)
	alpha = alpha.filter(ImageFilter.MedianFilter(3))
	color.putalpha(alpha)
	return color


def add_outline(sprite: Image.Image) -> Image.Image:
	alpha = sprite.getchannel("A")
	dilated = alpha.filter(ImageFilter.MaxFilter(OUTLINE_WIDTH * 2 + 1))
	outline_mask = ImageChops.subtract(dilated, alpha)
	result = Image.new("RGBA", sprite.size)
	outline = Image.new("RGBA", sprite.size, OUTLINE_COLOR)
	result.alpha_composite(Image.composite(outline, Image.new("RGBA", sprite.size), outline_mask))
	result.alpha_composite(sprite)
	return result


def build_atlas(source: Image.Image) -> Image.Image:
	cleaned = remove_connected_background(source)
	components = select_sprite_components(cleaned)
	sprites = [isolate_component(cleaned, component) for component in components]
	available = FRAME_SIZE - 2 * (OUTER_MARGIN + OUTLINE_WIDTH)
	row_scales: list[float] = []
	for row in range(ROWS):
		row_sprites = sprites[row * COLUMNS:(row + 1) * COLUMNS]
		max_width = max(sprite.width for sprite in row_sprites)
		max_height = max(sprite.height for sprite in row_sprites)
		row_scales.append(min(available / max_width, available / max_height))
	atlas = Image.new("RGBA", (COLUMNS * FRAME_SIZE, ROWS * FRAME_SIZE))
	for index, sprite in enumerate(sprites):
		row = index // COLUMNS
		resized = add_outline(resize_sprite(sprite, row_scales[row]))
		bbox = resized.getchannel("A").getbbox()
		if bbox is None:
			raise ValueError(f"Sprite {index} became empty during processing.")
		resized = resized.crop(bbox)
		column = index % COLUMNS
		x = column * FRAME_SIZE + (FRAME_SIZE - resized.width) // 2
		y = row * FRAME_SIZE + FRAME_SIZE - OUTER_MARGIN - resized.height
		atlas.alpha_composite(resized, (x, y))
	return atlas


def validate_atlas(atlas: Image.Image) -> None:
	if atlas.size != (COLUMNS * FRAME_SIZE, ROWS * FRAME_SIZE):
		raise ValueError(f"Unexpected atlas size: {atlas.size}")
	alpha_histogram = atlas.getchannel("A").histogram()
	if any(alpha_histogram[1:255]):
		raise ValueError("Atlas alpha must be fully transparent or fully opaque.")
	for row in range(ROWS):
		for column in range(COLUMNS):
			cell = atlas.crop((column * FRAME_SIZE, row * FRAME_SIZE, (column + 1) * FRAME_SIZE, (row + 1) * FRAME_SIZE))
			bbox = cell.getchannel("A").getbbox()
			if bbox is None:
				raise ValueError(f"Cell {column},{row} is empty.")
			margins = (bbox[0], bbox[1], FRAME_SIZE - bbox[2], FRAME_SIZE - bbox[3])
			if min(margins) < OUTER_MARGIN:
				raise ValueError(f"Cell {column},{row} has unsafe margins: {margins}")


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("source", type=Path)
	parser.add_argument("output", type=Path)
	args = parser.parse_args()
	source = Image.open(args.source)
	atlas = build_atlas(source)
	validate_atlas(atlas)
	args.output.parent.mkdir(parents=True, exist_ok=True)
	atlas.save(args.output)
	print(f"Saved {args.output} ({atlas.width}x{atlas.height}); 24 sprites, {OUTER_MARGIN}px minimum margin")


if __name__ == "__main__":
	main()
