class_name HudWeapon
extends HBoxContainer

# The weapon in hand on the vitals plate: its icon in a gold slot box, the
# caption and name, the range the attack really reaches, and the other weapon
# as a small dim icon beside the Tab key that swaps them. Sizes and spacing
# live in the Theme type HudWeapon; the name uses HudWeaponName.
const CAPTION := "主武器"
const EMPTY := "—"

var main_glyph: WeaponGlyph
var sub_glyph: WeaponGlyph
var caption_label: Label
var name_label: Label
var range_label: Label
var hint: KeyGuide


func _init() -> void:
	theme_type_variation = &"HudWeapon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Icons are 2x pixel art drawn below their size, so sample whole pixels.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	main_glyph = WeaponGlyph.new(&"glyph_size", true)
	main_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(main_glyph)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(text)
	var title := HBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	caption_label = _label(title, &"HudCaption", CAPTION)
	name_label = _label(title, &"HudWeaponName", EMPTY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	range_label = _label(text, &"HudSmall", "")
	sub_glyph = WeaponGlyph.new(&"sub_glyph_size", false)
	sub_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(sub_glyph)
	hint = KeyGuide.new()
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(hint)


# A key cap reads its style when added, so it waits until the Theme reaches it.
func _ready() -> void:
	hint.add_hint("Tab", "Y", "切替")


func _label(parent: Control, role: StringName, value: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = role
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


# attack is the weapon the attack code uses for main (Player.effective_weapon),
# so the range already includes upgrades and a socketed spell.
func show_weapons(main: ItemData, sub: ItemData, attack: WeaponData) -> void:
	name_label.text = main.label() if main != null else EMPTY
	range_label.text = range_text(attack) if main != null else "射程 %s" % EMPTY
	main_glyph.item = main
	sub_glyph.item = sub
	main_glyph.queue_redraw()
	sub_glyph.queue_redraw()
	tooltip_text = "%s：%s\n副武器：%s" % [CAPTION, name_label.text, sub.label() if sub != null else EMPTY]


# A healing spell lands on the hero herself, so it has no distance to show.
static func range_text(attack: WeaponData) -> String:
	if attack == null:
		return "射程 %s" % EMPTY
	if attack.spell_heal > 0:
		return "射程 自身"
	return "射程 %d" % attack.reach


# One weapon's slot box: the item's icon, or the faint symbol of an empty
# weapon slot. The main box has the gold rim of the equipment screens; the
# other weapon is drawn dim.
class WeaponGlyph:
	extends Control

	var item: ItemData
	var size_constant: StringName
	var main: bool

	func _init(constant: StringName, is_main: bool) -> void:
		size_constant = constant
		main = is_main
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		return Vector2.ONE * get_theme_constant(size_constant, &"HudWeapon")

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED:
			update_minimum_size()

	func _draw() -> void:
		var muted := get_theme_color(&"font_color", &"HudCaption")
		var box := Rect2(Vector2.ZERO, size)
		var glyph := box.grow(-2)
		draw_rect(box, Color(0, 0, 0, 0.35))
		var rim := get_theme_color(&"font_color", &"GoldLabel") if main and item != null else Color(muted, 0.35)
		draw_rect(box, rim, false, 1.0)
		if item == null:
			ItemGlyph.paint(self, glyph.grow(-glyph.size.x * 0.2), ItemGlyph.slot_symbol(Equipment.Slot.MAIN if main else Equipment.Slot.SUB), Color(muted, 0.45))
		elif main:
			ItemGlyph.paint(self, glyph, item, get_theme_color(&"font_color", &"Label"))
		else:
			ItemGlyph.paint(self, glyph, item, Color(muted, 0.85))
