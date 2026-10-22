"""Build the game's music loops from the third-party recordings.

Each track's original stays untouched in audio/third_party/<pack>/source/
(which Godot does not import). This writes audio/third_party/<pack>/<track>.ogg:
the silence at either end trimmed when the author did not make it a seamless
loop (so the fade out runs straight into the fade in), the loudness evened
out to TARGET_LUFS with loudnorm so one music volume fits every track, and
encoded as Ogg Vorbis. GameMusic loops each one.

Needs ffmpeg on PATH. Rerun after changing TRACKS:

	python tools/build_music.py
"""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THIRD_PARTY = ROOT / "audio" / "third_party"
# Integrated loudness every track is brought to, and its true peak ceiling.
TARGET_LUFS = -20.0
PEAK_DB = -1.5
# track: (pack folder, original file, already a seamless loop).
TRACKS = {
	"hub": ("randommind_medieval_exploration", "Exploration.mp3", False),
	"battle": ("cynicmusic_battle_theme_a", "battleThemeA.mp3", False),
	"boss": ("juhani_junkala_epic_boss_battle", "Epic Boss Battle [Seamlessly Looping].flac", True),
}
# Below this a sample counts as the silence a track starts or ends with.
SILENCE = "-60dB"


def build(track: str, pack: str, original: str, seamless: bool) -> None:
	source = THIRD_PARTY / pack / "source" / original
	out = THIRD_PARTY / pack / f"{track}.ogg"
	steps = []
	if not seamless:
		trim = f"silenceremove=start_periods=1:start_threshold={SILENCE}"
		steps += [trim, "areverse", trim, "areverse"]
	steps.append(f"loudnorm=I={TARGET_LUFS}:TP={PEAK_DB}:LRA=11")
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source), "-af", ",".join(steps), "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", str(out)], check=True)
	print(f"Saved {out.relative_to(ROOT)}")


def main() -> None:
	for track, (pack, original, seamless) in TRACKS.items():
		build(track, pack, original, seamless)


if __name__ == "__main__":
	main()
