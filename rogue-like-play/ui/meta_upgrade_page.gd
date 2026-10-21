class_name MetaUpgradePage
extends Control

# The lasting upgrades (MetaProgress.UPGRADES) as an upgrade shop's list, the
# common form: one row each across the slab, its emblem, its name and what
# it does, its ranks as sockets with the count under them, and at the row's
# end the price of the next rank on its button, which asks to buy
# (buy_requested; the hub saves, then calls present_purchase). A full
# upgrade says so; one the echo cannot pay for shows its price, its button
# off. The rows are walked with the up and down keys. Echo itself is in the
# hub's header.

signal buy_requested(id: StringName)

const EMBLEM_SIZE := 88.0
const PIP_SIZE := 22.0
const RANK_WIDTH := 170.0
const BUTTON_WIDTH := 280.0
const LIST_WIDTH := 1180.0

var meta: MetaProgress
var buttons: Array[Button] = []
var rank_labels: Array[Label] = []
var _cards: Array[Control] = []
var _pips: Array[Control] = []
var _slab: VBoxContainer


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slab = HubUI.open_column(columns, 1.0, &"SlabSolid")
	var list := VBoxContainer.new()
	list.theme_type_variation = &"RowList"
	list.custom_minimum_size.x = LIST_WIDTH
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slab.add_child(list)
	for upgrade in MetaProgress.UPGRADES:
		list.add_child(_row(upgrade))
	for index in buttons.size():
		buttons[index].focus_neighbor_top = buttons[posmod(index - 1, buttons.size())].get_path()
		buttons[index].focus_neighbor_bottom = buttons[posmod(index + 1, buttons.size())].get_path()
		buttons[index].focus_neighbor_left = buttons[index].get_path()
		buttons[index].focus_neighbor_right = buttons[index].get_path()
	UIMotion.bind_buttons(_slab)


func _row(upgrade: MetaUpgrade) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"InsetPanel"
	var row := HBoxContainer.new()
	row.theme_type_variation = &"ListRow"
	card.add_child(row)
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2.ONE * EMBLEM_SIZE
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(func(): EmblemIcons.paint(emblem, Rect2(Vector2.ZERO, emblem.size), upgrade.emblem))
	row.add_child(emblem)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	HubUI.label(words, upgrade.display_name, &"HeadingLabel").autowrap_mode = TextServer.AUTOWRAP_OFF
	HubUI.label(words, upgrade.description, &"DescriptionLabel")
	var ranks := VBoxContainer.new()
	ranks.custom_minimum_size.x = RANK_WIDTH
	ranks.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(ranks)
	var pips := Control.new()
	pips.custom_minimum_size.y = PIP_SIZE
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(_draw_pips.bind(pips, upgrade))
	ranks.add_child(pips)
	_pips.append(pips)
	var rank := HubUI.label(ranks, "", &"MutedLabel")
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank.autowrap_mode = TextServer.AUTOWRAP_OFF
	rank_labels.append(rank)
	var button := HubUI.button(row, "", func(): buy_requested.emit(upgrade.id), &"PrimaryButton")
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, HubUI.PRIMARY_ACTION_HEIGHT)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.append(button)
	_cards.append(card)
	return card


func refresh(current: MetaProgress) -> void:
	meta = current
	for index in MetaProgress.UPGRADES.size():
		var upgrade := MetaProgress.UPGRADES[index]
		var rank := meta.rank(upgrade.id)
		var price := upgrade.price(rank)
		rank_labels[index].text = "段階 %d / %d" % [rank, upgrade.max_rank()]
		var button := buttons[index]
		if price < 0:
			button.text = "習得済み"
			button.disabled = true
		else:
			button.text = "残響 %s で%s" % [UIFormat.amount(price), "習得" if rank == 0 else "強化"]
			button.disabled = meta.echo < price
		button.tooltip_text = "" if price < 0 or meta.echo >= price else "残響が%s足りない" % UIFormat.amount(price - meta.echo)
		_pips[index].queue_redraw()


# After a purchase has been saved: the card's moment.
func present_purchase(id: StringName) -> void:
	for index in MetaProgress.UPGRADES.size():
		if MetaProgress.UPGRADES[index].id == id:
			UIMotion.of(_cards[index]).pulse(1.03, UIMotion.GOLD_TIME)
			UIMotion.of(rank_labels[index]).reveal()


func focus_first() -> void:
	for button in buttons:
		if not button.disabled:
			button.grab_focus()
			return
	if not buttons.is_empty():
		buttons[0].grab_focus()


func play_entrance() -> void:
	UIMotion.of(_slab).appear(0.0, UIMotion.WINDOW_TIME)


func _draw_pips(canvas: Control, upgrade: MetaUpgrade) -> void:
	var empty := get_theme_icon(&"pip_empty", &"AbilityCard")
	var full := get_theme_icon(&"pip_full", &"AbilityCard")
	var count := upgrade.max_rank()
	var held := meta.rank(upgrade.id) if meta != null else 0
	var width := PIP_SIZE * full.get_width() / full.get_height()
	var gap := 4.0
	var start := (canvas.size.x - width * count - gap * (count - 1)) * 0.5
	for index in count:
		var rect := Rect2(start + index * (width + gap), 0, width, PIP_SIZE)
		canvas.draw_texture_rect(empty, rect, false)
		if index < held:
			canvas.draw_texture_rect(full, rect, false)
