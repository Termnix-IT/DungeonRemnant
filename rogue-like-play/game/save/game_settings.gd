class_name GameSettings
extends RefCounted

# Player preferences that belong to this machine, not to the adventure:
# kept apart from progress.json so a blocked or restored progress save never
# touches them, and a broken settings file only falls back to the defaults.

const VOLUME_STEPS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const VOLUME_NAMES: Array[String] = ["消音", "小", "中", "大", "最大"]

var path := "user://settings.cfg"
var volume_step := 4
var fullscreen := false


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	volume_step = clampi(int(file.get_value("audio", "volume_step", volume_step)), 0, VOLUME_STEPS.size() - 1)
	fullscreen = bool(file.get_value("display", "fullscreen", fullscreen))


func save_settings() -> bool:
	var file := ConfigFile.new()
	file.set_value("audio", "volume_step", volume_step)
	file.set_value("display", "fullscreen", fullscreen)
	return file.save(path) == OK


func apply_volume() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_linear(master, VOLUME_STEPS[volume_step])
	AudioServer.set_bus_mute(master, volume_step == 0)


# Headless runs have no window to change.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
