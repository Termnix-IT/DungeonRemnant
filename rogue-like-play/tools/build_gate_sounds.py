"""Build the sounds of the route's gates.

These are the game's own sounds, made here from nothing but sums of tones
and filtered noise (no recording is used, so they carry no licence of
anyone else's):

	gate_turn   a gate answers as it is turned to: a breath of air and a low bell
	gate_shut   a gate's iron grille lands: a thud, the iron ringing, a rattle
	gate_lift   the grilles are drawn back up: a short run of the chain
	gate_go     she walks into the light: a chord rising out of the air
	gate_wake   the boss's gate lights: a swell from under the floor
	gate_charge the gate chosen gathers its light as the others shut: a low
	            breath swelling, a tone climbing in it

Each is written to audio/made/<cue>.ogg (Ogg Vorbis, mono, 44.1 kHz), its
peak just under full scale; GameAudio plays them by these names. A hall's
echo is put on each by convolving it with decaying noise.

Needs numpy, and ffmpeg on PATH. Run from the Godot project root:

	python tools/build_gate_sounds.py
"""

from __future__ import annotations

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "audio" / "made"
RATE = 44100
PEAK = 0.89


def span(seconds: float) -> np.ndarray:
	return np.arange(int(RATE * seconds)) / RATE


def lowpass(signal: np.ndarray, cutoff: float | np.ndarray) -> np.ndarray:
	"""One pole, its cutoff a number or changing along the sound."""
	cutoffs = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), signal.shape)
	share = 1.0 - np.exp(-2.0 * np.pi * cutoffs / RATE)
	out = np.empty_like(signal)
	held = 0.0
	for index in range(signal.size):
		held += share[index] * (signal[index] - held)
		out[index] = held
	return out


def band(signal: np.ndarray, low: float | np.ndarray, high: float | np.ndarray) -> np.ndarray:
	return lowpass(signal, high) - lowpass(signal, low)


def noise(seconds: float, seed: int) -> np.ndarray:
	return np.random.default_rng(seed).uniform(-1.0, 1.0, int(RATE * seconds))


def swell(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
	"""Rises over `attack` seconds, then dies away at `decay` a second."""
	return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-np.maximum(t - attack, 0.0) * decay)


def place(base: np.ndarray, part: np.ndarray, at: float) -> None:
	start = int(RATE * at)
	end = min(base.size, start + part.size)
	if end > start:
		base[start:end] += part[: end - start]


def echo(signal: np.ndarray, seconds: float, share: float, seed: int, bright: float = 2600.0) -> np.ndarray:
	"""The hall's echo: the sound convolved with noise dying away."""
	t = span(seconds)
	room = lowpass(noise(seconds, seed) * np.exp(-t * 6.0 / seconds), bright)
	size = signal.size + room.size - 1
	wet = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(room, size), size)
	wet *= share * np.abs(signal).max() / max(np.abs(wet).max(), 1e-9)
	out = np.zeros(size)
	out[: signal.size] += signal
	return out + wet


def gate_turn() -> np.ndarray:
	t = span(0.5)
	# The air drawn through the gate.
	air = band(noise(0.5, 11), 500.0, 2400.0 + 1600.0 * np.exp(-t * 9.0)) * swell(t, 0.06, 9.0) * 0.9
	# A low bell under it, its partials a little out of tune with each other.
	bell = np.zeros_like(t)
	for pitch, level, decay in [(196.0, 1.0, 7.0), (293.7, 0.5, 9.0), (392.9, 0.3, 11.0), (587.3, 0.16, 14.0)]:
		bell += np.sin(2.0 * np.pi * pitch * t) * level * swell(t, 0.008, decay)
	return echo(air + bell * 0.55, 0.5, 0.3, 21)


def gate_shut() -> np.ndarray:
	t = span(0.9)
	# The weight landing: a thud falling in pitch, and the stone it strikes.
	sweep = 2.0 * np.pi * np.cumsum(46.0 + 80.0 * np.exp(-t * 26.0)) / RATE
	thud = np.sin(sweep) * swell(t, 0.003, 13.0)
	knock = lowpass(noise(0.9, 31), 900.0) * swell(t, 0.002, 34.0) * 1.2
	# The iron ringing: partials no string would give.
	iron = np.zeros_like(t)
	rng = np.random.default_rng(37)
	for pitch, level, decay in [(311.0, 0.5, 6.0), (523.0, 0.42, 7.5), (791.0, 0.36, 9.0), (1187.0, 0.26, 11.0), (1639.0, 0.2, 14.0), (2213.0, 0.14, 18.0), (2987.0, 0.08, 24.0)]:
		pitch *= 1.0 + rng.uniform(-0.012, 0.012)
		iron += np.sin(2.0 * np.pi * pitch * t + rng.uniform(0.0, 6.28)) * level * swell(t, 0.002, decay)
	out = thud * 1.0 + knock + iron * 0.42
	# It settles: a few smaller knocks of iron on iron.
	for at, level in [(0.11, 0.34), (0.19, 0.2), (0.25, 0.12)]:
		click_t = span(0.09)
		click = band(noise(0.09, int(at * 1000)), 900.0, 4200.0) * swell(click_t, 0.001, 60.0)
		click += np.sin(2.0 * np.pi * 1420.0 * click_t) * swell(click_t, 0.001, 46.0) * 0.5
		place(out, click * level, at)
	return echo(out, 0.7, 0.34, 41, 1900.0)


def gate_lift() -> np.ndarray:
	out = np.zeros(int(RATE * 0.5))
	rng = np.random.default_rng(53)
	# The chain running over its wheel, each link a little quicker.
	at = 0.0
	gap = 0.07
	for link in range(9):
		click_t = span(0.06)
		pitch = 1250.0 + rng.uniform(-160.0, 220.0)
		click = band(noise(0.06, 60 + link), 1200.0, 5200.0) * swell(click_t, 0.001, 85.0)
		click += np.sin(2.0 * np.pi * pitch * click_t) * swell(click_t, 0.001, 70.0) * 0.6
		place(out, click * (0.5 + 0.06 * link), at)
		at += gap
		gap *= 0.86
	# And the iron drawn up through the stone.
	t = span(0.5)
	scrape = band(noise(0.5, 71), 300.0, 900.0 + 1500.0 * t / 0.5) * swell(t, 0.2, 7.0) * 0.5
	return echo(out + scrape, 0.45, 0.28, 73)


def gate_go() -> np.ndarray:
	t = span(1.3)
	# A chord opening upward, each voice coming in a little after the last.
	chord = np.zeros_like(t)
	for order, pitch in enumerate([220.0, 329.6, 440.0, 554.4, 659.3, 880.0]):
		voice_t = np.maximum(t - order * 0.07, 0.0)
		rise = np.minimum(voice_t / 0.45, 1.0) ** 1.6
		tremble = 1.0 + 0.004 * np.sin(2.0 * np.pi * 5.2 * t + order)
		chord += np.sin(2.0 * np.pi * pitch * tremble * t) * rise / (1.0 + order * 0.35)
	# The air rushing toward the light, brightening as it comes.
	rush = band(noise(1.3, 83), 300.0, 800.0 + 5200.0 * (t / 1.3) ** 2) * (t / 1.3) ** 1.5 * 1.6
	out = (chord * 0.5 + rush) * np.minimum((1.3 - t) / 0.18, 1.0)
	return echo(out, 0.8, 0.4, 89, 4200.0)


def gate_wake() -> np.ndarray:
	t = span(1.1)
	# Something turning over under the floor.
	rumble = lowpass(noise(1.1, 97), 130.0) * 3.0 + np.sin(2.0 * np.pi * 49.0 * t) + np.sin(2.0 * np.pi * 73.5 * t) * 0.6
	growl = np.zeros_like(t)
	for pitch, level in [(98.0, 0.6), (147.5, 0.4), (207.0, 0.3), (311.5, 0.18)]:
		growl += np.sign(np.sin(2.0 * np.pi * pitch * t)) * level
	growl = lowpass(growl, 500.0 + 900.0 * swell(t, 0.25, 3.0))
	shape = swell(t, 0.22, 3.4)
	hiss = band(noise(1.1, 101), 1500.0, 6000.0) * swell(t, 0.3, 5.0) * 0.35
	return echo((rumble * 0.8 + growl * 0.55) * shape + hiss, 0.8, 0.36, 103, 1500.0)


def gate_charge() -> np.ndarray:
	t = span(0.85)
	along = t / 0.85
	# The air drawn in toward the gate, brightening as it gathers.
	air = band(noise(0.85, 107), 180.0, 1300.0 + 2400.0 * along) * swell(t, 0.42, 4.5) * 0.55
	# A tone climbing half an octave in it, and the floor answering under it.
	phase = 2.0 * np.pi * np.cumsum(196.0 * 2.0 ** (along * 0.5)) / RATE
	tone = (np.sin(phase) + 0.45 * np.sin(phase * 2.0) + 0.2 * np.sin(phase * 3.01)) * swell(t, 0.5, 5.0) * 0.4
	low = np.sin(2.0 * np.pi * 61.0 * t) * swell(t, 0.3, 3.2) * 0.5
	return echo(air + tone + low, 0.7, 0.34, 109, 2600.0)


SOUNDS = {
	"gate_turn": gate_turn,
	"gate_shut": gate_shut,
	"gate_lift": gate_lift,
	"gate_go": gate_go,
	"gate_wake": gate_wake,
	"gate_charge": gate_charge,
}


def write(name: str, signal: np.ndarray) -> Path:
	# Clean ends, and its peak just under full scale.
	edge = int(RATE * 0.004)
	signal = signal.copy()
	signal[:edge] *= np.linspace(0.0, 1.0, edge)
	tail = int(RATE * 0.05)
	signal[-tail:] *= np.linspace(1.0, 0.0, tail)
	signal *= PEAK / max(np.abs(signal).max(), 1e-9)
	OUTPUT.mkdir(parents=True, exist_ok=True)
	target = OUTPUT / f"{name}.ogg"
	with tempfile.TemporaryDirectory() as scratch:
		raw = Path(scratch) / f"{name}.wav"
		with wave.open(str(raw), "wb") as file:
			file.setnchannels(1)
			file.setsampwidth(2)
			file.setframerate(RATE)
			file.writeframes((signal * 32767.0).astype("<i2").tobytes())
		subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw), "-c:a", "libvorbis", "-q:a", "5", str(target)], check=True)
	return target


def main() -> None:
	for name, make in SOUNDS.items():
		signal = make()
		target = write(name, signal)
		print(f"{target.relative_to(ROOT)}: {signal.size / RATE:.2f}s")


if __name__ == "__main__":
	main()
