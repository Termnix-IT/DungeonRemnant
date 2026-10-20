class_name HubCodex
extends Control

# The encyclopedia, laid out like the shop, in two books the header's tabs
# switch between (mode_tabs, or R): items and monsters. Each lists every entry
# with its name, three to a row and filtered by category tabs, on the slab
# from the left edge, and the focused one's picture and account in the column
# on the right. An item counts as found once it has been held
# (RunCarryover.has_discovered), a monster once it has been seen
# (RunCarryover.has_met); the others show as dark shapes named "？？？",
# their kind alone told, so the list says how much is still to find without
# saying what. Nothing here changes the state.

signal mode_changed

const SHOWCASE_SIZE := 120.0
const PORTRAIT_SIZE := 160.0
const GRID_COLUMNS := 3
const CELL_WIDTH := 320.0
const CELL_SIZE := 72.0
const CELL_ICON := 48.0
const UNKNOWN_NAME := "？？？"
const UNKNOWN_NOTE := "まだ見つけていない品。冒険で拾うか、ショップで買うと記録される。"
const UNKNOWN_MONSTER_NOTE := "まだ出会っていない魔物。視界に入ると記録される。"
const MONSTER_CATEGORIES: Array[String] = ["すべて", "敵", "ボス"]

var state: RunCarryover
var mode_tabs: HBoxContainer
var items_tab: Button
var monsters_tab: Button
var monsters := false
var category_tabs: CategoryTabs
var monster_tabs: CategoryTabs
var count_label: Label
var grid: IconGrid
var showcase: ItemShowcase
var details: ItemDetails
var monster_view: VBoxContainer
var monster_picture: Control
var monster_name: Label
var monster_kind: Label
var monster_stats: Label
var monster_details: ItemDetails
# The rows shown, in the grid's order: items {item, index, unknown, ...};
# monsters {entry, portrait, index, unknown, ...}.
var rows: Array[Dictionary] = []
var _catalog: VBoxContainer
var _info: VBoxContainer
var _item_view: Array[Control] = []
var _picture := {}
var _picture_unknown := false


func _ready() -> void:
	_build_mode_tabs()
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catalog = HubUI.open_column(columns, 2.1, &"SlabSolid")
	category_tabs = CategoryTabs.new()
	_catalog.add_child(category_tabs)
	category_tabs.setup(HubSell.CATEGORIES)
	category_tabs.changed.connect(_category_changed)
	monster_tabs = CategoryTabs.new()
	_catalog.add_child(monster_tabs)
	monster_tabs.setup(MONSTER_CATEGORIES)
	monster_tabs.changed.connect(_category_changed)
	count_label = HubUI.label(_catalog, "", &"NoteLabel")
	grid = IconGrid.new()
	grid.columns = GRID_COLUMNS
	grid.cell_size = CELL_SIZE
	grid.cell_width = CELL_WIDTH
	grid.icon_size = CELL_ICON
	grid.choose_on_focus = true
	_catalog.add_child(grid)
	grid.chosen.connect(_select)
	_info = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	_info.theme_type_variation = &"DetailStack"
	showcase = ItemShowcase.new()
	showcase.visual.framed = false
	showcase.visual.idle = true
	showcase.visual.custom_minimum_size = Vector2.ONE * SHOWCASE_SIZE
	_info.add_child(showcase)
	var item_rule := HubUI.rule(_info)
	details = ItemDetails.new()
	details.fit_content = true
	_info.add_child(details)
	_item_view = [showcase, item_rule, details]
	_build_monster_view()
	HubUI.space(_info)
	_show_mode()


# Two title-sized tabs the hub shows in its header in place of the title.
func _build_mode_tabs() -> void:
	mode_tabs = HBoxContainer.new()
	mode_tabs.theme_type_variation = &"ModeTabs"
	TabUnderline.attach(mode_tabs)
	var group := ButtonGroup.new()
	items_tab = HubUI.button(mode_tabs, "アイテム", set_monsters.bind(false), &"ModeTab")
	monsters_tab = HubUI.button(mode_tabs, "魔物", set_monsters.bind(true), &"ModeTab")
	for tab in [items_tab, monsters_tab]:
		tab.custom_minimum_size.y = 0
		tab.toggle_mode = true
		tab.button_group = group
	items_tab.button_pressed = true


# The monster's picture standing on a glow, its name, kind and figures, then
# how it fights and where it is met.
func _build_monster_view() -> void:
	monster_view = VBoxContainer.new()
	monster_view.theme_type_variation = &"DetailStack"
	_info.add_child(monster_view)
	monster_picture = Control.new()
	monster_picture.custom_minimum_size = Vector2.ONE * PORTRAIT_SIZE
	monster_picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	monster_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monster_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	monster_picture.draw.connect(_draw_monster_picture)
	monster_view.add_child(monster_picture)
	monster_name = HubUI.label(monster_view, "", &"HeadingLabel")
	monster_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	monster_kind = HubUI.label(monster_view, "", &"MutedLabel")
	monster_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	monster_stats = HubUI.label(monster_view, "", &"BodyLabel")
	monster_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HubUI.rule(monster_view)
	monster_details = ItemDetails.new()
	monster_details.fit_content = true
	monster_view.add_child(monster_details)


func refresh(current: RunCarryover) -> void:
	state = current
	_show_rows()


func set_monsters(value: bool) -> void:
	monsters = value
	_show_mode()
	_show_rows()
	focus_first()
	mode_changed.emit()


func _show_mode() -> void:
	items_tab.set_pressed_no_signal(not monsters)
	monsters_tab.set_pressed_no_signal(monsters)
	category_tabs.visible = not monsters
	monster_tabs.visible = monsters
	for control in _item_view:
		control.visible = not monsters
	monster_view.visible = monsters


func _category_changed(_index: int) -> void:
	_show_rows()
	focus_first()


func _show_rows() -> void:
	if state == null:
		return
	if monsters:
		_show_monsters()
	else:
		_show_items()
	grid.show_rows(rows)
	if not rows.is_empty():
		grid.choose(0)
		_select(0, false)


func _show_items() -> void:
	var kind: int = HubSell.CATEGORY_KINDS[category_tabs.selected]
	var all := ItemCatalog.all_items()
	var found := 0
	rows.clear()
	for item in all:
		var known := state.has_discovered(item)
		if known:
			found += 1
		if kind >= 0 and item.kind != kind:
			continue
		if not known:
			# Made here, not while a cell draws.
			ItemIcons.silhouette(item)
		var row := {"item": item, "count": 1, "index": rows.size(), "badge": 1, "unknown": not known}
		row.caption = item.label() if known else UNKNOWN_NAME
		row.note = ItemGlyph.category(item)
		row.tooltip = ItemTooltipList.description(item) if known else UNKNOWN_NOTE
		rows.append(row)
	count_label.text = "見つけた品  %d / %d" % [found, all.size()]


func _show_monsters() -> void:
	var all := EnemyCatalog.entries()
	var met := 0
	rows.clear()
	for entry in all:
		var known := state.has_met(entry.id)
		if known:
			met += 1
		if (monster_tabs.selected == 1 and entry.boss) or (monster_tabs.selected == 2 and not entry.boss):
			continue
		var stats: EnemyStats = entry.stats
		var row := {"item": null, "entry": entry, "count": 1, "index": rows.size(), "badge": 1, "unknown": not known, "portrait": EnemySprites.portrait(stats)}
		row.caption = stats.display_name if known else UNKNOWN_NAME
		row.note = entry.where if entry.boss else "敵"
		row.tooltip = stats.display_name if known else UNKNOWN_MONSTER_NOTE
		rows.append(row)
	count_label.text = "出会った魔物  %d / %d" % [met, all.size()]


func _select(place: int, animate: bool = true) -> void:
	if place < 0 or place >= rows.size():
		return
	var row := rows[place]
	if monsters:
		_present_monster(row)
		if animate:
			UIMotion.reveal_selection([monster_view])
		return
	var item: ItemData = row.item
	showcase.present(item)
	showcase.visual.unknown = row.unknown
	details.reset()
	if row.unknown:
		showcase.title.text = UNKNOWN_NAME
		showcase.effect.text = ""
		details.line(UNKNOWN_NOTE, &"NoteLabel")
	else:
		details.item_text(item, showcase)
	if animate:
		UIMotion.reveal_selection([showcase, details])


func _present_monster(row: Dictionary) -> void:
	var entry: Dictionary = row.entry
	var stats: EnemyStats = entry.stats
	_picture = row.portrait
	_picture_unknown = row.unknown
	monster_picture.queue_redraw()
	monster_details.reset()
	monster_kind.text = ("ボス・" if entry.boss else "敵・") + entry.where
	if row.unknown:
		monster_name.text = UNKNOWN_NAME
		monster_stats.text = ""
		monster_details.line(UNKNOWN_MONSTER_NOTE, &"NoteLabel")
		return
	monster_name.text = stats.display_name
	# Floor enemies grow stronger deeper down; their figures are the first floor's.
	monster_stats.text = "HP %d　攻撃 %d　防御 %d%s" % [stats.max_hp, stats.attack, stats.defense, "" if entry.boss else "（1階）"]
	monster_details.line(EnemyCatalog.traits(stats), &"DescriptionLabel")


func _draw_monster_picture() -> void:
	if _picture.is_empty():
		return
	var region: Rect2 = _picture.region
	var extent := minf(monster_picture.size.x, monster_picture.size.y)
	var fit := extent / maxf(region.size.x, region.size.y)
	var drawn := region.size * fit
	var area := Rect2(Vector2((monster_picture.size.x - drawn.x) * 0.5, monster_picture.size.y - drawn.y), drawn)
	monster_picture.draw_texture_rect_region(_picture.texture, area, region, Color(0.0, 0.0, 0.0, 0.85) if _picture_unknown else Color.WHITE)


func selected_item() -> ItemData:
	var place := grid.entries.find_custom(func(row: Dictionary): return row.index == grid.selected)
	return rows[place].item if place >= 0 else null


func focus_first() -> void:
	if not grid.cells.is_empty():
		grid.cells[0].grab_focus()


func step_category(direction: int) -> void:
	(monster_tabs if monsters else category_tabs).step(direction)


# Opening the page: the list first, the column a beat later.
func play_entrance() -> void:
	UIMotion.of(_catalog).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(_info).appear(UIMotion.STAGGER_TIME)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var pad := event is InputEventJoypadButton
	if pad or event is InputEventKey:
		category_tabs.use_pad(pad)
		monster_tabs.use_pad(pad)
	var back: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q) or (pad and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER)
	var next: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E) or (pad and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER)
	var swap: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R) or (pad and event.pressed and event.button_index == JOY_BUTTON_Y)
	if back or next:
		step_category(-1 if back else 1)
		get_viewport().set_input_as_handled()
	elif swap:
		set_monsters(not monsters)
		get_viewport().set_input_as_handled()
