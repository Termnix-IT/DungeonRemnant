class_name DungeonMenu
extends CanvasLayer

# The fight's menu (Esc, or Start on a gamepad): back to the fight, the
# settings, or leaving the run, and beside it, as action roguelites' pause
# screens commonly show, the run's build: each boon taken as a row with its
# emblem, name and rank, and what the pointed (or focused) one does under
# them. Left and right move between the menu and the build. The fight waits
# while it is open. The
# settings are the hub's own page (HubSettings) over the dimmed field, so a
# change made here is the same change, stored the same way, and takes effect
# at once. Leaving goes through the area's confirmation, which says what is
# kept. Esc (B) steps back one level: from the help to the settings, from
# the settings to the menu, from the menu to the fight.

signal resumed
signal abort_requested
signal settings_changed

const WIDTH := 460.0
const BUILD_WIDTH := 520.0
const EMBLEM_SIZE := 48.0
const SHADE := Color(0.01, 0.02, 0.03, 0.82)
# The settings read as a page of their own, as dark as the inventory's shade.
const SETTINGS_SHADE := Color(0.01, 0.02, 0.03, 0.94)
# The settings page stands where the hub puts it: rows from near the screen's
# left edge, between the title and the key guide.
const PAGE_RECT := Rect2(40, 110, 1480, 700)
const EDGE := Vector2(40, 22)

var settings: GameSettings
# The run whose build is shown beside the menu; none shows no build.
var run: RunState
var menu: Control
var build_panel: PanelContainer
var build_list: VBoxContainer
var build_note: Label
var _build_rows: Array[Button] = []
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
	var side_by_side := HBoxContainer.new()
	side_by_side.theme_type_variation = &"ListRow"
	menu.add_child(side_by_side)
	_build_build(side_by_side)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"QuietWindow"
	frame.custom_minimum_size.x = WIDTH
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side_by_side.add_child(frame)
	# The theme's margins keep the buttons inside the frame's ornaments.
	var margin := MarginContainer.new()
	frame.add_child(margin)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"DetailStack"
	margin.add_child(column)
	var title := HubUI.label(column, "メニュー", &"TitleLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HubUI.rule(column)
	resume_button = HubUI.button(column, "戦いに戻る", resume, &"PrimaryButton")
	settings_button = HubUI.button(column, "設定", open_settings)
	abort_button = HubUI.button(column, "ランを中断する", func(): abort_requested.emit())
	abort_button.tooltip_text = "中断の確認へ進む。持ち帰れるものはそこで確かめられる。"
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


# The run's build, as a framed list beside the menu.
func _build_build(parent: Control) -> void:
	build_panel = PanelContainer.new()
	build_panel.theme_type_variation = &"QuietWindow"
	build_panel.custom_minimum_size.x = BUILD_WIDTH
	parent.add_child(build_panel)
	var margin := MarginContainer.new()
	build_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"DetailStack"
	margin.add_child(column)
	var title := HubUI.label(column, "このランの強化", &"HeadingLabel")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	HubUI.rule(column)
	build_list = VBoxContainer.new()
	column.add_child(build_list)
	HubUI.rule(column)
	build_note = HubUI.label(column, "", &"DescriptionLabel")


func _show_build() -> void:
	build_panel.visible = run != null
	_build_rows.clear()
	for button: Button in [resume_button, settings_button, abort_button]:
		button.focus_neighbor_left = NodePath()
	if run == null:
		return
	for child in build_list.get_children():
		child.free()
	var owned := run.build.owned()
	build_note.text = "まだ強化を取っていない。レベルを上げるとカードから選べる。" if owned.is_empty() else ""
	for boon in owned:
		var rank := run.build.rank(boon.id)
		var row := HubUI.button(build_list, boon.display_name if boon.max_level == 1 else "%s　Lv %d / %d" % [boon.display_name, rank, boon.max_level], func(): pass)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.icon = EmblemIcons.texture(boon.emblem)
		row.expand_icon = true
		row.custom_minimum_size.y = EMBLEM_SIZE + 8.0
		var words := boon.effect_description(rank)
		row.focus_entered.connect(func(): build_note.text = words)
		row.mouse_entered.connect(func(): build_note.text = words)
		_build_rows.append(row)
	if _build_rows.is_empty():
		return
	build_note.text = owned[0].effect_description(run.build.rank(owned[0].id))
	for index in _build_rows.size():
		var row := _build_rows[index]
		row.focus_neighbor_top = _build_rows[posmod(index - 1, _build_rows.size())].get_path()
		row.focus_neighbor_bottom = _build_rows[posmod(index + 1, _build_rows.size())].get_path()
		row.focus_neighbor_right = resume_button.get_path()
		row.focus_neighbor_left = row.get_path()
	for button: Button in [resume_button, settings_button, abort_button]:
		button.focus_neighbor_left = _build_rows[0].get_path()
	UIMotion.bind_buttons(build_list)


func _build_settings() -> void:
	settings_view = Control.new()
	settings_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(settings_view)
	settings_title = HubUI.label(settings_view, "設定", &"TitleLabel")
	settings_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	settings_title.position = EDGE
	settings_page = HubSettings.new()
	settings_page.in_run = true
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
	_show_build()
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
		settings_guide.add_hint("Q / E", "LB / RB", "分類")
