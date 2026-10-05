class_name ItemDetails
extends RichTextLabel

# Lines added by line() are centred when set, for a column that stacks the
# item's art above its text (the warehouse's transfer column).
var centered := false
var _fit_gap: Control
var _fit_minimum := 0.0


func _init() -> void:
	theme_type_variation = &"ItemDetails"
	focus_mode = Control.FOCUS_ALL
	selection_enabled = true
	context_menu_enabled = false


# Keeps to its lines like fit_content while the column has spare height in
# gap (an expanding spacer beside it), then scrolls instead of pushing the
# actions below it off the page.
func fit_lines(gap: Control, minimum: float) -> void:
	fit_content = false
	scroll_active = true
	_fit_gap = gap
	_fit_minimum = minimum
	custom_minimum_size.y = minimum
	# Content height is known once laid out; the deferred check settles in
	# one step and stops when the height no longer changes.
	draw.connect(func(): _fit_height.call_deferred())
	gap.resized.connect(func(): _fit_height.call_deferred())


func _fit_height() -> void:
	if not is_visible_in_tree():
		return
	var wanted := maxf(_fit_minimum, get_content_height() + get_theme_stylebox(&"normal").get_minimum_size().y)
	# The height this box and the spacer share between them.
	var room := maxf(_fit_minimum, size.y + _fit_gap.size.y)
	var target := floorf(minf(wanted, room))
	if not is_equal_approx(custom_minimum_size.y, target):
		custom_minimum_size.y = target


func reset() -> void:
	clear()
	get_v_scroll_bar().value = 0


func line(value: String, role: StringName = &"BodyLabel") -> void:
	var color_role := role if has_theme_color(&"font_color", role) else &"Label"
	if centered:
		push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	push_color(get_theme_color(&"font_color", color_role))
	push_font_size(get_theme_font_size(&"font_size", role))
	# Item names/descriptions are plain text, never executable BBCode.
	add_text(value + "\n")
	pop()
	pop()
	if centered:
		pop()


# Only what the showcase does not already say. Its title always holds the full
# name and its effect line the main effect; without a showcase, name the item.
func item_text(item: ItemData, showcase: ItemShowcase = null, role: StringName = &"DescriptionLabel") -> void:
	if showcase == null:
		line(item.label(), &"MutedLabel")
	if item.description() != ItemGlyph.main_effect(item):
		line(item.description(), role)


# Changed values as aligned columns: caption, before, after, difference.
# Each row is [caption, before, after]; the difference takes the rise or fall
# colour so the change reads before the numbers do.
func stat_table(rows: Array) -> void:
	if rows.is_empty():
		return
	var muted := get_theme_color(&"font_color", &"MutedLabel")
	var body := get_theme_color(&"default_color")
	push_table(4)
	for row: Array in rows:
		var difference: int = row[2] - row[1]
		var tone := muted
		if difference > 0:
			tone = get_theme_color(&"font_color", &"PositiveLabel")
		elif difference < 0:
			tone = get_theme_color(&"decrease_color")
		for cell: Array in [[row[0], muted], ["%d" % row[1], muted], ["→  %d" % row[2], body], ["(%+d)" % difference, tone]]:
			push_cell()
			push_color(cell[1])
			add_text(cell[0] + "    ")
			pop()
			pop()
	pop()
	add_text("\n")


func delta(caption: String, before: int, after: int) -> void:
	var difference := after - before
	var color := get_theme_color(&"font_color", &"MutedLabel")
	if difference > 0:
		color = get_theme_color(&"font_color", &"PositiveLabel")
	elif difference < 0:
		color = get_theme_color(&"decrease_color")
	push_color(color)
	add_text("%s  %d → %d (%+d)\n" % [caption, before, after, difference])
	pop()
