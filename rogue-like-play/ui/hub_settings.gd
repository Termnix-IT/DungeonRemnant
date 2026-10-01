class_name HubSettings
extends Control

# The settings page, entered from the lobby like the other pages. Changes
# apply at once and are stored by GameSettings when the hub reports them.

signal changed

var volume_slider: GameSlider
var volume_value: Label
var display_cycler: OptionCycler
var settings: GameSettings


func _ready() -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"MainPanel"
	panel.custom_minimum_size.x = 860
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"SettingsMargin"
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.theme_type_variation = &"SettingsRows"
	margin.add_child(rows)
	var volume_row := _row(rows, "音量")
	_hint(volume_row, "← 小")
	volume_slider = GameSlider.new()
	volume_slider.name = "VolumeSlider"
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 5
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.tooltip_text = "音量"
	volume_row.add_child(volume_slider)
	_hint(volume_row, "大 →")
	volume_value = HubUI.label(volume_row, "", &"SettingsValue")
	volume_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	volume_value.custom_minimum_size.x = 72
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_slider.value_changed.connect(_volume_changed)
	_rule(rows)
	var display_row := _row(rows, "画面モード")
	display_cycler = OptionCycler.new()
	display_cycler.name = "DisplayCycler"
	display_cycler.custom_minimum_size = Vector2(300, 52)
	display_cycler.tooltip_text = "画面モード"
	display_row.add_child(display_cycler)
	display_cycler.setup(GameSettings.DISPLAY_NAMES)
	display_cycler.item_selected.connect(func(index: int):
		settings.fullscreen = index == 1
		settings.apply_display()
		changed.emit())
	volume_slider.focus_neighbor_bottom = display_cycler.get_path()
	display_cycler.focus_neighbor_top = volume_slider.get_path()


func _row(parent: Node, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"SettingsRow"
	parent.add_child(row)
	var label := HubUI.label(row, caption, &"HeadingLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = 180
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


func _hint(row: HBoxContainer, text: String) -> void:
	var hint := HubUI.label(row, text, &"MutedLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# A thin gilt rule between the rows, fading at both ends.
func _rule(parent: Node) -> void:
	var rule := Control.new()
	rule.custom_minimum_size.y = 9
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func():
		var color := rule.get_theme_color(&"rail", &"HubLobby")
		var y := rule.size.y * 0.5
		rule.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(rule.size.x * 0.5, y), Vector2(rule.size.x, y)]), PackedColorArray([Color(color, 0.0), Color(color, 0.45), Color(color, 0.0)]), 1.0, true))
	parent.add_child(rule)


func refresh(value: GameSettings) -> void:
	settings = value
	volume_slider.set_value_no_signal(settings.volume_percent())
	volume_slider.queue_redraw()
	volume_value.text = "%d%%" % settings.volume_percent()
	display_cycler.select(1 if settings.fullscreen else 0)


func focus_first() -> void:
	volume_slider.grab_focus()


func _volume_changed(percent: float) -> void:
	settings.volume = percent / 100.0
	settings.apply_volume()
	volume_value.text = "%d%%" % settings.volume_percent()
	changed.emit()
