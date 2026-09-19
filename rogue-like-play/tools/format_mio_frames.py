"""Slice and register the approved front-view sheets on a 128px pixel grid."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/characters/mio_animation_draft_v1'
OUTPUT = ROOT / 'art/characters/mio_animation_v2'


def frames_from_sheet(path):
	image = Image.open(path).convert('RGBA')
	frames = []
	for index in range(8):
		x, y = index % 4, index // 4
		cell = image.crop((round(x * image.width / 4), round(y * image.height / 2),
			round((x + 1) * image.width / 4), round((y + 1) * image.height / 2)))
		alpha = cell.getchannel('A').point(lambda a: 255 if a >= 160 else 0)
		cell.putalpha(alpha)
		bounds = alpha.getbbox()
		if bounds is None:
			raise ValueError(f'Empty frame {index}: {path}')
		cell = cell.crop(bounds)
		# All sprites have the same canvas, scale and ground anchor. Pixel detail is
		# reduced with area sampling, then stored with binary alpha and one palette.
		size = (round(cell.width * 112 / cell.height), 112)
		cell = cell.resize(size, Image.Resampling.BOX)
		cell.putalpha(cell.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
		pixels = np.asarray(cell)
		face = pixels[18:37].astype(np.int16)
		mask = (face[:,:,0] > 150) & (face[:,:,0] > face[:,:,2] + 12) & (face[:,:,0] > face[:,:,1] + 12) & (face[:,:,3] == 255)
		_, xs = np.where(mask)
		center = round(float(np.median(xs))) if len(xs) else cell.width // 2
		frame = Image.new('RGBA', (128, 128))
		frame.alpha_composite(cell, (64 - center, 9))
		frames.append(frame)
	return frames


def main():
	OUTPUT.mkdir(exist_ok=True)
	frames = {'idle': frames_from_sheet(SOURCE / 'idle_front.png'),
		'walk': frames_from_sheet(OUTPUT / 'walk_corrected_source.png')}
	colors = []
	for group in frames.values():
		for frame in group:
			p = np.asarray(frame)
			colors.extend(p[:,:,:3][p[:,:,3] == 255].tolist())
	palette_source = Image.new('RGB', (len(colors), 1))
	palette_source.putdata([tuple(c) for c in colors])
	palette = palette_source.quantize(colors=48, method=Image.Quantize.MEDIANCUT)
	report = {'frame_size': [128,128], 'columns':4, 'rows':2,
		'anchor': [64,120], 'palette_colors_max':48, 'animations':{}}
	for action, group in frames.items():
		atlas = Image.new('RGBA', (512,256))
		bounds = []
		for index, frame in enumerate(group):
			alpha = frame.getchannel('A')
			frame = frame.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE).convert('RGBA')
			frame.putalpha(alpha)
			bbox = alpha.getbbox()
			assert bbox and min(bbox[0], bbox[1], 128-bbox[2],128-bbox[3]) >= 4, bbox
			assert not any(alpha.histogram()[1:255])
			assert bbox[3] == 121, bbox
			frame.save(OUTPUT / f'{action}_front_{index:02}.png')
			group[index] = frame
			bounds.append(bbox)
			atlas.alpha_composite(frame, (index%4*128,index//4*128))
		atlas.save(OUTPUT / f'{action}_front.png')
		report['animations'][action] = {'frames':8, 'bounds':bounds}
	# A view-only GIF uses the same PNG frames; PNG remains the game asset.
	preview = []
	for i in range(8):
		canvas = Image.new('RGB',(256,128),(38,42,55))
		for j, action in enumerate(('idle','walk')):
			canvas.paste(frames[action][i],(j*128,0),frames[action][i])
		preview.append(canvas.resize((768,384),Image.Resampling.NEAREST))
	preview[0].save(OUTPUT/'animation_preview.gif',save_all=True,append_images=preview[1:],duration=150,loop=0)
	(OUTPUT/'frames.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
	print(json.dumps(report))


if __name__ == '__main__':
	main()
