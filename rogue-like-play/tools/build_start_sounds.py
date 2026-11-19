"""Build the sounds of the way from starting the game to setting out.

These are the game's own sounds, made here from nothing but sums of tones
and filtered noise, with the same parts as the route's gates
(tools/build_gate_sounds.py; no recording is used, so they carry no licence
of anyone else's):

	title_swell   the hall comes out of the dark behind the game's name: a
	              low drone rising, the air brightening, three soft bells
	title_start   the opening's key: a soft thud and a bright chord lifting
	hall_gate     the view goes up to the hall's gate: air drawn toward it
	set_out       setting out: the press landing, the air rushing in toward
	              the way in, and the dark closing with a deep stroke
	chapter_toll  the chapter's name in the dark: one low bell

Each is written to audio/made/<cue>.ogg (Ogg Vorbis, mono, 44.1 kHz), its
peak just under full scale; GameAudio plays them by these names.

Needs numpy, and ffmpeg on PATH. Run from the Godot project root:

	python tools/build_start_sounds.py
"""

from __future__ import annotations

import numpy as np

from build_gate_sounds import RATE, ROOT, band, echo, noise, place, span, swell, write


def bell(seconds: float, partials: list[tuple[float, float, float]], attack: float = 0.006) -> np.ndarray:
	"""A struck bell: each partial its own pitch, level and dying away."""
	t = span(seconds)
	out = np.zeros_like(t)
	for pitch, level, decay in partials:
		out += np.sin(2.0 * np.pi * pitch * t) * level * swell(t, attack, decay)
	return out


def title_swell() -> np.ndarray:
	length = 3.2
	t = span(length)
	along = t / length
	# The hall's own low note coming up out of nothing, a fifth over it.
	drone = (np.sin(2.0 * np.pi * 73.4 * t) + 0.5 * np.sin(2.0 * np.pi * 110.0 * t) + 0.25 * np.sin(2.0 * np.pi * 146.8 * t + 0.6)) * swell(t, 1.6, 0.9) * 0.5
	# The air of a large room, brightening as the lamps catch.
	air = band(noise(length, 301), 160.0, 500.0 + 2600.0 * along) * swell(t, 1.9, 1.1) * 0.3
	base = drone + air
	# Three soft bells as the name comes: the note, its fifth, its octave.
	for at, pitch, level in [(1.25, 293.7, 0.34), (1.62, 440.0, 0.26), (2.05, 587.3, 0.3)]:
		place(base, bell(1.5, [(pitch, 1.0, 2.6), (pitch * 2.0, 0.34, 4.0), (pitch * 2.76, 0.16, 6.0), (pitch * 4.07, 0.07, 9.0)], 0.012) * level, at)
	return echo(base, 1.3, 0.42, 303, 3000.0)


def title_start() -> np.ndarray:
	t = span(0.9)
	along = t / 0.9
	# A soft thud under it: the key taken.
	phase = 2.0 * np.pi * np.cumsum(92.0 * np.exp(-t * 7.0) + 46.0) / RATE
	thud = np.sin(phase) * swell(t, 0.004, 9.0) * 0.8
	# A bright chord lifting off, and the air rising with it.
	chord = bell(0.9, [(587.3, 1.0, 3.6), (740.0, 0.6, 4.2), (880.0, 0.55, 4.6), (1174.7, 0.3, 6.0), (1760.0, 0.12, 9.0)], 0.01) * 0.42
	air = band(noise(0.9, 311), 500.0, 1500.0 + 4200.0 * along) * swell(t, 0.3, 5.0) * 0.22
	return echo(thud + chord + air, 0.9, 0.36, 313, 3400.0)


def hall_gate() -> np.ndarray:
	t = span(0.7)
	along = t / 0.7
	# The air drawn toward the gate, rising, and the gate's low answer.
	air = band(noise(0.7, 321), 220.0 + 500.0 * along, 900.0 + 3000.0 * along) * swell(t, 0.36, 6.0) * 0.8
	phase = 2.0 * np.pi * np.cumsum(98.0 * 2.0 ** (along * 0.42)) / RATE
	tone = (np.sin(phase) + 0.4 * np.sin(phase * 2.0)) * swell(t, 0.4, 6.5) * 0.36
	return echo(air + tone, 0.6, 0.32, 323, 2800.0)


def set_out() -> np.ndarray:
	length = 1.25
	t = span(length)
	along = t / length
	base = np.zeros_like(t)
	# The press landing: a short heavy stroke.
	strike_t = span(0.4)
	phase = 2.0 * np.pi * np.cumsum(120.0 * np.exp(-strike_t * 11.0) + 44.0) / RATE
	strike = np.sin(phase) * swell(strike_t, 0.003, 9.5) + band(noise(0.4, 331), 300.0, 2400.0) * swell(strike_t, 0.002, 30.0) * 0.5
	place(base, strike * 0.9, 0.0)
	# The air rushing in toward the way in, gathering all the way.
	rush = band(noise(length, 333), 200.0 + 300.0 * along, 700.0 + 3600.0 * along * along) * (along ** 1.7) * np.exp(-np.maximum(t - 0.95, 0.0) * 9.0) * 0.85
	glide = 2.0 * np.pi * np.cumsum(110.0 * 2.0 ** (along * 0.9)) / RATE
	tone = (np.sin(glide) + 0.45 * np.sin(glide * 2.0) + 0.2 * np.sin(glide * 3.0)) * (along ** 1.5) * np.exp(-np.maximum(t - 0.95, 0.0) * 8.0) * 0.32
	base += rush + tone
	# The dark closing: a deep stroke under everything.
	close_t = span(0.5)
	deep = 2.0 * np.pi * np.cumsum(70.0 * np.exp(-close_t * 6.0) + 36.0) / RATE
	place(base, np.sin(deep) * swell(close_t, 0.006, 6.0) * 0.95, 0.9)
	return echo(base, 1.0, 0.36, 335, 2400.0)


def chapter_toll() -> np.ndarray:
	# One low bell: its hum, its strike note, the minor third a bell carries.
	toll = bell(1.9, [(110.0, 0.7, 1.5), (220.0, 1.0, 2.0), (262.4, 0.5, 2.6), (330.0, 0.34, 3.4), (440.0, 0.3, 4.2), (661.0, 0.12, 6.0), (887.0, 0.06, 8.0)], 0.007)
	t = span(1.9)
	knock = band(noise(1.9, 341), 400.0, 1800.0) * swell(t, 0.002, 60.0) * 0.4
	return echo(toll * 0.6 + knock, 1.5, 0.46, 343, 2600.0)


SOUNDS = {
	"title_swell": title_swell,
	"title_start": title_start,
	"hall_gate": hall_gate,
	"set_out": set_out,
	"chapter_toll": chapter_toll,
}


def main() -> None:
	for name, make in SOUNDS.items():
		signal = make()
		target = write(name, signal)
		print(f"{target.relative_to(ROOT)}: {signal.size / RATE:.2f}s")


if __name__ == "__main__":
	main()
