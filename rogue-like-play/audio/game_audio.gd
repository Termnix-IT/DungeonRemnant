class_name GameAudio
extends RefCounted
## Temporary synthesized cues. Supply real assets with set_override() when available.

const SAMPLE_RATE := 22050
const MAX_VOICES := 8
const VOICE_GROUP := &"game_audio_voices"
# duration, start/end frequency, noise share, decay, optional note sequence
const PROFILES := {
	&"slash": [0.14, 1100.0, 240.0, 0.82, 1.5, []],
	&"thrust": [0.11, 520.0, 120.0, 0.55, 2.0, []],
	&"heavy": [0.24, 150.0, 42.0, 0.32, 2.2, []],
	&"magic": [0.27, 350.0, 1400.0, 0.08, 1.2, []],
	&"hit": [0.09, 190.0, 75.0, 0.70, 2.4, []],
	&"death": [0.28, 300.0, 60.0, 0.22, 1.6, []],
	&"pickup": [0.15, 780.0, 1200.0, 0.0, 1.8, []],
	&"step": [0.055, 110.0, 65.0, 0.85, 2.5, []],
	&"confirm": [0.12, 660.0, 880.0, 0.0, 1.4, []],
	&"level_up": [0.48, 0.0, 0.0, 0.0, 1.0, [523.25, 659.25, 783.99, 1046.5]],
	&"floor": [0.36, 0.0, 0.0, 0.0, 1.4, [392.0, 523.25, 659.25]],
	&"warning": [0.38, 0.0, 0.0, 0.12, 1.0, [220.0, 207.65, 220.0]],
	&"victory": [0.72, 0.0, 0.0, 0.0, 0.9, [523.25, 659.25, 783.99, 1046.5]],
	&"defeat": [0.62, 0.0, 0.0, 0.04, 1.8, [392.0, 329.63, 261.63, 196.0]],
}

static var _streams: Dictionary = {}
static var _overrides: Dictionary = {}


static func set_override(cue: StringName, stream: AudioStream) -> void:
	if stream == null:
		_overrides.erase(cue)
	else:
		_overrides[cue] = stream


static func clear_overrides() -> void:
	_overrides.clear()


static func stream_for(cue: StringName) -> AudioStream:
	if _overrides.has(cue):
		return _overrides[cue]
	if not PROFILES.has(cue):
		return null
	if not _streams.has(cue):
		_streams[cue] = _synthesize(cue)
	return _streams[cue]


static func play(parent: Node, cue: StringName, volume_db: float = -16.0) -> AudioStreamPlayer:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return null
	if DisplayServer.get_name() == "headless":
		return null
	var stream := stream_for(cue)
	if stream == null:
		return null
	var voices := parent.get_tree().get_nodes_in_group(VOICE_GROUP)
	# Remove from the group immediately: multiple cues can arrive within one frame.
	while voices.size() >= MAX_VOICES:
		var oldest := voices.pop_front() as AudioStreamPlayer
		if is_instance_valid(oldest):
			oldest.stop()
			oldest.remove_from_group(VOICE_GROUP)
			oldest.queue_free()
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = clampf(volume_db, -60.0, -12.0)
	parent.add_child(player)
	player.add_to_group(VOICE_GROUP)
	player.finished.connect(player.queue_free)
	# Also retire accidentally looped overrides or externally stopped voices.
	var lifetime := Timer.new()
	lifetime.one_shot = true
	lifetime.wait_time = clampf(stream.get_length() + 0.15, 0.2, 5.0)
	player.add_child(lifetime)
	lifetime.timeout.connect(player.queue_free)
	lifetime.start()
	player.play()
	return player


static func _synthesize(cue: StringName) -> AudioStreamWAV:
	var profile: Array = PROFILES[cue]
	var duration: float = profile[0]
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = String(cue).hash()
	var phase := 0.0
	var notes: Array = profile[5]
	var filtered_noise := 0.0
	for i in range(count):
		var progress := float(i) / float(count - 1)
		var time := float(i) / SAMPLE_RATE
		var frequency := lerpf(profile[1], profile[2], progress)
		var note_envelope := 1.0
		if not notes.is_empty():
			var note_progress := progress * notes.size()
			frequency = notes[mini(int(note_progress), notes.size() - 1)]
			var local_progress := fmod(note_progress, 1.0)
			note_envelope = minf(local_progress / 0.06, 1.0) * pow(1.0 - local_progress, 0.7)
		phase += TAU * frequency / SAMPLE_RATE
		filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.55)
		var tone := sin(phase) * 0.82 + sin(phase * 2.0) * 0.18
		var envelope := minf(time / 0.004, 1.0) * pow(1.0 - progress, float(profile[4]))
		var value := lerpf(tone, filtered_noise, profile[3]) * envelope * note_envelope * 0.72
		bytes.encode_s16(i * 2, int(clampf(value, -0.9, 0.9) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
