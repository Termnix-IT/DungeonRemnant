"""Cut the small icons for a foe's figures in the bestiary.

art/ui/source/stat_icons.png is a 2x3 board painted on flat magenta: the
heart (HP), the burst of a hit (contact damage) and the winged boot (speed),
in gold on the top row and in colour on the bottom row. The magenta is keyed
out, each icon is cut, centred on a clear square and shrunk to SIZE px as
art/ui/stat_<name>.png, from the row ROW. HubCodex draws them at about
STAT_ICON px beside each figure.

	python tools/build_stat_icons.py [row]
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

from image_boards import cut_board, key_out

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "ui" / "source" / "stat_icons.png"
TARGET = ROOT / "art" / "ui"
NAMES = ["hp", "contact", "speed"]
# 0 gold, 1 coloured.
ROW = 1
# Drawn at about 24 px; room for a larger window.
SIZE = 64
# Clear pixels round the icon, as a share of the square.
MARGIN = 0.04


def main() -> None:
	row = int(sys.argv[1]) if len(sys.argv) > 1 else ROW
	keyed = key_out(Image.open(SOURCE).convert("RGB"), 3)
	icons = cut_board(keyed, 2, 3)
	for name, icon in zip(NAMES, icons[row * 3:row * 3 + 3]):
		icon = icon.crop(icon.getchannel("A").getbbox())
		side = round(max(icon.size) / (1.0 - MARGIN * 2))
		square = Image.new("RGBA", (side, side))
		square.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
		square.resize((SIZE, SIZE), Image.LANCZOS).save(TARGET / f"stat_{name}.png")
		print(f"Saved stat_{name}.png ({SIZE}x{SIZE})")


if __name__ == "__main__":
	main()
