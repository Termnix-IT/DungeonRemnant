"""Build the art of the route's hall of gates from its generated pictures.

art/ui/route/source/gate_<chapter>.png is a stone gateway seen from the
front, its opening and everything outside it a flat magenta (#FF00FF);
gate_bars.png is an iron portcullis and hall_pillar.png a stone column,
each on the same magenta. This keys the magenta out, trims each to what is
painted and writes, into art/ui/route/:

	gate_<chapter>.png        the gateway, its opening see-through, GATE_HEIGHT tall
	gate_<chapter>_light.png  the same size: red is the opening (where the
	                          gate's light and its portcullis show), green is
	                          how much of that light falls on the stone round
	                          the opening (strongest on its inner edge), blue
	                          is the light spilt past the stone (its halo)
	gate_bars.png             the portcullis, BARS_WIDTH wide
	hall_pillar.png           the pillar, PILLAR_HEIGHT tall

and, from pictures of the same kind (a thing on magenta, or a painting that
fills its picture):

	route_tablet.png          the slab the chapter's route is cut into, and
	route_plate.png           the same slab PLATE_WIDTH wide, for an area's card
	brazier.png               a trial's and the boss's fire stand, BRAZIER_HEIGHT tall
	finial_<kind>.png         what crowns a gate by its area's kind (arena,
	                          event, boss), cut from the one board
	                          gate_finials.png, FINIAL_HEIGHT tall at most
	floor_flags.png           the hall's paving seen from straight above, laid
	                          beside its mirror both ways so that it repeats
	                          without a seam (FLAGS_SIZE a quarter)
	road_strip.png            a causeway's slabs with the bronze channel down
	                          their middle, over its mirror so that it repeats
	                          along the road (ROAD_WIDTH wide)
	floor_dais.png            the round stone the causeways meet at, DAIS_SIZE across
	inside_<kind>.png         what is seen through a gate by its area's kind
	                          (field, arena, event, boss), INSIDE_HEIGHT tall

RouteGateView reads where the opening lies from the light picture itself, so
a gate repainted with another opening needs no constant changed.

Run from the Godot project root:

	python tools/build_route_gates.py                 # everything
	python tools/build_route_gates.py gate_gale_woods  # the named ones
	python tools/build_route_gates.py --measure        # where each opening lies
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from image_boards import key_out

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "route" / "source"
OUTPUT = ROOT / "art" / "ui" / "route"
GATES = ["gate_ash_corridor", "gate_gale_woods", "gate_amethyst_mausoleum", "gate_abyss_of_echoes"]
OTHERS = ["gate_bars", "hall_pillar"]
KEYED = {"route_tablet": ("width", 1472), "brazier": ("height", 440), "floor_dais": ("width", 640)}
INSIDES = ["inside_field", "inside_arena", "inside_event", "inside_boss"]
FINIALS = ["arena", "event", "boss"]
HALL = list(KEYED) + INSIDES + ["gate_finials", "floor_flags", "road_strip"]
FINIAL_HEIGHT = 320
PLATE_WIDTH = 736
FLAGS_SIZE = 768
ROAD_WIDTH = 384
INSIDE_HEIGHT = 960
GATE_HEIGHT = 1000
BARS_WIDTH = 512
PILLAR_HEIGHT = 1200
# How far the gate's light reaches over its stone and past it, as shares of
# the gate's width.
RIM_REACH = 0.045
HALO_REACH = 0.12
# The opening is found above this share of the gate's height (see opening_of).
FOOT_CUT = 0.94


def keyed(name: str) -> Image.Image:
	image = key_out(Image.open(SOURCE / f"{name}.png"), 2)
	box = image.getchannel("A").point(lambda value: 255 if value > 24 else 0).getbbox()
	return image.crop(box)


def opening_of(gate: Image.Image) -> Image.Image:
	"""The gate's opening as a mask: the see-through region its middle lies in."""
	clear = gate.getchannel("A").point(lambda value: 255 if value < 128 else 0)
	seed = (gate.width // 2, round(gate.height * 0.62))
	if clear.getpixel(seed) == 0:
		raise ValueError("the gate's middle is not see-through: is its opening magenta?")
	# The jambs' feet are uneven, and a see-through sliver under one would join
	# the opening to the outside: the fill stops short of the foot, and the
	# opening runs straight down from there between the same two sides.
	cut = round(gate.height * FOOT_CUT)
	upper = clear.crop((0, 0, gate.width, cut))
	ImageDraw.floodfill(upper, seed, 128)
	hole = np.asarray(upper) == 128
	sides = np.flatnonzero(hole[-1])
	if sides.size == 0 or hole[:, 0].any() or hole[:, -1].any():
		raise ValueError("the gate's opening is not closed in by its stone")
	whole = np.zeros((gate.height, gate.width), dtype=bool)
	whole[:cut] = hole
	whole[cut:, sides[0]:sides[-1] + 1] = np.asarray(clear)[cut:, sides[0]:sides[-1] + 1] > 0
	return Image.fromarray((whole * 255).astype(np.uint8))


def build_gate(name: str) -> list[Path]:
	gate = keyed(name)
	size = (round(gate.width * GATE_HEIGHT / gate.height), GATE_HEIGHT)
	gate = gate.resize(size, Image.Resampling.LANCZOS)
	opening = opening_of(gate)
	stone = np.asarray(gate.getchannel("A"), dtype=np.float32) / 255.0
	hole = np.asarray(opening, dtype=np.float32) / 255.0
	# The opening's light on the stone: its blurred mask where there is stone,
	# lifted so the inner edge is fully lit.
	rim = np.asarray(opening.filter(ImageFilter.GaussianBlur(size[0] * RIM_REACH)), dtype=np.float32) / 255.0
	rim = np.clip(rim * 2.4, 0.0, 1.0) * stone
	halo = np.asarray(opening.filter(ImageFilter.GaussianBlur(size[0] * HALO_REACH)), dtype=np.float32) / 255.0
	halo = np.clip(halo * 1.6, 0.0, 1.0)
	light = np.dstack([hole, rim, halo, np.ones_like(hole)])
	# Whatever of the gate was painted over its own opening is cut away.
	pixels = np.asarray(gate, dtype=np.float32) / 255.0
	pixels[..., 3] *= 1.0 - hole
	gate_path = OUTPUT / f"{name}.png"
	light_path = OUTPUT / f"{name}_light.png"
	Image.fromarray((pixels * 255.0).round().astype(np.uint8), "RGBA").save(gate_path)
	Image.fromarray((light * 255.0).round().astype(np.uint8), "RGBA").save(light_path)
	return [gate_path, light_path]


def build_other(name: str) -> list[Path]:
	image = keyed(name)
	if name == "gate_bars":
		size = (BARS_WIDTH, round(image.height * BARS_WIDTH / image.width))
	else:
		size = (round(image.width * PILLAR_HEIGHT / image.height), PILLAR_HEIGHT)
	target = OUTPUT / f"{name}.png"
	image.resize(size, Image.Resampling.LANCZOS).save(target)
	return [target]


def sized(image: Image.Image, side: str, length: int) -> Image.Image:
	if side == "width":
		size = (length, round(image.height * length / image.width))
	else:
		size = (round(image.width * length / image.height), length)
	return image.resize(size, Image.Resampling.LANCZOS)


def build_hall(name: str) -> list[Path]:
	"""The hall's own pictures: the tablet, the fires, the floor and what lies beyond a gate."""
	if name in KEYED:
		target = OUTPUT / f"{name}.png"
		built = sized(keyed(name), *KEYED[name])
		built.save(target)
		if name == "route_tablet":
			# The same slab at the size it is drawn at, for the card of an
			# area (its ends and edges are kept, its middle stretched).
			plate = OUTPUT / "route_plate.png"
			sized(built, "width", PLATE_WIDTH).save(plate)
			return [target, plate]
		return [target]
	if name == "gate_finials":
		# Three things side by side on one board: each is cut where the board
		# is see-through from top to bottom.
		board = key_out(Image.open(SOURCE / f"{name}.png"), 2)
		painted = np.asarray(board.getchannel("A")) > 24
		columns = painted.any(axis=0)
		runs = []
		start = None
		for x, there in enumerate(columns):
			if there and start is None:
				start = x
			elif not there and start is not None:
				if x - start > 20:
					runs.append((start, x))
				start = None
		if start is not None:
			runs.append((start, len(columns)))
		if len(runs) != len(FINIALS):
			raise ValueError(f"the board holds {len(runs)} things, not {len(FINIALS)}")
		targets = []
		for kind, (left, right) in zip(FINIALS, runs):
			piece = board.crop((left, 0, right, board.height))
			piece = piece.crop(piece.getchannel("A").point(lambda value: 255 if value > 24 else 0).getbbox())
			target = OUTPUT / f"finial_{kind}.png"
			sized(piece, "height", min(FINIAL_HEIGHT, piece.height)).save(target)
			targets.append(target)
		return targets
	source = Image.open(SOURCE / f"{name}.png").convert("RGB")
	target = OUTPUT / f"{name}.png"
	if name == "floor_flags":
		tile = source.resize((FLAGS_SIZE, FLAGS_SIZE), Image.Resampling.LANCZOS)
		whole = Image.new("RGB", (FLAGS_SIZE * 2, FLAGS_SIZE * 2))
		whole.paste(tile, (0, 0))
		whole.paste(tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (FLAGS_SIZE, 0))
		whole.paste(tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0, FLAGS_SIZE))
		whole.paste(tile.transpose(Image.Transpose.ROTATE_180), (FLAGS_SIZE, FLAGS_SIZE))
		whole.save(target)
	elif name == "road_strip":
		tile = sized(source, "width", ROAD_WIDTH)
		whole = Image.new("RGB", (tile.width, tile.height * 2))
		whole.paste(tile, (0, 0))
		whole.paste(tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0, tile.height))
		whole.save(target)
	else:
		sized(source, "height", INSIDE_HEIGHT).save(target)
	return [target]


def measure(name: str) -> str:
	with Image.open(OUTPUT / f"{name}_light.png") as light:
		hole = np.asarray(light.getchannel("R")) > 128
		rows = np.flatnonzero(hole.any(axis=1))
		columns = np.flatnonzero(hole.any(axis=0))
		height, width = hole.shape
		return (f"{name}: {width}x{height}  opening x {columns[0] / width:.3f}-{(columns[-1] + 1) / width:.3f}"
			f"  y {rows[0] / height:.3f}-{(rows[-1] + 1) / height:.3f}  ({columns[-1] + 1 - columns[0]}x{rows[-1] + 1 - rows[0]} px)")


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("names", nargs="*", choices=GATES + OTHERS + HALL)
	parser.add_argument("--measure", action="store_true")
	arguments = parser.parse_args()
	names = arguments.names or GATES + OTHERS + HALL
	for name in names:
		if arguments.measure:
			if name in GATES:
				print(measure(name))
			continue
		for target in build_gate(name) if name in GATES else (build_hall(name) if name in HALL else build_other(name)):
			with Image.open(target) as built:
				print(f"{target.relative_to(ROOT)}: {built.width}x{built.height}")


if __name__ == "__main__":
	main()
