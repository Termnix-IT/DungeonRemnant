class_name BattleAmbience
extends AudioStreamPlayer

# The battlefield's air: a low wind that swells and falls, generated once
# (no recording) and looped seamlessly on the Ambience bus, so the
# settings' ambience volume governs it. Silent where nothing is heard
# (headless runs).

const SAMPLE_RATE := 22050
const LENGTH := 8.0
# The tail mixed over the head so the loop has no seam.
const CROSSFADE := 0.6
# The wind's swells per loop (whole numbers keep the loop seamless).
const SWELLS := 2.0
const VOLUME_DB := -18.0
static var _stream: AudioStreamWAV


func _ready() -> void:
	bus = GameSettings.AMBIENCE_BUS
	volume_db = VOLUME_DB
	if DisplayServer.get_name() == "headless":
		return
	stream = loop()
	play()


# The looped wind, made on first use.
static func loop() -> AudioStreamWAV:
	if _stream == null:
		_stream = _synthesize()
	return _stream


static func _synthesize() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * LENGTH)
	var fade := int(SAMPLE_RATE * CROSSFADE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7071
	var raw := PackedFloat32Array()
	raw.resize(count + fade)
	var low := 0.0
	var lower := 0.0
	for i in raw.size():
		# Noise smoothed twice: a dull rush with no hiss.
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.06)
		lower = lerpf(lower, low, 0.12)
		var time := float(i % count) / SAMPLE_RATE
		var swell := 0.55 + 0.45 * sin(TAU * SWELLS * time / LENGTH)
		raw[i] = lower * swell * 3.2
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var value := raw[i]
		if i < fade:
			value = lerpf(raw[count + i], raw[i], float(i) / fade)
		bytes.encode_s16(i * 2, int(clampf(value, -0.9, 0.9) * 32767.0))
	var wind := AudioStreamWAV.new()
	wind.format = AudioStreamWAV.FORMAT_16_BITS
	wind.mix_rate = SAMPLE_RATE
	wind.stereo = false
	wind.data = bytes
	wind.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wind.loop_begin = 0
	wind.loop_end = count
	return wind
