extends SceneTree

const Audio := preload("res://audio/game_audio.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func run_tests() -> void:
	seed(1729)
	var expected_random := randi()
	seed(1729)
	var signatures: Array[int] = []
	for cue in Audio.PROFILES:
		var stream := Audio.synthesized(cue) as AudioStreamWAV
		check(stream != null, "%s generated" % cue)
		check(stream.get_length() > 0.04 and stream.get_length() < 0.8, "%s bounded duration" % cue)
		check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s finite playback" % cue)
		var bytes := stream.data
		var peak := 0
		for i in range(0, bytes.size(), 2):
			peak = maxi(peak, absi(bytes.decode_s16(i)))
		check(peak > 100 and peak < 30000, "%s audible without clipping" % cue)
		check(bytes.decode_s16(0) == 0 and bytes.decode_s16(bytes.size() - 2) == 0, "%s clean endpoints" % cue)
		check(Audio.synthesized(cue) == stream, "%s cached" % cue)
		check(not signatures.has(hash(bytes)), "%s distinct waveform" % cue)
		signatures.append(hash(bytes))
	check(randi() == expected_random, "Synthesis does not consume gameplay random state")
	check(Audio.stream_for(&"unknown") == null, "Unknown cues are silent")
	# Recorded cues replace their placeholders; the rest keep the synthesized sound.
	for cue: StringName in Audio.ASSETS:
		var sound := Audio.stream_for(cue)
		check(sound is AudioStreamOggVorbis and sound == Audio.recorded(cue), "%s plays its recording" % cue)
		check(not (sound as AudioStreamOggVorbis).loop and sound.get_length() > 0.05 and sound.get_length() < 4.8, "%s is a finite one-shot inside the voice lifetime" % cue)
		check(Audio.PROFILES.has(cue), "%s keeps a synthesized fallback" % cue)
	for cue: StringName in [&"hit", &"victory", &"level_up"]:
		check(not Audio.ASSETS.has(cue) and Audio.stream_for(cue) == Audio.synthesized(cue), "%s stays synthesized" % cue)
	var default_stream := Audio.stream_for(&"slash")
	var replacement := AudioStreamWAV.new()
	Audio.set_override(&"slash", replacement)
	check(Audio.stream_for(&"slash") == replacement, "Real asset override takes precedence")
	Audio.set_override(&"slash", null)
	check(Audio.stream_for(&"slash") == default_stream, "Removing override restores cached fallback")
	var detached := Node.new()
	check(Audio.play(detached, &"hit") == null, "Detached parents do not create voices")
	detached.free()
	var parent := Node.new()
	root.add_child(parent)
	if DisplayServer.get_name() == "headless":
		check(Audio.play(parent, &"hit") == null and parent.get_child_count() == 0, "Headless playback is silent and allocation free")
	else:
		for i in range(16):
			Audio.play(parent, &"hit", -60.0)
		check(get_nodes_in_group(Audio.VOICE_GROUP).size() == Audio.MAX_VOICES, "Same-frame voice burst respects cap")
		await create_timer(0.4).timeout
		await process_frame
		check(parent.get_child_count() == 0, "Finished voices and timers leave no children")
		var looping := (Audio.stream_for(&"hit") as AudioStreamWAV).duplicate() as AudioStreamWAV
		looping.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looping.loop_end = looping.data.size() / 2
		Audio.set_override(&"hit", looping)
		Audio.play(parent, &"hit", -60.0)
		await create_timer(0.4).timeout
		await process_frame
		check(parent.get_child_count() == 0, "Looped override cannot leak voices")
		Audio.clear_overrides()
	parent.queue_free()
	await process_frame
	# The battlefield's wind: one seamless loop on the ambience bus.
	var wind := BattleAmbience.loop()
	check(wind.loop_mode == AudioStreamWAV.LOOP_FORWARD and wind.loop_end * 2 == wind.data.size() and is_equal_approx(wind.get_length(), BattleAmbience.LENGTH), "The wind loops over its whole length")
	var tail := wind.data.decode_s16(wind.data.size() - 2)
	var head := wind.data.decode_s16(0)
	var peak := 0
	for index in range(0, wind.data.size(), 64):
		peak = maxi(peak, absi(wind.data.decode_s16(index)))
	check(absi(head - tail) < 600 and peak > 800 and peak < 30000, "The wind is heard, unclipped, with no click where it loops")
	check(BattleAmbience.loop() == wind, "The wind is made once")
	var air := BattleAmbience.new()
	root.add_child(air)
	check(air.bus == GameSettings.AMBIENCE_BUS, "The wind plays on the ambience bus, under its volume setting")
	air.free()
	# The music: one track at a time on the Music bus, crossfading, muffled on demand.
	check(AudioServer.get_bus_index(GameSettings.MUSIC_BUS) >= 0 and AudioServer.get_bus_effect(AudioServer.get_bus_index(GameSettings.MUSIC_BUS), 0) is AudioEffectLowPassFilter, "The Music bus carries its low-pass filter")
	for track: StringName in GameMusic.TRACKS:
		var loop: AudioStream = load(GameMusic.TRACKS[track])
		check(loop is AudioStreamOggVorbis and loop.get_length() > 60.0, "%s is a long recorded track" % track)
	var music := GameMusic.new()
	root.add_child(music)
	music.play(&"battle")
	check(music.track == &"battle" and GameMusic.find(root) == music, "A track is cued and the player is found")
	var playing := music._current
	music.play(&"battle")
	check(music._current == playing, "Cueing the same track again changes nothing")
	music.play(&"boss")
	check(music.track == &"boss" and music._current != playing, "A new track takes the other player, to crossfade")
	music.set_muffled(true)
	await create_timer(GameMusic.MUFFLE_TIME + 0.1).timeout
	var filter := AudioServer.get_bus_effect(AudioServer.get_bus_index(GameSettings.MUSIC_BUS), 0) as AudioEffectLowPassFilter
	check(music.muffled and filter.cutoff_hz < 1000.0, "Muffled, the highs are cut")
	music.set_muffled(false)
	await create_timer(GameMusic.MUFFLE_TIME + 0.1).timeout
	check(not music.muffled and filter.cutoff_hz > 20000.0, "And let through again")
	music.free()
	var tuned := GameSettings.new()
	tuned.path = "res://.godot/music-settings-%d.cfg" % Time.get_ticks_usec()
	tuned.music_volume = 0.35
	tuned.save_settings()
	var reread := GameSettings.new()
	reread.path = tuned.path
	reread.load_settings()
	check(is_equal_approx(reread.music_volume, 0.35), "The music's volume is kept with the settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tuned.path))
	print("Game audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
