class_name MagicPicker
extends CanvasLayer

# Choosing a staff's spell from the staff's side. The spells at hand are large
# cards (the scroll's art, the spell's name, what it does, its MP cost and
# where it is kept); the one the staff already holds is marked and cannot be
# chosen again. Picking a card is the decision, so it needs no second prompt;
# taking the spell out is the lesser action. Esc or B leaves. Shared by the
# hub's equipment page and the dungeon's inventory, which apply the choice
# their own way (a key per card, given back by `chosen`).

signal chosen(key: Variant)
signal removed
signal canceled

const CARD_SIZE := Vector2(220, 268)
# The card's frame ornaments sit in this margin, clear of the text.
const CARD_INSET := 18.0
const CARD_ICON := 72.0
const COLUMNS := 3

var panel: PanelContainer
var title_label: Label
var current_label: Label
var cards_box: GridContainer
var empty_label: Label
var remove_button: Button
var cancel_button: Button
var key_guide: KeyGuide
var cards: Array[Button] = []
var keys: Array = []


func _ready() -> void:
	layer = 13
	var root := Control.new()
	root.theme = preload("res://ui/theme/dungeon_theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.01, 0.02, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.theme_type_variation = &"PromptPanel"
	panel.custom_minimum_size.x = 820
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"DetailStack"
	panel.add_child(column)
	title_label = HubUI.label(column, "", &"TitleLabel")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_label = HubUI.label(column, "", &"PlaqueNote")
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HubUI.rule(column)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	cards_box = GridContainer.new()
	cards_box.columns = COLUMNS
	cards_box.theme_type_variation = &"GearGrid"
	holder.add_child(cards_box)
	empty_label = HubUI.label(column, "魔法の巻物を持っていない。巻物はショップで買えるほか、まれに敵が落とす。", &"NoteLabel")
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(actions)
	remove_button = HubUI.button(actions, "魔法を外す", func(): removed.emit())
	remove_button.custom_minimum_size.x = 200
	remove_button.tooltip_text = "外した巻物は所持品に戻る"
	cancel_button = HubUI.button(actions, "やめる", func(): canceled.emit())
	cancel_button.custom_minimum_size.x = 200
	key_guide = KeyGuide.new()
	key_guide.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(key_guide)
	key_guide.add_hint("Enter", "A", "込める")
	key_guide.add_hint("Esc", "B", "戻る")
	UIMotion.bind_buttons(actions)
	hide()


# title names the staff ("主武器の杖に魔法を込める"); current is the spell the
# staff holds or null; choices are {key, item, count, place} for each scroll
# at hand, one card each.
func open(title: String, current: ItemData, choices: Array[Dictionary]) -> void:
	title_label.text = title
	current_label.text = "今の魔法：%s" % (current.weapon.display_name if current != null else "なし")
	for card in cards:
		card.get_parent().remove_child(card)
		card.queue_free()
	cards.clear()
	keys.clear()
	for choice: Dictionary in choices:
		var held: bool = current != null and choice.item.id == current.id
		cards.append(_card(choice, held))
		keys.append(choice.key)
	cards_box.visible = not cards.is_empty()
	empty_label.visible = cards.is_empty()
	remove_button.visible = current != null
	show()
	UIMotion.of(panel).appear(0.0, UIMotion.WINDOW_TIME)
	for index in cards.size():
		UIMotion.of(cards[index]).appear(index * UIMotion.STAGGER_TIME)
	var first := cards.filter(func(card: Button) -> bool: return not card.disabled)
	if not first.is_empty():
		(first[0] as Button).grab_focus()
	elif remove_button.visible:
		remove_button.grab_focus()
	else:
		cancel_button.grab_focus()


func _card(choice: Dictionary, held: bool) -> Button:
	var item: ItemData = choice.item
	var card := Button.new()
	card.theme_type_variation = &"HomeCard"
	card.custom_minimum_size = CARD_SIZE
	card.disabled = held
	card.tooltip_text = ItemTooltipList.description(item)
	cards_box.add_child(card)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(CARD_INSET))
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2.ONE * CARD_ICON
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(func():
		var color := icon.get_theme_color(&"font_color", &"Label")
		ItemGlyph.paint(icon, Rect2(Vector2.ZERO, icon.size), item, color if not held else Color(color, 0.45)))
	stack.add_child(icon)
	var name_label := HubUI.label(stack, item.weapon.display_name, &"HeadingLabel")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var effect := HubUI.label(stack, effect_text(item), &"DescriptionLabel")
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cost := HubUI.label(stack, "消費MP %d" % item.weapon.mana_cost, &"ValueLabel")
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var place := "込めている" if held else ("%s　×%d" % [choice.place, choice.count] if int(choice.count) > 1 else String(choice.place))
	var place_label := HubUI.label(stack, place, &"GoldLabel" if held else &"MutedLabel")
	place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var at := cards.size()
	card.pressed.connect(func(): chosen.emit(keys[at]))
	return card


# What the spell does, without the cost (shown on its own line).
static func effect_text(scroll: ItemData) -> String:
	var spell := scroll.weapon
	if spell.spell_heal > 0:
		return "HPを%d回復" % spell.spell_heal
	return "射程%d・補正%+d" % [spell.reach, spell.damage_bonus]


# Escape and the gamepad cancel button leave.
func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	var cancel := InputMap.has_action("cancel_attack") and event.is_action_pressed("cancel_attack")
	if cancel or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
