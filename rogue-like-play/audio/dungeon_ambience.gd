extends AudioStreamPlayer
## Quiet provisional room tone. Replace with a looping ambience asset when available.

@export var stream_override: AudioStream
const SAMPLE_RATE := 22050
const DURATION := 2.0
static var _streams: Dictionary = {}


func start(forest: bool = false) -> void:
	var next_stream: AudioStream = stream_override if stream_override != null else stream_for(forest)
	volume_db = -32.0
	if stream != next_stream:
		stream = next_stream
	if is_inside_tree() and DisplayServer.get_name() != "headless" and not playing:
		play()


static func stream_for(forest: bool = false) -> AudioStreamWAV:
	if _streams.has(forest):
		return _streams[forest]
	var sample_count := int(SAMPLE_RATE * DURATION)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	# All component frequencies complete whole cycles in two seconds.
	# Noise-like upper harmonics provide air without random discontinuities at the seam.
	for i in range(sample_count):
		var time := float(i) / SAMPLE_RATE
		var breath := 0.75 + 0.25 * cos(TAU * 0.5 * time)
		var value := 0.0
		if forest:
			value = sin(TAU * 173.5 * time) * 0.12 + sin(TAU * 271.0 * time) * 0.1
			value += sin(TAU * 619.5 * time) * 0.045 + sin(TAU * 937.0 * time) * 0.025
		else:
			value = sin(TAU * 55.0 * time) * 0.2 + sin(TAU * 82.5 * time) * 0.1
			value += sin(TAU * 137.0 * time) * 0.05 + sin(TAU * 223.5 * time) * 0.025
		bytes.encode_s16(i * 2, int(value * breath * 32767.0))
	var generated := AudioStreamWAV.new()
	generated.format = AudioStreamWAV.FORMAT_16_BITS
	generated.mix_rate = SAMPLE_RATE
	generated.data = bytes
	generated.loop_mode = AudioStreamWAV.LOOP_FORWARD
	generated.loop_begin = 0
	generated.loop_end = sample_count
	_streams[forest] = generated
	return generated
