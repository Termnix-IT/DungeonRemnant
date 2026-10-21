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
	print("Game audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
