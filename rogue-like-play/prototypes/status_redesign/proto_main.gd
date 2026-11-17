extends Control

# The status page's three redesign prototypes, side by side for comparison:
# F1 the orbits, F2 the four pillars, F3 the stargazer's glass. All three
# show the same status (ProtoStatus, which asks the shipped page's own
# rules), kept in memory only: nothing reaches the save file. Run it on its
# own:
#   godot --path . res://prototypes/status_redesign/proto_main.tscn

var model: ProtoStatus
var screens: Array[ProtoScreen] = []
var shown := 0
var _switch: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The shipped page, out of sight: the prototypes read what it works out.
	var page := HubStatus.new()
	page.theme = preload("res://ui/theme/dungeon_theme.tres")
	page.hide()
	add_child(page)
	model = ProtoStatus.new(page)
	for kind: Script in ProtoMain.kinds():
		var screen: ProtoScreen = kind.new(model)
		add_child(screen)
		screens.append(screen)
	_switch = Label.new()
	_switch.position = Vector2(620.0, 4.0)
	_switch.add_theme_font_size_override(&"font_size", 12)
	_switch.modulate = Color(1.0, 1.0, 1.0, 0.45)
	_switch.text = "F1 軌道　F2 四本の柱　F3 星見の鏡"
	add_child(_switch)
	show_screen(0)


func show_screen(index: int) -> void:
	shown = index
	for at in screens.size():
		screens[at].visible = at == index
		screens[at].clock = 0.0
		screens[at]._kicks.clear()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F1, KEY_F2, KEY_F3]:
		show_screen(mini(event.keycode - KEY_F1, screens.size() - 1))
		get_viewport().set_input_as_handled()
