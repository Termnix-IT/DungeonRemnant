class_name MetaUpgradePage
extends Control

# The lasting upgrades (MetaProgress.UPGRADES), side by side on the slab:
# each its emblem, name and words, its ranks as sockets, and the price of
# the next rank on its button, which asks to buy (buy_requested; the hub
# saves, then calls present_purchase). A full upgrade says so; one the echo
# cannot pay for shows its price, its button off. Echo itself is in the
# hub's header.

signal buy_requested(id: StringName)

const CARD_WIDTH := 360.0
const EMBLEM_SIZE := 120.0
const PIP_SIZE := 22.0

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
	var lead := HubUI.label(_slab, "ランで得た残響で、次のランからずっと続く強化を手に入れる。", &"NoteLabel")
	lead.autowrap_mode = TextServer.AUTOWRAP_OFF
	var row := HBoxContainer.new()
	row.theme_type_variation = &"ShopColumns"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slab.add_child(row)
	for upgrade in MetaProgress.UPGRADES:
		row.add_child(_card(upgrade))
	for index in buttons.size():
		buttons[index].focus_neighbor_left = buttons[posmod(index - 1, buttons.size())].get_path()
		buttons[index].focus_neighbor_right = buttons[posmod(index + 1, buttons.size())].get_path()
	UIMotion.bind_buttons(_slab)


func _card(upgrade: MetaUpgrade) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"InsetPanel"
	card.custom_minimum_size.x = CARD_WIDTH
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"DetailStack"
	card.add_child(stack)
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2.ONE * EMBLEM_SIZE
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(func(): EmblemIcons.paint(emblem, Rect2(Vector2.ZERO, emblem.size), upgrade.emblem))
	stack.add_child(emblem)
	var title := HubUI.label(stack, upgrade.display_name, &"HeadingLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pips := Control.new()
	pips.custom_minimum_size.y = PIP_SIZE
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(_draw_pips.bind(pips, upgrade))
	stack.add_child(pips)
	_pips.append(pips)
	var words := HubUI.label(stack, upgrade.description, &"DescriptionLabel")
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rank := HubUI.label(stack, "", &"MutedLabel")
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_labels.append(rank)
	var button := HubUI.button(stack, "", func(): buy_requested.emit(upgrade.id), &"PrimaryButton")
	button.custom_minimum_size.y = HubUI.PRIMARY_ACTION_HEIGHT
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
