class_name GameMusic
extends Node

# The game's music: one loop at a time on the Music bus (TRACKS: the base,
# the fights, the boss), crossfading when the scene's track changes, and
# muffled while the world waits on a choice or a menu (its highs cut by the
# bus's low-pass filter and a little quieter), as games commonly duck their
# music behind a pause. Main keeps the one instance; anything finds it with
# find(), and without one (a scene run on its own, a test) nothing plays.

const GROUP := &"game_music"
const BUS := &"Music"
const TRACKS := {
	&"hub": "res://audio/third_party/randommind_medieval_exploration/hub.ogg",
	&"battle": "res://audio/third_party/cynicmusic_battle_theme_a/battle.ogg",
	&"boss": "res://audio/third_party/juhani_junkala_epic_boss_battle/boss.ogg",
}
# The level a track plays at, and how far below it a track starts or ends.
const LEVEL_DB := -6.0
const SILENT_DB := -50.0
const FADE_TIME := 1.2
# Muffled: the low-pass filter's cutoff, and how much quieter it gets.
const OPEN_CUTOFF := 20500.0
const MUFFLE_CUTOFF := 850.0
const MUFFLE_DB := -5.0
const MUFFLE_TIME := 0.25

var track: StringName = &""
var muffled := false
var _players: Array[AudioStreamPlayer] = []
var _current := 0
var _fades: Array[Tween] = [null, null]
var _muffle_tween: Tween
var _muffle_db := 0.0


static func find(node: Node) -> GameMusic:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as GameMusic


# Plays `name` (a TRACKS key; empty fades out) where there is a player.
static func cue(node: Node, name: StringName) -> void:
	var music := find(node)
	if music != null:
		music.play(name)


static func muffle(node: Node, value: bool) -> void:
	var music := find(node)
	if music != null:
		music.set_muffled(value)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


func play(name: StringName) -> void:
	if name == track:
		return
	track = name
	_fade(_current, SILENT_DB, true)
	if name.is_empty() or not TRACKS.has(name):
		return
	_current = 1 - _current
	var player := _players[_current]
	var stream: AudioStream = load(TRACKS[name])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	player.stream = stream
	player.volume_db = SILENT_DB
	# Headless runs keep the state for tests but play nothing.
	if DisplayServer.get_name() != "headless":
		player.play()
	_fade(_current, LEVEL_DB, false)


func _fade(index: int, to_db: float, stop_after: bool) -> void:
	if _fades[index] != null:
		_fades[index].kill()
	var player := _players[index]
	var fade := create_tween()
	fade.tween_property(player, "volume_db", to_db + (_muffle_db if not stop_after else 0.0), FADE_TIME)
	if stop_after:
		fade.tween_callback(player.stop)
	_fades[index] = fade


func set_muffled(value: bool) -> void:
	if value == muffled:
		return
	muffled = value
	_muffle_db = MUFFLE_DB if value else 0.0
	var bus := AudioServer.get_bus_index(BUS)
	var filter := AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0 else null
	if _muffle_tween != null:
		_muffle_tween.kill()
	_muffle_tween = create_tween().set_parallel()
	if filter != null:
		_muffle_tween.tween_property(filter, "cutoff_hz", MUFFLE_CUTOFF if value else OPEN_CUTOFF, MUFFLE_TIME)
	if not track.is_empty():
		_muffle_tween.tween_property(_players[_current], "volume_db", LEVEL_DB + _muffle_db, MUFFLE_TIME)
