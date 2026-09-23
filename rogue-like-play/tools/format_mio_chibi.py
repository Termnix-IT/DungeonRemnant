"""Pack the generated 4x4 chibi board into native 64px dungeon atlases."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from process_animation_sheet import find_components

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'art/characters/mio_dungeon_chibi_64'


def main():
	source = Image.open(OUTPUT / 'source_front_v2.png').convert('RGBA')
	source.putalpha(source.getchannel('A').point(lambda a:255 if a >=160 else 0))
	# Generated boards do not guarantee equally spaced cells. Locate figures
	# before registering them; otherwise a cell boundary can cut off hair/feet.
	components = sorted(find_components(source), key=lambda c:len(c.pixels), reverse=True)[:16]
	assert len(components) == 16
	assert min(len(c.pixels) for c in components) > 1000
	components.sort(key=lambda c:c.center[1])
	ordered = []
	for row in range(4):
		ordered.extend(sorted(components[row*4:row*4+4],key=lambda c:c.center[0]))
	frames = []
	for component in ordered:
		cell = source.crop(component.bbox)
		cell = cell.resize((min(60, round(cell.width*56/cell.height)),56),Image.Resampling.BOX)
		cell.putalpha(cell.getchannel('A').point(lambda a:255 if a >=128 else 0))
		# Register the face, not the asymmetrical outer hair silhouette.
		face = np.asarray(cell)[10:28].astype(np.int16)
		mask = (face[:,:,0]>150)&(face[:,:,0]>face[:,:,2]+15)&(face[:,:,0]>face[:,:,1]+15)&(face[:,:,3]==255)
		_, xs = np.where(mask)
		center = round(float(np.median(xs))) if len(xs) else cell.width//2
		frame = Image.new('RGBA',(64,64))
		left = max(2,min(62-cell.width,32-center))
		frame.alpha_composite(cell,(left,4))
		assert frame.getbbox()[3] == 60
		assert min(frame.getbbox()[0],64-frame.getbbox()[2]) >= 2
		frames.append(frame)
	# Use the approved side/diagonal colors instead of the hub palette.
	p = np.asarray(Image.open(OUTPUT/'diagonal.png').convert('RGBA'))
	colors = p[:,:,:3][p[:,:,3]==255].tolist()
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
