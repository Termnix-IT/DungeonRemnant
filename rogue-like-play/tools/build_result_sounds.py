"""Build the sounds of a run's end.

These are the game's own sounds, made here from nothing but sums of tones
and filtered noise, with the same parts as the route's gates
(tools/build_gate_sounds.py; no recording is used, so they carry no licence
of anyone else's):

	boss_slain     the boss's name struck through: a deep stroke, a blade's
	               ring across it, and a bright bell left hanging
	result_dawn    the run won: the great door's light pouring in, a warm
	               chord opening upward under three rising bells
	result_fall    the run lost: one low hollow bell in a cold room, the
	               last of the air leaving after it
	result_return  the run left: a door drawn to far off, and a soft low note
	result_tally   the result's lines settling: a small dull tap of stone

Each is written to audio/made/<cue>.ogg (Ogg Vorbis, mono, 44.1 kHz), its
peak just under full scale; GameAudio plays them by these names.

Needs numpy, and ffmpeg on PATH. Run from the Godot project root:

	python tools/build_result_sounds.py
"""

from __future__ import annotations

import numpy as np

from build_gate_sounds import RATE, ROOT, band, echo, lowpass, noise, place, span, swell, write
from build_start_sounds import bell


def boss_slain() -> np.ndarray:
	length = 2.2
	t = span(length)
	base = np.zeros_like(t)
	# The stroke: deep, falling, with the stone it lands on.
	strike_t = span(0.7)
	phase = 2.0 * np.pi * np.cumsum(118.0 * np.exp(-strike_t * 9.0) + 38.0) / RATE
	strike = np.sin(phase) * swell(strike_t, 0.003, 5.5) + band(noise(0.7, 401), 200.0, 2600.0) * swell(strike_t, 0.002, 26.0) * 0.6
	place(base, strike * 0.95, 0.0)
	# The blade's ring across it: bright noise sweeping down, quickly gone.
	ring_t = span(0.5)
	sweep = band(noise(0.5, 403), 2400.0 - 1400.0 * ring_t / 0.5, 7800.0 - 3000.0 * ring_t / 0.5) * swell(ring_t, 0.01, 11.0)
	place(base, sweep * 0.5, 0.02)
	# A bright bell left hanging: the note, its fifth and its octave.
	place(base, bell(2.0, [(293.7, 0.8, 1.6), (440.0, 1.0, 1.9), (587.3, 0.7, 2.3), (880.0, 0.4, 3.2), (1174.7, 0.2, 4.6), (1620.0, 0.08, 7.0)], 0.008) * 0.4, 0.12)
	return echo(base, 1.5, 0.44, 405, 3200.0)


def result_dawn() -> np.ndarray:
	length = 3.0
	t = span(length)
	along = t / length
	# The door's light: the air of a great room opening and brightening.
	air = band(noise(length, 411), 180.0, 600.0 + 3600.0 * np.minimum(along * 2.2, 1.0)) * swell(t, 0.9, 0.8) * 0.3
	# A warm chord opening upward, each voice a little after the last.
	chord = np.zeros_like(t)
	for index, pitch in enumerate([146.8, 220.0, 293.7, 370.0, 440.0]):
		voice_t = span(length - index * 0.14)
		voice = (np.sin(2.0 * np.pi * pitch * voice_t) + 0.3 * np.sin(2.0 * np.pi * pitch * 2.0 * voice_t + 0.4)) * swell(voice_t, 0.5, 0.9)
		place(chord, voice * (0.3 - index * 0.03), index * 0.14)
	base = air + chord
	# Three rising bells: the note, its third, its fifth above.
	for at, pitch, level in [(0.5, 587.3, 0.3), (0.84, 740.0, 0.27), (1.2, 880.0, 0.32)]:
		place(base, bell(1.8, [(pitch, 1.0, 2.2), (pitch * 2.0, 0.34, 3.4), (pitch * 2.76, 0.14, 5.5), (pitch * 4.07, 0.06, 8.0)], 0.01) * level, at)
	return echo(base, 1.3, 0.42, 413, 3400.0)


def result_fall() -> np.ndarray:
	length = 2.8
	t = span(length)
	# One low hollow bell: its hum, its strike note, the minor third it carries.
	toll = bell(length, [(73.4, 0.7, 1.0), (146.8, 1.0, 1.3), (174.6, 0.5, 1.8), (220.0, 0.3, 2.4), (293.7, 0.2, 3.2), (440.0, 0.07, 5.0)], 0.01)
	knock = band(noise(length, 421), 300.0, 1300.0) * swell(t, 0.003, 50.0) * 0.35
	# The last of the air leaving after it: low, falling.
	along = t / length
	air = lowpass(noise(length, 423), 520.0 - 360.0 * along) * swell(t, 0.7, 1.1) * 0.5
	return echo(toll * 0.62 + knock + air, 1.5, 0.5, 425, 1900.0)


def result_return() -> np.ndarray:
	length = 1.8
	t = span(length)
	base = np.zeros_like(t)
	# A door drawn to, far off.
	door_t = span(0.6)
	phase = 2.0 * np.pi * np.cumsum(84.0 * np.exp(-door_t * 12.0) + 44.0) / RATE
	door = np.sin(phase) * swell(door_t, 0.004, 8.0) + band(noise(0.6, 431), 250.0, 1500.0) * swell(door_t, 0.003, 30.0) * 0.4
	place(base, door * 0.6, 0.05)
	# A soft low note under the corridor's air.
	note = (np.sin(2.0 * np.pi * 110.0 * t) + 0.4 * np.sin(2.0 * np.pi * 164.8 * t)) * swell(t, 0.5, 1.6) * 0.28
	air = band(noise(length, 433), 200.0, 1200.0) * swell(t, 0.4, 1.8) * 0.22
	return echo(base + note + air, 1.4, 0.46, 435, 2200.0)


def result_tally() -> np.ndarray:
	t = span(0.16)
	phase = 2.0 * np.pi * np.cumsum(190.0 * np.exp(-t * 30.0) + 90.0) / RATE
	tap = np.sin(phase) * swell(t, 0.002, 34.0) * 0.7 + band(noise(0.16, 441), 700.0, 3200.0) * swell(t, 0.001, 70.0) * 0.5
	return echo(tap, 0.25, 0.2, 443, 3000.0)


SOUNDS = {
	"boss_slain": boss_slain,
	"result_dawn": result_dawn,
	"result_fall": result_fall,
	"result_return": result_return,
	"result_tally": result_tally,
}


def main() -> None:
	for name, make in SOUNDS.items():
		signal = make()
		target = write(name, signal)
		print(f"{target.relative_to(ROOT)}: {signal.size / RATE:.2f}s")


if __name__ == "__main__":
	main()
