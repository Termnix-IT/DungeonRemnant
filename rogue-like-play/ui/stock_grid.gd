class_name StockGrid
extends IconGrid

# One inventory shown as icons: its name and room, a row that filters its icons
# by kind and sorts them, and under that the grid of its goods (IconGrid; a
# row's index is the entry's index in the inventory).

const FILTERS: Array[String] = ["すべて", "武器", "防具", "装飾", "魔法", "道具"]
const SORTS: Array[String] = ["標準", "名前順", "種類順"]

var inventory: Inventory
var filter_index := 0
var sort_index := 0
var name_label: Label
var rule: HintMark
var count_label: Label
var filter_tabs: CategoryTabs
var sort_cycler: OptionCycler


func _init(title: String = "", rule_text: String = "") -> void:
	super()
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"CompactRow"
	add_child(heading)
	move_child(heading, 0)
	name_label = HubUI.label(heading, title, &"ItemNameLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if not rule_text.is_empty():
		rule = HintMark.make(heading, rule_text, HubSettings.TOPIC_PREPARATION)
	count_label = HubUI.label(heading, "", &"NoteLabel")
	count_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sort_cycler = OptionCycler.new()
	sort_cycler.custom_minimum_size = Vector2(150, 40)
	sort_cycler.tooltip_text = "並べ替え"
	heading.add_child(sort_cycler)
	sort_cycler.setup(SORTS)
	sort_cycler.item_selected.connect(func(index: int):
		sort_index = index
		_changed())
	filter_tabs = CategoryTabs.new()
	add_child(filter_tabs)
	move_child(filter_tabs, 1)
	filter_tabs.setup(FILTERS, false)
	filter_tabs.changed.connect(func(index: int):
		filter_index = index
		_changed())


func set_stock(stock: Inventory) -> void:
	inventory = stock
	var rows: Array[Dictionary] = []
	for index in stock.entries.size():
		var item := stock.entries[index].item
		if _passes_filter(item):
			rows.append({"index": index, "item": item, "count": stock.entries[index].count})
	_sort(rows)
	count_label.text = "%d / %d 枠" % [stock.entries.size(), stock.max_entries]
	show_rows(rows, "この種類の品はない" if not stock.entries.is_empty() else "")


func _passes_filter(item: ItemData) -> bool:
	match filter_index:
		1: return item.kind == ItemData.Kind.WEAPON
		2: return item.kind == ItemData.Kind.ARMOR
		3: return item.kind == ItemData.Kind.ACCESSORY
		4: return item.kind == ItemData.Kind.SCROLL
		5: return item.kind == ItemData.Kind.CONSUMABLE
	return true


# 標準 keeps the stock's own order; 名前順 and 種類順 reorder what is shown.
func _sort(rows: Array[Dictionary]) -> void:
	if sort_index == 1:
		rows.sort_custom(func(a: Dictionary, b: Dictionary): return a.item.label() < b.item.label())
	elif sort_index == 2:
		rows.sort_custom(func(a: Dictionary, b: Dictionary):
			var kind_a: String = ItemGlyph.category(a.item)
			var kind_b: String = ItemGlyph.category(b.item)
			return a.item.label() < b.item.label() if kind_a == kind_b else kind_a < kind_b)


func _changed() -> void:
	if inventory != null:
		set_stock(inventory)
