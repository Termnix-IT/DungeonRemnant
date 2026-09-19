"""Pack the generated 4x4 chibi board into native 64px dungeon atlases."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'art/characters/mio_dungeon_chibi_64'


def main():
	source = Image.open(OUTPUT / 'source.png').convert('RGBA')
	frames = []
	for index in range(16):
		x, y = index % 4, index // 4
		cell = source.crop((round(x*source.width/4), round(y*source.height/4),
			round((x+1)*source.width/4), round((y+1)*source.height/4)))
		cell.putalpha(cell.getchannel('A').point(lambda a: 255 if a >= 160 else 0))
		box = cell.getbbox()
		assert box, f'Empty source cell {index}'
		cell = cell.crop(box)
		cell = cell.resize((round(cell.width*56/cell.height),56),Image.Resampling.BOX)
		cell.putalpha(cell.getchannel('A').point(lambda a:255 if a >=128 else 0))
		# Register the face, not the asymmetrical outer hair silhouette.
		face = np.asarray(cell)[10:28].astype(np.int16)
		mask = (face[:,:,0]>150)&(face[:,:,0]>face[:,:,2]+15)&(face[:,:,0]>face[:,:,1]+15)&(face[:,:,3]==255)
		_, xs = np.where(mask)
		center = round(float(np.median(xs))) if len(xs) else cell.width//2
		frame = Image.new('RGBA',(64,64))
		frame.alpha_composite(cell,(32-center,4))
		assert frame.getbbox()[3] == 60
		assert min(frame.getbbox()[0],64-frame.getbbox()[2]) >= 2
		frames.append(frame)
	colors = []
	for frame in frames:
		p = np.asarray(frame)
		colors.extend(p[:,:,:3][p[:,:,3]==255].tolist())
	palette_source = Image.new('RGB',(len(colors),1))
	palette_source.putdata([tuple(c) for c in colors])
	palette = palette_source.quantize(colors=48,method=Image.Quantize.MEDIANCUT)
	for i,frame in enumerate(frames):
		color = frame.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA')
		color.putalpha(frame.getchannel('A'))
		frames[i] = color
	for action,group in [('idle',frames[:8]),('walk',frames[8:])]:
		atlas=Image.new('RGBA',(256,128))
		for i,frame in enumerate(group):
			atlas.alpha_composite(frame,(i%4*64,i//4*64))
			frame.save(OUTPUT/f'{action}_{i:02}.png')
		atlas.save(OUTPUT/f'{action}_front.png')
	preview=Image.new('RGBA',(512,128))
	preview.alpha_composite(frames[0],(0,0))
	for i,frame in enumerate(frames[8:]):
		preview.alpha_composite(frame,(i*64,64))
	preview.resize((1024,256),Image.Resampling.NEAREST).save(OUTPUT/'inspection.png')
	print(json.dumps({'source':source.size,'frames':16,'cell':[64,64],'foot_row':59}))


if __name__ == '__main__':
	main()
