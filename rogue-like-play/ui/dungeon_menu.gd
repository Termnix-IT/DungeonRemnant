class_name DungeonMenu
extends CanvasLayer

# The dungeon's menu (Esc, or Start on a gamepad): back to the floor, the
# settings, or leaving the run. The run waits while it is open. The settings
# are the hub's own page (HubSettings) over the dimmed floor, so a change made
# here is the same change, stored the same way, and takes effect at once.
# Leaving goes through the run's abort confirmation, which says what is lost.
# Esc (B) steps back one level: from the help to the settings, from the
# settings to the menu, from the menu to the floor.

signal resumed
signal abort_requested
signal settings_changed

const WIDTH := 460.0
const SHADE := Color(0.01, 0.02, 0.03, 0.82)
# The settings read as a page of their own, as dark as the inventory's shade.
const SETTINGS_SHADE := Color(0.01, 0.02, 0.03, 0.94)
# The settings page stands where the hub puts it: rows from near the screen's
# left edge, between the title and the key guide.
const PAGE_RECT := Rect2(40, 110, 1480, 700)
const EDGE := Vector2(40, 22)

var settings: GameSettings
var menu: Control
var resume_button: Button
var settings_button: Button
var abort_button: Button
var settings_view: Control
var settings_page: HubSettings
var settings_guide: KeyGuide
var settings_title: Label
var _root: Control
var _shade: ColorRect


func _init() -> void:
	layer = 9


func _ready() -> void:
	_root = Control.new()
	_root.theme = preload("res://ui/theme/dungeon_theme.tres")
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_shade = ColorRect.new()
	_shade.color = SHADE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_shade)
	_build_menu()
	_build_settings()
	hide()


func _build_menu() -> void:
	menu = CenterContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(menu)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"MainPanel"
	frame.custom_minimum_size.x = WIDTH
	menu.add_child(frame)
	# The theme's margins keep the buttons inside the frame's ornaments.
	var margin := MarginContainer.new()
	frame.add_child(margin)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"DetailStack"
	margin.add_child(column)
	var title := HubUI.label(column, "メニュー", &"TitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HubUI.rule(column)
	resume_button = HubUI.button(column, "探索に戻る", resume, &"PrimaryButton")
	settings_button = HubUI.button(column, "設定", open_settings)
	abort_button = HubUI.button(column, "冒険を中断する", func(): abort_requested.emit())
	abort_button.tooltip_text = "中断の確認へ進む。失うものはそこで確かめられる。"
	var buttons: Array[Button] = [resume_button, settings_button, abort_button]
	for index in buttons.size():
		buttons[index].focus_neighbor_top = buttons[(index + buttons.size() - 1) % buttons.size()].get_path()
		buttons[index].focus_neighbor_bottom = buttons[(index + 1) % buttons.size()].get_path()
	var guide := KeyGuide.new()
	guide.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(guide)
	guide.add_hint("Enter", "A", "決定")
	guide.add_hint("Esc", "B", "戻る", back)
	UIMotion.bind_buttons(column)


func _build_settings() -> void:
	settings_view = Control.new()
	settings_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(settings_view)
	settings_title = HubUI.label(settings_view, "設定", &"TitleLabel")
	settings_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	settings_title.position = EDGE
	settings_page = HubSettings.new()
	settings_page.position = PAGE_RECT.position
	settings_page.size = PAGE_RECT.size
	settings_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_view.add_child(settings_page)
	settings_page.changed.connect(func(): settings_changed.emit())
	settings_page.help_opened.connect(_settings_hints)
	settings_guide = KeyGuide.new()
	settings_view.add_child(settings_guide)
	settings_guide.position = Vector2(EDGE.x, 900 - EDGE.y - 40)
	_settings_hints()
	settings_view.hide()


func open() -> void:
	_shade.color = SHADE
	settings_view.hide()
	menu.show()
	show()
	resume_button.grab_focus()
	UIMotion.of(menu).appear(0.0, UIMotion.WINDOW_TIME)


func resume() -> void:
	settings_page.release_focus()
	hide()
	resumed.emit()


func open_settings() -> void:
	_shade.color = SETTINGS_SHADE
	menu.hide()
	settings_view.show()
	settings_page.refresh(settings)
	settings_page.focus_first()
	settings_page.play_entrance()
	_settings_hints()


func showing_settings() -> bool:
	return visible and settings_view.visible


# One level back: the help, then the settings, then the menu itself.
func back() -> void:
	if not visible:
		return
	if settings_view.visible:
		if settings_page.help_shown:
			settings_page.close_help()
			_settings_hints()
			return
		settings_view.hide()
		_shade.color = SHADE
		menu.show()
		settings_button.grab_focus()
		return
	resume()


# The hub's settings keys, behind the way back.
func _settings_hints() -> void:
	settings_title.text = "ヘルプ" if settings_page.help_shown else "設定"
	settings_guide.clear_hints(0)
	settings_guide.add_hint("Esc", "B", "戻る", back)
	settings_guide.add_hint("↑ / ↓", "▲ / ▼", "項目")
	if not settings_page.help_shown:
		settings_guide.add_hint("← / →", "◀ / ▶", "変更")
