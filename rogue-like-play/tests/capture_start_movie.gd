extends SceneTree

# The way from starting the game to the three gates played through once,
# for a film of it: the game's opening, the lobby and its menu, the
# departure and its chapters, setting out, and the hall of gates opening.
# The game is the real Main with saving off, driven by the same actions the
# keys send, on a fixed seed and a save where the second chapter is open.
# Run under the movie writer, which also records the sound, and turn the
# result into a film with ffmpeg:
#   godot --path . --rendering-method gl_compatibility --resolution 1280x720 --fixed-fps 60 --write-movie .godot/start_movie.avi --script res://tests/capture_start_movie.gd
#   ffmpeg -y -i .godot/start_movie.avi -c:v libx264 -pix_fmt yuv420p -crf 21 -c:a aac .godot/start_movie.mp4

# How long the lobby is left to come in after the opening has gone on to
# it by itself.
const ARRIVAL := 1.8

var main: Node


func _initialize() -> void:
	call_deferred("play")


func play() -> void:
	TranslationServer.set_locale("ja")
	main = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.saving_enabled = false
	main.run_seed = 6
	main.meta.echo = 240
	main.meta.ranks["echo_lantern"] = 1
	main.meta.ranks["sturdy_body"] = 1
	main.meta.runs = 3
	main.meta.best_layer = 3
	main.meta.chapter_best[&"ash_corridor"] = 3
	main.meta.chapter_clears[&"ash_corridor"] = 1
	main.meta.met[&"wandering_sentinel"] = true
	main.meta.met[&"dashing_rat"] = true
	main.meta.met[&"ruin_king"] = true
	root.add_child(main)
	main.get_node("Hub").refresh(main.meta)
	await _wait(HubOpening.AUTO_AT + ARRIVAL)
	# The lobby: down the menu and back up to the departure.
	for action: StringName in [&"ui_down", &"ui_down", &"ui_down", &"ui_up", &"ui_up", &"ui_up"]:
		await _press(action, 0.55)
	await _wait(0.8)
	# Into the departure, round its chapters, and out.
	await _press(&"ui_accept", 2.2)
	await _press(&"ui_right", 1.6)
	await _press(&"ui_left", 1.6)
	await _press(&"ui_accept", 6.5)
	quit()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


# An action pressed and let go, as a key sends it, and a wait after it.
func _press(action: StringName, then: float) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _wait(then)
