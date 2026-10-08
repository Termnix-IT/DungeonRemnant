"""Build the game's sound cues from the third-party recordings.

Each cue's original stays untouched in audio/third_party/<pack>/source/
(which Godot does not import). This writes audio/third_party/<pack>/<cue>.ogg:
leading silence trimmed (one-shots only, so a hit sounds on the frame it
lands), the level matched to the mean loudness of the synthesized cue it
replaces (GameAudio and DungeonAmbience), peaks held under full scale by a
limiter, encoded as Ogg Vorbis. Matching the old level keeps the volume each
caller passes to GameAudio.play meaning what it did; play() caps volume at
-12 dB, so a quiet recording could not be raised at run time instead.

Needs ffmpeg on PATH. Rerun after changing CUES:

	python tools/build_sound_effects.py
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THIRD_PARTY = ROOT / "audio" / "third_party"
# cue: (pack folder, original file, target mean loudness in dB). The target is
# the synthesized cue's mean volume measured by ffmpeg's volumedetect.
CUES = {
	"slash": ("artisticdude_rpg_sound_pack", "swing.wav", -19.5),
	"thrust": ("rubberduck_80_cc0_rpg_sfx", "blade_03.ogg", -19.9),
	"heavy": ("kenney_impact_sounds", "impactPlate_heavy_000.ogg", -18.1),
	"magic": ("rubberduck_80_cc0_rpg_sfx", "spell_01.ogg", -13.6),
	"death": ("rubberduck_80_cc0_rpg_sfx", "creature_misc_01.ogg", -15.8),
	"pickup": ("rubberduck_80_cc0_rpg_sfx", "item_gem_01.ogg", -14.4),
	"step": ("kenney_impact_sounds", "footstep_carpet_000.ogg", -21.3),
	"confirm": ("artisticdude_rpg_sound_pack", "interface6.wav", -13.6),
	"level_up": ("kenney_music_jingles", "jingles_NES13.ogg", -15.9),
	"floor": ("kenney_music_jingles", "jingles_PIZZI06.ogg", -16.6),
	"warning": ("kenney_music_jingles", "jingles_HIT15.ogg", -16.8),
	"boss": ("rubberduck_80_cc0_rpg_sfx", "creature_roar_03.ogg", -17.0),
	"defeat": ("kenney_music_jingles", "jingles_NES05.ogg", -17.8),
	# Loops: never trimmed, so the seam stays where the author made it.
	"ambience_ruins": ("paul_wortmann_dark_cavern_ambient", "dark_cavern_ambient_002.ogg", -18.0),
	"ambience_forest": ("tinyworlds_forest_ambience", "Forest_Ambience.mp3", -21.0),
}
TRIM = "silenceremove=start_periods=1:start_threshold=-50dB"
LIMIT = "alimiter=limit=0.95:level=disabled"


def mean_volume(path: Path, prefilter: str = "") -> float:
	chain = (prefilter + "," if prefilter else "") + "volumedetect"
	result = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", chain, "-f", "null", "-"], capture_output=True, text=True, encoding="utf-8", errors="replace", check=True)
	return float(re.search(r"mean_volume: (-?[\d.]+) dB", result.stderr).group(1))


def build(cue: str, pack: str, original: str, target: float) -> tuple[float, float]:
	source = THIRD_PARTY / pack / "source" / original
	trim = "" if cue.startswith("ambience_") else TRIM
	gain = target - mean_volume(source, trim)
	chain = ",".join(part for part in [trim, "volume=%.2fdB" % gain, LIMIT] if part)
	out = THIRD_PARTY / pack / ("%s.ogg" % cue)
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source), "-af", chain, "-c:a", "libvorbis", "-q:a", "5", str(out)], check=True)
	return gain, mean_volume(out)


def main() -> None:
	for cue, (pack, original, target) in CUES.items():
		gain, result = build(cue, pack, original, target)
		print("%-16s %+6.1f dB -> mean %.1f dB (target %.1f)  %s/%s.ogg" % (cue, gain, result, target, pack, cue))


if __name__ == "__main__":
	main()
