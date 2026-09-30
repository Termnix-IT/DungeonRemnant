"""Cut generated item boards into the game's item icons.

Each board in art/items/source/ is a grid of objects on a flat background, laid
out in the order listed in BOARDS. Every object becomes art/items/<item id>.png:
a 48px pixel-art icon (fitted to 44px, octree palette, the enemies' 1px dark
outline) stored at 2x with nearest scaling, so a 48px item card shows it at
exactly one source pixel per two texture pixels.

	python tools/process_item_icons.py
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

from process_enemy_sheet import add_outline, background_mask, downscale

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "items" / "source"
OUTPUT = ROOT / "art" / "items"
ICON = 48
FIT = 44
STORED_SCALE = 2
PALETTE_COLORS = 32
# Parts smaller than this share of a cell's object (sparkles, a loose pixel)
# are dropped; a detached cord or crystal is kept with its object.
MIN_PART_SHARE = 0.01
# (board file, rows, columns, ids in reading order). Weapon items use the ids
# ItemData.from_weapon gives them: weapon_<WeaponData.Kind>.
BOARDS = [
	("items_a.png", 2, 4, ["healing_potion", "mana_potion", "bolt_scroll", "flame_scroll", "heal_scroll", "leather_armor", "chain_armor", "power_charm"]),
	("items_b.png", 2, 4, ["vision_charm", "vital_charm", "damage_talisman", "defense_talisman", "vision_talisman", "regen_talisman", "kill_heal_talisman", "gold_talisman"]),
	("items_c.png", 2, 3, ["exp_talisman", "weapon_0", "weapon_1", "weapon_2", "weapon_3", "weapon_4"]),
]


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


def to_icon(source: Image.Image) -> Image.Image:
	small = downscale(source, FIT / max(source.size))
	small = small.crop(small.getchannel("A").getbbox())
	alpha = small.getchannel("A")
	flat = Image.new("RGB", small.size)
	flat.paste(small.convert("RGB"), mask=alpha)
	reduced = flat.quantize(colors=PALETTE_COLORS, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGBA")
	reduced.putalpha(alpha)
	body = add_outline(reduced)
	icon = Image.new("RGBA", (ICON, ICON))
	icon.alpha_composite(body, ((ICON - body.width) // 2, (ICON - body.height) // 2))
	return icon


def main() -> None:
	OUTPUT.mkdir(parents=True, exist_ok=True)
	for name, rows, columns, ids in BOARDS:
		path = SOURCE / name
		if not path.exists():
			print(f"Skipped {name}: not generated yet")
			continue
		icons = cut_board(Image.open(path), rows, columns)
		for item_id, source in zip(ids, icons, strict=True):
			icon = to_icon(source)
			if any(icon.getchannel("A").histogram()[1:255]):
				raise ValueError(f"{item_id}: alpha must be binary")
			icon.resize((ICON * STORED_SCALE, ICON * STORED_SCALE), Image.Resampling.NEAREST).save(OUTPUT / f"{item_id}.png")
		print(f"Saved {len(ids)} icons from {name}")


if __name__ == "__main__":
	main()
