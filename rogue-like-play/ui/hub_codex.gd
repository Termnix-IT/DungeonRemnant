class_name HubCodex
extends Control

# The item encyclopedia, laid out like the shop: every item the game has as
# icons with their names, three to a row and filtered by the same category
# tabs, on the slab from the left edge, and the focused one's art, name, kind,
# main effect and description in the column on the right. An item counts as
# found once it has been held (RunCarryover.has_discovered); the others show
# as dark outlines named "？？？", their kind alone told, so the list says how
# much is still to find without saying what. Nothing here changes the state.

const SHOWCASE_SIZE := 120.0
const GRID_COLUMNS := 3
const CELL_WIDTH := 320.0
const CELL_SIZE := 72.0
const CELL_ICON := 48.0
const UNKNOWN_NAME := "？？？"
const UNKNOWN_NOTE := "まだ見つけていない品。冒険で拾うか、ショップで買うと記録される。"

var state: RunCarryover
var category_tabs: CategoryTabs
var count_label: Label
var grid: IconGrid
var showcase: ItemShowcase
var details: ItemDetails
# The rows shown, in the grid's order: {item, count, index, unknown}.
var rows: Array[Dictionary] = []
var _catalog: VBoxContainer
var _info: VBoxContainer


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catalog = HubUI.open_column(columns, 2.1, &"SlabSolid")
	category_tabs = CategoryTabs.new()
	_catalog.add_child(category_tabs)
	category_tabs.setup(HubSell.CATEGORIES)
	category_tabs.changed.connect(func(_index: int):
		_show_items()
		focus_first())
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
	HubUI.rule(_info)
	details = ItemDetails.new()
	details.fit_content = true
	_info.add_child(details)
	HubUI.space(_info)


func refresh(current: RunCarryover) -> void:
	state = current
	_show_items()


func _show_items() -> void:
	if state == null:
		return
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
	grid.show_rows(rows)
	if not rows.is_empty():
		grid.choose(0)
		_select(0, false)


func _select(place: int, animate: bool = true) -> void:
	if place < 0 or place >= rows.size():
		return
	var row := rows[place]
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


func selected_item() -> ItemData:
	var place := grid.entries.find_custom(func(row: Dictionary): return row.index == grid.selected)
	return rows[place].item if place >= 0 else null


func focus_first() -> void:
	if not grid.cells.is_empty():
		grid.cells[0].grab_focus()


func step_category(direction: int) -> void:
	category_tabs.step(direction)


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
	var back: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q) or (pad and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER)
	var next: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E) or (pad and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER)
	if back or next:
		step_category(-1 if back else 1)
		get_viewport().set_input_as_handled()
