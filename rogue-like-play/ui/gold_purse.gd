class_name GoldPurse
extends VBoxContainer

# The hub's Gold, set straight on the hall instead of in a boxed card: a coin,
# the word Gold and the amount, over a gilt rule drawn like the lobby menu's
# rail (a double line with diamond studs), on a faint pool of shade that
# keeps it legible against the lantern-lit wall.

var value_label: Label
var _shade: GradientTexture2D


func _init() -> void:
	theme_type_variation = &"PurseStack"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := Gradient.new()
	fade.set_color(0, Color(0, 0, 0, 1))
	fade.set_color(1, Color(0, 0, 0, 0))
	_shade = GradientTexture2D.new()
	_shade.gradient = fade
	_shade.fill = GradientTexture2D.FILL_RADIAL
	_shade.fill_from = Vector2(0.5, 0.5)
	_shade.fill_to = Vector2(1.0, 0.5)
	_shade.changed.connect(queue_redraw)


func _ready() -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"PurseRow"
	row.alignment = BoxContainer.ALIGNMENT_END
	add_child(row)
	var coin := Control.new()
	coin.name = "Coin"
	coin.custom_minimum_size = Vector2(32, 32)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.draw.connect(_draw_coin.bind(coin))
	row.add_child(coin)
	var caption := HubUI.label(row, "Gold", &"PurseCaption")
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_label = HubUI.label(row, "", &"PurseValue")
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rule := Control.new()
	rule.custom_minimum_size.y = 12
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(_draw_rule.bind(rule))
	add_child(rule)


func _draw_coin(coin: Control) -> void:
	var gold := coin.get_theme_color(&"font_color", &"GoldLabel")
	var center := coin.size * 0.5
	var radius := minf(coin.size.x, coin.size.y) * 0.5 - 1.0
	coin.draw_circle(center, radius, gold.darkened(0.45))
	coin.draw_circle(center, radius - 2.5, gold)
	coin.draw_arc(center, radius - 5.0, 0, TAU, 24, gold.darkened(0.35), 1.5, true)
	coin.draw_circle(center + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.18, Color(1, 1, 1, 0.45))


func _draw() -> void:
	var shade := get_theme_color(&"purse_shade", &"HubLobby")
	draw_texture_rect(_shade, Rect2(Vector2(-60, -24), size + Vector2(90, 48)), false, shade)


# Bright under the amount, fading out to the left: a double line like the
# menu's rail, with a diamond stud at each end.
func _draw_rule(rule: Control) -> void:
	var rail := rule.get_theme_color(&"rail", &"HubLobby")
	var y := rule.size.y * 0.5
	var start := 34.0
	var end := rule.size.x - 8.0
	rule.draw_polyline_colors(PackedVector2Array([Vector2(start, y - 1.5), Vector2(end, y - 1.5)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.95)]), 1.5, true)
	rule.draw_polyline_colors(PackedVector2Array([Vector2(start + 40, y + 2.5), Vector2(end - 10, y + 2.5)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.4)]), 1.0, true)
	for stud: Vector2 in [Vector2(end + 3, y), Vector2(start + 60, y - 1.5)]:
		var radius := 5.0 if stud.x > start + 60 else 3.0
		rule.draw_colored_polygon(PackedVector2Array([stud + Vector2(0, -radius), stud + Vector2(radius, 0), stud + Vector2(0, radius), stud + Vector2(-radius, 0)]), Color(rail, 1.0 if radius > 4.0 else 0.55))
