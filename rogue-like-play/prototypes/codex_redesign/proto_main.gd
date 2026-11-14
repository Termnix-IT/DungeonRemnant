extends Control

# The bestiary's three redesign prototypes, side by side for comparison:
# F1 the ledger, F2 the plates, F3 the altar. All three show the same record
# (ProtoCodex), kept in memory only: nothing reaches the save file. Run it
# on its own:
#   godot --path . res://prototypes/codex_redesign/proto_main.tscn

var codex: ProtoCodex
var screens: Array[ProtoScreen] = []
var shown := 0
var _switch: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	codex = ProtoCodex.new()
	for kind: Script in ProtoMain.kinds():
		var screen: ProtoScreen = kind.new(codex)
		add_child(screen)
		screens.append(screen)
	_switch = Label.new()
	_switch.position = Vector2(1180.0, 4.0)
	_switch.add_theme_font_size_override(&"font_size", 12)
	_switch.modulate = Color(1.0, 1.0, 1.0, 0.45)
	_switch.text = "F1 調査台帳　F2 魔物図譜　F3 追憶の祭壇"
	_switch.visible = not OS.has_feature("capture")
	add_child(_switch)
	show_screen(0)


func show_screen(index: int) -> void:
	shown = index
	for at in screens.size():
		screens[at].visible = at == index
		screens[at].clock = 0.0


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F1, KEY_F2, KEY_F3]:
		show_screen(mini(event.keycode - KEY_F1, screens.size() - 1))
		get_viewport().set_input_as_handled()

