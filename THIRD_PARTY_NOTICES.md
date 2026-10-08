# Third-Party Notices

Dungeon Remnant uses the following third-party software and assets. These notices do not change the license of Dungeon Remnant's own source code or original game assets.

## Godot Engine

This game uses Godot Engine, available under the following license:

Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Godot Engine license and attribution guidance: <https://godotengine.org/license/>

Godot Engine also contains third-party components under compatible licenses. Include the `COPYRIGHT.txt` file from the matching Godot Engine release with desktop distributions. The complete notice for Godot 4.7.2 is available at <https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt>.

## Godot Engine Icon

`rogue-like-play/icon.svg` is the default Godot Engine icon.

Godot Engine Logo

Copyright (c) 2017 Andrea Calabró

Licensed under the Creative Commons Attribution 4.0 International license (CC BY 4.0 International): <https://creativecommons.org/licenses/by/4.0/>

Godot logo and icon usage guidance: <https://godotengine.org/press/>

## Shippori Mincho

`rogue-like-play/ui/fonts/ShipporiMincho-Bold.ttf` and `ShipporiMincho-Medium.ttf` are the Shippori Mincho typeface, used for headings, the logo and emphasised numbers.

Copyright 2021 The Shippori Mincho Project Authors (https://github.com/fontdasu/ShipporiMincho)

This Font Software is licensed under the SIL Open Font License, Version 1.1. The full license text is `rogue-like-play/ui/fonts/OFL.txt`, which is distributed with the game as `SHIPPORI_MINCHO_OFL.txt`.

## Sound effects and ambience

The sound effects and room tones below are third-party recordings. Each original is kept unmodified in `rogue-like-play/audio/third_party/<pack>/source/`; the game plays copies that `rogue-like-play/tools/build_sound_effects.py` level-matches, peak-limits and encodes as Ogg Vorbis (one-shot effects also have their leading silence trimmed). Each folder's `SOURCE.txt` records the download and the files used. Hit and victory sounds remain the game's own synthesized placeholders.

### RPG sound pack

RPG sound pack by artisticdude: <https://opengameart.org/content/rpg-sound-pack>

Used: `battle/swing.wav` (sword swing) and `interface/interface6.wav` (confirm), in `rogue-like-play/audio/third_party/artisticdude_rpg_sound_pack/`.

License: Creative Commons Zero 1.0 Universal (CC0 1.0): <https://creativecommons.org/publicdomain/zero/1.0/>

### 80 CC0 RPG SFX

80 CC0 RPG SFX by rubberduck: <https://opengameart.org/content/80-cc0-rpg-sfx>

Used: `blade_03.ogg` (spear thrust), `spell_01.ogg` (spell), `creature_misc_01.ogg` (enemy defeated), `item_gem_01.ogg` (pickup) and `creature_roar_03.ogg` (boss appears), in `rogue-like-play/audio/third_party/rubberduck_80_cc0_rpg_sfx/`.

License: Creative Commons Zero 1.0 Universal (CC0 1.0): <https://creativecommons.org/publicdomain/zero/1.0/>

### Impact Sounds

Impact Sounds by Kenney (www.kenney.nl): <https://kenney.nl/assets/impact-sounds>

Used: `impactPlate_heavy_000.ogg` (hammer) and `footstep_carpet_000.ogg` (footstep), in `rogue-like-play/audio/third_party/kenney_impact_sounds/`.

License: Creative Commons Zero 1.0 Universal (CC0 1.0): <https://creativecommons.org/publicdomain/zero/1.0/>

### Music Jingles

Music Jingles by Kenney (www.kenney.nl): <https://kenney.nl/assets/music-jingles>

Used: `jingles_NES13.ogg` (level up), `jingles_PIZZI06.ogg` (floor arrival), `jingles_HIT15.ogg` (monster house warning) and `jingles_NES05.ogg` (defeat), in `rogue-like-play/audio/third_party/kenney_music_jingles/`.

License: Creative Commons Zero 1.0 Universal (CC0 1.0): <https://creativecommons.org/publicdomain/zero/1.0/>

### Dark Cavern Ambient

Dark Cavern Ambient by Paul Wortmann: <https://opengameart.org/content/dark-cavern-ambient>

Used: `dark_cavern_ambient_002.ogg` (ruins room tone), in `rogue-like-play/audio/third_party/paul_wortmann_dark_cavern_ambient/`.

License: Creative Commons Zero 1.0 Universal (CC0 1.0): <https://creativecommons.org/publicdomain/zero/1.0/>

### Forest Ambience

Forest Ambience by TinyWorlds: <https://opengameart.org/content/forest-ambience>

Used: `Forest_Ambience.mp3` (forest room tone), in `rogue-like-play/audio/third_party/tinyworlds_forest_ambience/`.

License: Creative Commons Zero 1.0 Universal (CC0 1.0): <https://creativecommons.org/publicdomain/zero/1.0/>
