"""Lay the prototypes' captures side by side.

Reads .godot/codex_<name>_<state>_1920.png (written by capture_proto.gd) and
writes, into .godot/codex_compare/:

	compare_<state>.png   the three prototypes in one state, left to right
	compare_all.png       every state a row, the three prototypes across
	<name>_states.png     one prototype's states in a sheet two across

Run from the Godot project root:

	python prototypes/codex_redesign/compare_sheets.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent.parent
SHOTS = ROOT / ".godot"
OUT = SHOTS / "codex_compare"
NAMES = [("ledger", "A  調査台帳"), ("plates", "B  魔物図譜"), ("altar", "C  追憶の祭壇")]
STATES = [("initial", "初期表示"), ("browse", "敵選択中"), ("category", "カテゴリー切り替え後"), ("unknown", "未発見の敵"), ("detail", "詳細表示")]
CELL = (1280, 720)
BAR = 44
FONT = ROOT / "art" / "third_party" / "biz_udp_gothic" / "BIZUDPGothic-Bold.ttf"


def shot(name: str, state: str, size: tuple[int, int]) -> Image.Image:
	return Image.open(SHOTS / f"codex_{name}_{state}_1920.png").convert("RGB").resize(size, Image.LANCZOS)


def labelled(image: Image.Image, words: str, font: ImageFont.FreeTypeFont) -> Image.Image:
	cell = Image.new("RGB", (image.width, image.height + BAR), (18, 18, 20))
	cell.paste(image, (0, BAR))
	ImageDraw.Draw(cell).text((16, 9), words, font=font, fill=(235, 232, 225))
	return cell


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	font = ImageFont.truetype(str(FONT), 24)
	rows = []
	for state, state_words in STATES:
		cells = [labelled(shot(name, state, CELL), f"{words}　{state_words}", font) for name, words in NAMES]
		row = Image.new("RGB", (CELL[0] * 3 + 16, CELL[1] + BAR), (0, 0, 0))
		for index, cell in enumerate(cells):
			row.paste(cell, (index * (CELL[0] + 8), 0))
		row.save(OUT / f"compare_{state}.png")
		rows.append(row)
	whole = Image.new("RGB", (rows[0].width, sum(row.height + 8 for row in rows)), (0, 0, 0))
	for index, row in enumerate(rows):
		whole.paste(row, (0, index * (row.height + 8)))
	whole.save(OUT / "compare_all.png")
	for name, words in NAMES:
		sheet = Image.new("RGB", (CELL[0] * 2 + 8, (CELL[1] + BAR + 8) * 3), (0, 0, 0))
		for index, (state, state_words) in enumerate(STATES):
			cell = labelled(shot(name, state, CELL), f"{words}　{state_words}", font)
			sheet.paste(cell, ((index % 2) * (CELL[0] + 8), (index // 2) * (CELL[1] + BAR + 8)))
		sheet.save(OUT / f"{name}_states.png")
	print("wrote", OUT.relative_to(ROOT).as_posix())


if __name__ == "__main__":
	main()
