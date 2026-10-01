class_name GoldPurse
extends VBoxContainer

# The hub's Gold, set straight on the hall instead of in a boxed card: a coin,
# the word Gold and the amount, over a thin gilt rule.

var value_label: Label


func _init() -> void:
	theme_type_variation = &"PurseStack"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"PurseRow"
	row.alignment = BoxContainer.ALIGNMENT_END
	add_child(row)
	var coin := Control.new()
	coin.name = "Coin"
	coin.custom_minimum_size = Vector2(26, 26)
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
	rule.custom_minimum_size.y = 9
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


# Bright under the amount, fading out to the left, with a stud at the end.
func _draw_rule(rule: Control) -> void:
	var rail := rule.get_theme_color(&"rail", &"HubLobby")
	var y := rule.size.y * 0.5
	rule.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(rule.size.x - 8, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.85)]), 1.0, true)
	var stud := Vector2(rule.size.x - 4, y)
	rule.draw_colored_polygon(PackedVector2Array([stud + Vector2(0, -4), stud + Vector2(4, 0), stud + Vector2(0, 4), stud + Vector2(-4, 0)]), rail)
