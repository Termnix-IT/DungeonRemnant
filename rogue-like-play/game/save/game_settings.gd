class_name GameSettings
extends RefCounted

# Player preferences that belong to this machine, not to the adventure:
# kept apart from progress.json so a blocked or restored progress save never
# touches them, and a broken settings file only falls back to the defaults.

const DISPLAY_NAMES: Array[String] = ["ウィンドウ", "全画面"]
# The buses of default_bus_layout.tres: GameAudio's cues and the dungeon's
# room tone, each under the master volume.
const EFFECTS_BUS := &"Effects"
const AMBIENCE_BUS := &"Ambience"
# How hard the camera shakes when she is hit, as a share of Run.SHAKE_STRENGTH.
const SHAKE_NAMES: Array[String] = ["標準", "弱め", "なし"]
const SHAKE_SCALES: Array[float] = [1.0, 0.5, 0.0]
# Whether the dungeon HUD shows the card of what can be done now (HudActions).
const CONTROLS_NAMES: Array[String] = ["ON", "OFF"]
# The first settings stored five volume steps; read them as their level.
const LEGACY_VOLUME_STEPS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]

var path := "user://settings.cfg"
# Master volume as a linear level from 0 (silent) to 1.
var volume := 1.0
var effects_volume := 1.0
var ambience_volume := 1.0
var fullscreen := false
# An index into SHAKE_NAMES.
var shake_level := 0
var show_controls := true


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	if file.has_section_key("audio", "volume"):
		volume = clampf(float(file.get_value("audio", "volume", volume)), 0.0, 1.0)
	elif file.has_section_key("audio", "volume_step"):
		var step := clampi(int(file.get_value("audio", "volume_step", 4)), 0, LEGACY_VOLUME_STEPS.size() - 1)
		volume = LEGACY_VOLUME_STEPS[step]
	effects_volume = clampf(float(file.get_value("audio", "effects", effects_volume)), 0.0, 1.0)
	ambience_volume = clampf(float(file.get_value("audio", "ambience", ambience_volume)), 0.0, 1.0)
	fullscreen = bool(file.get_value("display", "fullscreen", fullscreen))
	shake_level = clampi(int(file.get_value("display", "shake", shake_level)), 0, SHAKE_NAMES.size() - 1)
	show_controls = bool(file.get_value("display", "controls", show_controls))


func save_settings() -> bool:
	var file := ConfigFile.new()
	file.set_value("audio", "volume", volume)
	file.set_value("audio", "effects", effects_volume)
	file.set_value("audio", "ambience", ambience_volume)
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("display", "shake", shake_level)
	file.set_value("display", "controls", show_controls)
	return file.save(path) == OK


func volume_percent(level: float = volume) -> int:
	return roundi(level * 100.0)


func shake_scale() -> float:
	return SHAKE_SCALES[shake_level]


func apply_volume() -> void:
	for pair: Array in [[&"Master", volume], [EFFECTS_BUS, effects_volume], [AMBIENCE_BUS, ambience_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus < 0:
			continue
		AudioServer.set_bus_volume_linear(bus, pair[1])
		AudioServer.set_bus_mute(bus, pair[1] <= 0.0)


# Headless runs have no window to change.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
