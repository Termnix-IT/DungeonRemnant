class_name DungeonMenu
extends CanvasLayer

# The fight's menu (Esc, or Start on a gamepad): one window holding, as
# survivor-likes' pause screens commonly do, the run's build on the left and
# the menu (back to the fight, the settings, or leaving the run) on the
# right. The build is a grid of the boons taken, each its emblem in a round
# socket with its rank at the lower right as the HUD shows it, so it fits
# however many are taken; under the grid, the pointed (or focused) boon's
# name, rank and what it does. Left and right move between the grid and the
# menu. The fight waits while it is open. The
# settings are the hub's own page (HubSettings) over the dimmed field, so a
# change made here is the same change, stored the same way, and takes effect
# at once. Leaving goes through the area's confirmation, which says what is
# kept. Esc (B) steps back one level: from the help to the settings, from
# the settings to the menu, from the menu to the fight.

signal resumed
signal abort_requested
signal settings_changed

# The menu's column.
const WIDTH := 300.0
# The build's grid: emblems this wide, this many to a row (all 32 boons fit
# in six rows).
const EMBLEM_SIZE := 56.0
const BUILD_COLUMNS := 6
# The boon's account under the grid keeps room for this many lines, so the
# window does not change height as the focus moves.
const NOTE_LINES := 2
const EMPTY_NOTE := "レベルアップで選んだ強化が、ここに並ぶ"
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
# The build's column, its grid of boons and the chosen boon's account.
var build_panel: VBoxContainer
var build_grid: GridContainer
var build_name: Label
var build_rank: Label
var build_note: Label
var _build_cells: Array[EquipSocket] = []
var _build_rule: Control
var _column_rule: Control
var resume_button: JustifiedButton
var settings_button: JustifiedButton
var abort_button: JustifiedButton
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
	frame.theme_type_variation = &"QuietWindow"
	menu.add_child(frame)
	# The theme's margins keep the contents inside the frame's ornaments.
	var margin := MarginContainer.new()
	frame.add_child(margin)
	var side_by_side := HBoxContainer.new()
	side_by_side.theme_type_variation = &"ListRow"
	margin.add_child(side_by_side)
	_build_build(side_by_side)
	_column_rule = HubUI.column_rule(side_by_side, 16.0)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"DetailStack"
	column.custom_minimum_size.x = WIDTH
	side_by_side.add_child(column)
	# The column keeps one axis: the heading, the buttons and the keys all
	# stand on its centre, as the rule's diamond does.
	var title := HubUI.label(column, "メニュー", &"HeadingLabel")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HubUI.rule(column)
	resume_button = _menu_button(column, "戦いに戻る", resume, &"PrimaryButton")
	settings_button = _menu_button(column, "設定", open_settings, &"SecondaryButton")
	abort_button = _menu_button(column, "探索を中断する", func(): abort_requested.emit(), &"SecondaryButton")
	var buttons: Array[Button] = [resume_button, settings_button, abort_button]
	# The three words spread to the longest one's width, so they read as one
	# even block down the column's centre.
	JustifiedButton.align_spans(buttons)
	for index in buttons.size():
		buttons[index].focus_neighbor_top = buttons[(index + buttons.size() - 1) % buttons.size()].get_path()
		buttons[index].focus_neighbor_bottom = buttons[(index + 1) % buttons.size()].get_path()
	# The keys stand at the column's foot, level with the boon's account.
	HubUI.space(column)
	var guide := KeyGuide.new()
	guide.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(guide)
	guide.add_hint("Enter", "A", "決定")
	guide.add_hint("Esc", "B", "戻る", back)
	UIMotion.bind_buttons(column)


# One of the menu's buttons, its words spread (JustifiedButton).
func _menu_button(parent: Node, words: String, action: Callable, role: StringName) -> JustifiedButton:
	var button := JustifiedButton.new()
	button.caption = words
	button.theme_type_variation = role
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button


# The run's build, the window's left column: the grid of boons, and the
# chosen one's account under it.
func _build_build(parent: Control) -> void:
	build_panel = VBoxContainer.new()
	build_panel.theme_type_variation = &"DetailStack"
	parent.add_child(build_panel)
	# The heading and the grid stand on the column's centre, as the menu's
	# do; the boon's account under them, being running text, keeps to the
	# left.
	var title := HubUI.label(build_panel, "この探索の強化", &"HeadingLabel")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HubUI.rule(build_panel)
	build_grid = GridContainer.new()
	build_grid.theme_type_variation = &"CodexGrid"
	build_grid.columns = BUILD_COLUMNS
	build_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	build_panel.add_child(build_grid)
	# As wide as a full row, however few boons are taken.
	var cell := EMBLEM_SIZE + 2.0 * (EquipSocket.RING_GAP + EquipSocket.RING_WIDTH)
	build_panel.custom_minimum_size.x = BUILD_COLUMNS * cell + (BUILD_COLUMNS - 1) * build_grid.get_theme_constant(&"h_separation")
	_build_rule = HubUI.rule(build_panel)
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"HudTallyRow"
	build_panel.add_child(heading)
	build_name = HubUI.label(heading, "", &"ItemNameLabel")
	build_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	build_rank = HubUI.label(heading, "", &"MutedLabel")
	build_rank.autowrap_mode = TextServer.AUTOWRAP_OFF
	build_rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	build_note = HubUI.label(build_panel, "", &"DescriptionLabel")
	var font := build_note.get_theme_font(&"font")
	var font_size := build_note.get_theme_font_size(&"font_size")
	build_note.custom_minimum_size.y = NOTE_LINES * font.get_height(font_size)


func _show_build() -> void:
	build_panel.visible = run != null
	_column_rule.visible = run != null
	_build_cells.clear()
	for button: Button in [resume_button, settings_button, abort_button]:
		button.focus_neighbor_left = NodePath()
	if run == null:
		return
	for child in build_grid.get_children():
		child.free()
	var owned := run.build.owned()
	build_grid.visible = not owned.is_empty()
	_build_rule.visible = not owned.is_empty()
	build_name.get_parent().visible = not owned.is_empty()
	build_note.text = EMPTY_NOTE
	# The one line said while the build is empty stands under the heading;
	# a boon's account, running text, keeps to the left.
	build_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if owned.is_empty() else HORIZONTAL_ALIGNMENT_LEFT
	for boon in owned:
		var rank := run.build.rank(boon.id)
		var cell := EquipSocket.new(EMBLEM_SIZE, false, true)
		cell.emblem = EmblemIcons.texture(boon.emblem)
		cell.tooltip_text = boon.display_name
		build_grid.add_child(cell)
		if boon.max_level > 1:
			# The rank at the emblem's lower right, as the HUD's row shows it.
			var digit := HubUI.label(cell, str(rank), &"HudCaption")
			digit.autowrap_mode = TextServer.AUTOWRAP_OFF
			digit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			digit.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			digit.grow_vertical = Control.GROW_DIRECTION_BEGIN
		cell.focus_entered.connect(_tell.bind(boon, rank, cell))
		cell.mouse_entered.connect(_tell.bind(boon, rank, cell))
		_build_cells.append(cell)
	if _build_cells.is_empty():
		return
	for index in _build_cells.size():
		var cell := _build_cells[index]
		var column := index % BUILD_COLUMNS
		var last := _build_cells.size() - 1
		cell.focus_neighbor_left = _build_cells[index - 1].get_path() if column > 0 else cell.get_path()
		cell.focus_neighbor_right = _build_cells[index + 1].get_path() if column < BUILD_COLUMNS - 1 and index < last else resume_button.get_path()
		cell.focus_neighbor_top = _build_cells[index - BUILD_COLUMNS].get_path() if index >= BUILD_COLUMNS else cell.get_path()
		# Down from a row over a shorter last row lands on its last boon.
		var below := index + BUILD_COLUMNS
		if below > last and index / BUILD_COLUMNS < last / BUILD_COLUMNS:
			below = last
		cell.focus_neighbor_bottom = _build_cells[below].get_path() if below <= last else cell.get_path()
	_tell(owned[0], run.build.rank(owned[0].id), _build_cells[0])


# The boon's name, rank and what it does, under the grid; its socket keeps a
# quiet gold ring while the focus is on the menu, and the menu's way left
# returns to it.
func _tell(boon: BoonData, rank: int, cell: EquipSocket) -> void:
	for other in _build_cells:
		other.lit = other == cell
	build_name.text = boon.display_name
	build_rank.text = "" if boon.max_level == 1 else "Lv %d / %d" % [rank, boon.max_level]
	build_note.text = boon.effect_description(rank)
	for button: Button in [resume_button, settings_button, abort_button]:
		button.focus_neighbor_left = cell.get_path()


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
	settings_page.help_close_requested.connect(back)
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
