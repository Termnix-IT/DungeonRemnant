"""Build the sounds of the fight's great moments.

These are the game's own sounds, made here from nothing but sums of tones
and filtered noise, with the same parts as the route's gates
(tools/build_gate_sounds.py; no recording is used, so they carry no licence
of anyone else's):

	card_deal    a boon card turned over as it is dealt: a dry flick
	card_take    the card taken: a low stroke and a bright chord opening
	level_surge  the power taken rising round her as the fight resumes
	boss_tremor  a boss foretold: the floor's low rumble and a far horn
	boss_fall    a boss falls: a great stroke, its tone sinking, light after

Each is written to audio/made/<cue>.ogg (Ogg Vorbis, mono, 44.1 kHz), its
peak just under full scale; GameAudio plays them by these names.

Needs numpy, and ffmpeg on PATH. Run from the Godot project root:

	python tools/build_battle_sounds.py
"""

from __future__ import annotations

import numpy as np

from build_gate_sounds import RATE, ROOT, band, echo, noise, place, span, swell, write


def tones(seconds: float, partials: list[tuple[float, float, float]], attack: float = 0.006) -> np.ndarray:
	"""Struck tones: each its own pitch, level and dying away."""
	t = span(seconds)
	out = np.zeros_like(t)
	for pitch, level, decay in partials:
		out += np.sin(2.0 * np.pi * pitch * t) * level * swell(t, attack, decay)
	return out


def card_deal() -> np.ndarray:
	t = span(0.16)
	# A dry flick: a breath of paper and a small knock as it lands.
	flick = band(noise(0.16, 401), 900.0, 5200.0) * swell(t, 0.004, 34.0) * 0.9
	knock = np.sin(2.0 * np.pi * (220.0 * np.exp(-t * 20.0) + 110.0) * t) * swell(t, 0.002, 30.0) * 0.5
	return echo(flick + knock, 0.25, 0.2, 403, 3200.0)


def card_take() -> np.ndarray:
	t = span(0.8)
	along = t / 0.8
	phase = 2.0 * np.pi * np.cumsum(104.0 * np.exp(-t * 8.0) + 52.0) / RATE
	stroke = np.sin(phase) * swell(t, 0.004, 8.0) * 0.8
	chord = tones(0.8, [(523.3, 1.0, 3.4), (659.3, 0.7, 3.8), (784.0, 0.62, 4.2), (1046.5, 0.4, 5.0), (1568.0, 0.16, 8.0)], 0.012) * 0.4
	air = band(noise(0.8, 411), 600.0, 1800.0 + 4400.0 * along) * swell(t, 0.25, 5.5) * 0.2
	return echo(stroke + chord + air, 0.9, 0.36, 413, 3400.0)


def level_surge() -> np.ndarray:
	t = span(0.7)
	along = t / 0.7
	air = band(noise(0.7, 421), 260.0 + 500.0 * along, 1200.0 + 3600.0 * along) * swell(t, 0.3, 6.0) * 0.7
	glide = 2.0 * np.pi * np.cumsum(196.0 * 2.0 ** (along * 1.0)) / RATE
	tone = (np.sin(glide) + 0.4 * np.sin(glide * 2.0)) * swell(t, 0.34, 6.5) * 0.34
	bell = np.zeros_like(t)
	place(bell, tones(0.45, [(784.0, 1.0, 5.0), (1174.7, 0.5, 6.0), (1568.0, 0.25, 8.0)], 0.01) * 0.3, 0.22)
	return echo(air + tone + bell, 0.7, 0.34, 423, 3200.0)


def boss_tremor() -> np.ndarray:
	length = 1.5
	t = span(length)
	along = t / length
	# The floor's rumble, swelling, and stones grinding in it.
	rumble = (np.sin(2.0 * np.pi * 41.0 * t) + 0.6 * np.sin(2.0 * np.pi * 55.0 * t + 0.7) + 0.4 * np.sin(2.0 * np.pi * 27.5 * t)) * swell(t, 0.7, 2.2) * 0.6
	grind = band(noise(length, 431), 60.0, 380.0 + 300.0 * along) * swell(t, 0.8, 2.4) * 0.7
	# A far horn: one low note with a slow beat in it.
	horn = (np.sin(2.0 * np.pi * 110.0 * t) + 0.5 * np.sin(2.0 * np.pi * 110.7 * t) + 0.35 * np.sin(2.0 * np.pi * 220.0 * t) + 0.2 * np.sin(2.0 * np.pi * 330.9 * t)) * swell(t, 0.5, 1.8) * 0.3
	return echo(rumble + grind + horn, 1.4, 0.42, 433, 1800.0)


def boss_fall() -> np.ndarray:
	length = 1.9
	t = span(length)
	base = np.zeros_like(t)
	# The stroke that fells it.
	strike_t = span(0.6)
	phase = 2.0 * np.pi * np.cumsum(150.0 * np.exp(-strike_t * 9.0) + 38.0) / RATE
	place(base, (np.sin(phase) * swell(strike_t, 0.003, 6.0) + band(noise(0.6, 441), 200.0, 2600.0) * swell(strike_t, 0.002, 18.0) * 0.6) * 1.0, 0.0)
	# Its tone sinking away.
	sink = 2.0 * np.pi * np.cumsum(196.0 * 2.0 ** (-t / length * 1.6)) / RATE
	base += (np.sin(sink) + 0.5 * np.sin(sink * 1.5) + 0.3 * np.sin(sink * 2.02)) * swell(t, 0.05, 2.2) * 0.3
	# Light after it: high tones opening one after another.
	for at, pitch in [(0.45, 587.3), (0.62, 880.0), (0.8, 1174.7), (1.0, 1760.0)]:
		place(base, tones(0.8, [(pitch, 1.0, 4.0), (pitch * 2.0, 0.3, 6.0)], 0.02) * 0.16, at)
	return echo(base, 1.6, 0.44, 443, 2600.0)


SOUNDS = {
	"card_deal": card_deal,
	"card_take": card_take,
	"level_surge": level_surge,
	"boss_tremor": boss_tremor,
	"boss_fall": boss_fall,
}


def main() -> None:
	for name, make in SOUNDS.items():
		signal = make()
		target = write(name, signal)
		print(f"{target.relative_to(ROOT)}: {signal.size / RATE:.2f}s")


if __name__ == "__main__":
	main()
