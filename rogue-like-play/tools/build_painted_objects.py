"""Shrink the painted objects (item icons, boss-floor passages, the torch).

Each generated object (1024 px, on transparency) is trimmed to its pixels,
padded to a square with a margin, and shrunk to its size here, written for
Godot to show with mipmapped linear filtering:

- art/items/painted/source/<id>.png -> art/items/painted/<id>.png (ICON px),
  read by ItemIcons for screens and the floor; the weapons' also give the
  pictures the hero holds.
- art/tiles/painted/source/<passage>.png -> art/tiles/painted/<passage>.png
  (PASSAGE px), drawn over a boss floor's cell.
- art/tiles/painted/source/torch_sconce.png and torch_flame.png ->
  art/tiles/painted/torch_*.png (TORCH px tall), drawn on the wall faces.
- art/enemies/rig/source/sentinel_base.png -> art/enemies/rig/
  basic_portrait.png (PORTRAIT px): the sentinel's whole figure for the
  encyclopedia and other portraits, as its rig is drawn in parts with no one
  body picture (EnemySprites.portrait).
- art/tiles/painted/source/obstacle_<kind>.png -> art/tiles/painted/
  obstacle_<kind>.png (OBSTACLE px), the rubble, crates and pools that
  stand on floor cells (GridState.OBSTACLES).

	python tools/build_painted_objects.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ITEMS = ROOT / "art" / "items" / "painted"
TILES = ROOT / "art" / "tiles" / "painted"
# Four times the 48 px a card shows an icon at, twice its largest showcase.
ICON = 192
# How much of the icon's square the object fills.
ICON_FILL = 0.88
PASSAGE = 192
PASSAGE_FILL = 1.0
PASSAGES = ["guardian_door", "descent_stairs", "return_door"]
TORCH = 128
OBSTACLE = 192
PORTRAIT = 256
PORTRAITS = {"basic": "sentinel_base"}
ENEMY_RIGS = ROOT / "art" / "enemies" / "rig"
OBSTACLES = ["rubble", "crate", "water"]


def trimmed(path: Path) -> Image.Image:
	image = Image.open(path).convert("RGBA")
	box = image.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
	return image.crop(box)


# The object centred in a size px square, its larger side fill of it.
def square(image: Image.Image, size: int, fill: float) -> Image.Image:
	scale = size * fill / max(image.width, image.height)
	image = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.LANCZOS)
	canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	canvas.alpha_composite(image, ((size - image.width) // 2, (size - image.height) // 2))
	return canvas


# Shrunk to a height, its width following.
def tall(image: Image.Image, height: int) -> Image.Image:
	scale = height / image.height
	return image.resize((max(1, round(image.width * scale)), height), Image.Resampling.LANCZOS)


def main() -> None:
	for source in sorted((ITEMS / "source").glob("*.png")):
		square(trimmed(source), ICON, ICON_FILL).save(ITEMS / source.name)
		print(f"icon {source.stem}")
	for name in PASSAGES:
		source = TILES / "source" / f"{name}.png"
		if source.exists():
			square(trimmed(source), PASSAGE, PASSAGE_FILL).save(TILES / f"{name}.png")
			print(f"passage {name}")
	for name, source_name in PORTRAITS.items():
		source = ENEMY_RIGS / "source" / f"{source_name}.png"
		if source.exists():
			square(trimmed(source), PORTRAIT, 1.0).save(ENEMY_RIGS / f"{name}_portrait.png")
			print(f"portrait {name}")
	for kind in OBSTACLES:
		source = TILES / "source" / f"obstacle_{kind}.png"
		if source.exists():
			square(trimmed(source), OBSTACLE, 1.0).save(TILES / f"obstacle_{kind}.png")
			print(f"obstacle {kind}")
	for part in ["sconce", "flame"]:
		source = TILES / "source" / f"torch_{part}.png"
		if source.exists():
			tall(trimmed(source), TORCH).save(TILES / f"torch_{part}.png")
			print(f"torch {part}")


if __name__ == "__main__":
	main()
