extends Control

# The departure's three redesign prototypes, side by side for comparison:
# F1 the shaft, F2 the vista, F3 the expedition chart. All three show the
# same departure (ProtoExpedition), kept in memory only: nothing reaches the
# save file, and setting out starts no run. Run it on its own:
#   godot --path . res://prototypes/sortie_redesign/proto_main.tscn

var model: ProtoExpedition
var screens: Array[ProtoScreen] = []
var shown := 0
var _switch: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	model = ProtoExpedition.new()
	for kind: Script in ProtoMain.kinds():
		var screen: ProtoScreen = kind.new(model)
		add_child(screen)
		screens.append(screen)
	_switch = Label.new()
	_switch.position = Vector2(620.0, 4.0)
	_switch.add_theme_font_size_override(&"font_size", 12)
	_switch.modulate = Color(1.0, 1.0, 1.0, 0.45)
	_switch.text = "F1 深層への縦坑　F2 一枚絵の門　F3 遠征図　F5 エンディング後"
	add_child(_switch)
	show_screen(0)


func show_screen(index: int) -> void:
	shown = index
	for at in screens.size():
		screens[at].visible = at == index
		screens[at].clock = 0.0
		screens[at]._kicks.clear()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode in [KEY_F1, KEY_F2, KEY_F3]:
		show_screen(mini(event.keycode - KEY_F1, screens.size() - 1))
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F5:
		# Past the ending and back: every chapter and four steps open.
		model.reset(model.steps_open() == 0)
		get_viewport().set_input_as_handled()
