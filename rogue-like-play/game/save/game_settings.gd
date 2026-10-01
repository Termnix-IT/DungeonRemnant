class_name GameSettings
extends RefCounted

# Player preferences that belong to this machine, not to the adventure:
# kept apart from progress.json so a blocked or restored progress save never
# touches them, and a broken settings file only falls back to the defaults.

const DISPLAY_NAMES: Array[String] = ["ウィンドウ", "全画面"]
# The first settings stored five volume steps; read them as their level.
const LEGACY_VOLUME_STEPS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]

var path := "user://settings.cfg"
# Master volume as a linear level from 0 (silent) to 1.
var volume := 1.0
var fullscreen := false


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	if file.has_section_key("audio", "volume"):
		volume = clampf(float(file.get_value("audio", "volume", volume)), 0.0, 1.0)
	elif file.has_section_key("audio", "volume_step"):
		var step := clampi(int(file.get_value("audio", "volume_step", 4)), 0, LEGACY_VOLUME_STEPS.size() - 1)
		volume = LEGACY_VOLUME_STEPS[step]
	fullscreen = bool(file.get_value("display", "fullscreen", fullscreen))


func save_settings() -> bool:
	var file := ConfigFile.new()
	file.set_value("audio", "volume", volume)
	file.set_value("display", "fullscreen", fullscreen)
	return file.save(path) == OK


func volume_percent() -> int:
	return roundi(volume * 100.0)


func apply_volume() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_linear(master, volume)
	AudioServer.set_bus_mute(master, volume <= 0.0)


# Headless runs have no window to change.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
