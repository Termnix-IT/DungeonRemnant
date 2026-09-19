"""Register new chibi direction boards against the approved 64px front palette."""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'art/characters/mio_dungeon_chibi_64'


def pack(source_name, rows, output_name, palette):
	source = Image.open(OUTPUT / source_name).convert('RGBA')
	atlas = Image.new('RGBA', (384, rows * 64))
	for row in range(rows):
		for col in range(6):
			cell = source.crop((round(col*source.width/6), round(row*source.height/rows),
				round((col+1)*source.width/6), round((row+1)*source.height/rows)))
			cell.putalpha(cell.getchannel('A').point(lambda a:255 if a>=160 else 0))
			box = cell.getbbox()
			assert box, (row,col)
			cell = cell.crop(box)
			cell = cell.resize((round(cell.width*56/cell.height),56),Image.Resampling.BOX)
			alpha = cell.getchannel('A').point(lambda a:255 if a>=128 else 0)
			color = cell.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA')
			color.putalpha(alpha)
			frame = Image.new('RGBA',(64,64))
			# Hair extends behind profile views; anchor to feet instead of hair bounds.
			_, foot_x = np.where(np.asarray(alpha)[-6:] > 0)
			anchor = (int(foot_x.min()) + int(foot_x.max()) + 1) / 2
			left = max(2, min(62-color.width, round(32-anchor)))
			frame.alpha_composite(color,(left,4))
			bounds = frame.getbbox()
			assert bounds and bounds[3] == 60 and min(bounds[0],64-bounds[2])>=2, (row,col,bounds)
			assert not any(frame.getchannel('A').histogram()[1:255])
			atlas.alpha_composite(frame,(col*64,row*64))
	atlas.save(OUTPUT / output_name)
	return atlas


def main():
	front = Image.open(OUTPUT/'idle_front.png').convert('RGBA')
	p = np.asarray(front)
	colors = p[:,:,:3][p[:,:,3]==255]
	palette_source = Image.new('RGB',(len(colors),1))
	palette_source.putdata([tuple(c) for c in colors])
	palette = palette_source.quantize(colors=48,method=Image.Quantize.MEDIANCUT)
	cardinal = pack('cardinal_source.png',3,'cardinal.png',palette)
	diagonal = pack('diagonal_source.png',4,'diagonal.png',palette)
	contact = Image.new('RGBA',(8*64,64))
	contact.alpha_composite(front.crop((0,0,64,64)),(0,0))
	for i in range(3):
		contact.alpha_composite(cardinal.crop((0,i*64,64,i*64+64)),((i+1)*64,0))
	for i in range(4):
		contact.alpha_composite(diagonal.crop((0,i*64,64,i*64+64)),((i+4)*64,0))
	contact.resize((1024,128),Image.Resampling.NEAREST).save(OUTPUT/'directions_preview.png')
	print('Validated 42 frames: 64x64, binary alpha, 56px height, foot row 59.')


if __name__ == '__main__':
	main()
