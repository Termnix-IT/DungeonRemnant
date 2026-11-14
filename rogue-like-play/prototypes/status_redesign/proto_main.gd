extends Control

# The status page's three redesign prototypes, side by side for comparison:
# F1 the armoury, F2 the grimoire, F3 the altar. All three show the same
# build (ProtoBuild), kept in memory only, so equipping in one shows in the
# others and nothing reaches the save file. Run it on its own:
#   godot --path . res://prototypes/status_redesign/proto_main.tscn

var build: ProtoBuild
var screens: Array[ProtoScreen] = []
var shown := 0
var _switch: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	build = ProtoBuild.new()
	for kind: Script in ProtoMain.kinds():
		var screen: ProtoScreen = kind.new(build)
		add_child(screen)
		screens.append(screen)
	_switch = Label.new()
	_switch.position = Vector2(1180.0, 4.0)
	_switch.add_theme_font_size_override(&"font_size", 12)
	_switch.modulate = Color(1.0, 1.0, 1.0, 0.45)
	_switch.text = "F1 武具庫　F2 魔導書　F3 祭壇"
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


func _exit_tree() -> void:
	build.free_teller()
