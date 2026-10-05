class_name InkTooltip
extends RefCounted

# Hover hints in the lobby's ink-wash family, matching the heroine's speech
# bubble without its tail, instead of the theme's boxed tooltip. Controls
# opt in by being made from the classes below; other tooltips (item lists,
# long descriptions) keep the shared TooltipPanel.


static func build(text: String) -> Control:
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"InkTooltip"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The ink is drawn at its painted height; only its middle stretches.
	var ink := plate.get_theme_stylebox(&"panel", &"InkTooltip") as StyleBoxTexture
	plate.custom_minimum_size.y = ink.texture.get_height()
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"InkTooltipLabel"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(label)
	# The popup around it would draw the shared tooltip box; clear it so only
	# the ink shows.
	plate.tree_entered.connect(func():
		var popup := plate.get_parent()
		if popup is PopupPanel:
			popup.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
			popup.transparent_bg = true)
	return plate


class HintButton extends Button:
	func _make_custom_tooltip(for_text: String) -> Object:
		return InkTooltip.build(for_text)


class HintLabel extends Label:
	func _make_custom_tooltip(for_text: String) -> Object:
		return InkTooltip.build(for_text)
