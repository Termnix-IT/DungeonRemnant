extends Control

# The route map's three redesign prototypes, side by side for comparison:
# F1 the expedition chart, F2 the three gates, F3 the war table. All three
# show the same run (ProtoRoute: a real chapter's route from a fixed seed,
# two areas in) and save nothing. A pick gone ahead with moves the run on a
# layer, so each can be played through to the boss and round again.
# Run it on its own:
#   godot --path . res://prototypes/route_redesign/proto_main.tscn

var model: ProtoRoute
var screens: Array[ProtoScreen] = []
var shown := 0
var _switch: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	model = ProtoRoute.new()
	for kind: Script in ProtoMain.kinds():
		var screen: ProtoScreen = kind.new(model)
		add_child(screen)
		screens.append(screen)
	_switch = Label.new()
	_switch.position = Vector2(620.0, 2.0)
	_switch.add_theme_font_size_override(&"font_size", 12)
	_switch.modulate = Color(1.0, 1.0, 1.0, 0.45)
	_switch.text = "F1 遠征図　F2 三つの門　F3 作戦盤"
	add_child(_switch)
	show_screen(0)


func show_screen(index: int) -> void:
	shown = index
	for at in screens.size():
		screens[at].visible = at == index
	screens[index].clock = 0.0
	screens[index].pose(&"initial")
	screens[index].opened()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F1, KEY_F2, KEY_F3]:
		show_screen(mini(event.keycode - KEY_F1, screens.size() - 1))
		get_viewport().set_input_as_handled()
