class_name HubSettings
extends Control

# The settings page, in the shared grammar: the settings as open rows on a
# slab from the screen's left edge that melts into the hall at its right,
# as tall as they are and level with the
# middle of the screen, the focused row on the lobby's warm band (sliding
# between rows) and what it does under them. Changes apply at once and are
# stored by GameSettings when the hub reports them, so the page holds no
# primary action.

signal changed

const ROW_HEIGHT := 92.0
const BAND_TIP := 18.0
# The band starts at the screen's left edge, as the lobby menu's does.
const EDGE_REACH := 40.0
const NOTES := ["効果音と環境音の大きさ。左右キーかドラッグで5%ずつ変える。0%で消音。", "ウィンドウと全画面を切り替える。左右キーか矢印を押して選ぶ。"]

var volume_slider: GameSlider
var volume_value: Label
var display_cycler: OptionCycler
var settings: GameSettings
var rows: VBoxContainer
var note: Label
var focused_row := 0
var _rows: Array[Control] = []


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left := HubUI.open_column(columns, 1.5, &"SlabBand")
	left.theme_type_variation = &"DetailStack"
	# Two settings make a band, not a full-height column of empty slab.
	(left.get_parent() as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	HubUI.label(left, "変更はその場で反映され、自動で保存される。", &"NoteLabel")
	rows = VBoxContainer.new()
	rows.theme_type_variation = &"SettingsRows"
	left.add_child(rows)
	UIMotion.of(rows)
	rows.draw.connect(_draw_rows)
	var volume_row := _row("音量")
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
	volume_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.value_changed.connect(_volume_changed)
	var display_row := _row("画面モード")
	display_cycler = OptionCycler.new()
	display_cycler.name = "DisplayCycler"
	display_cycler.custom_minimum_size = Vector2(300, 52)
	display_cycler.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	display_cycler.tooltip_text = "画面モード"
	display_row.add_child(display_cycler)
	display_cycler.setup(GameSettings.DISPLAY_NAMES)
	display_cycler.item_selected.connect(func(index: int):
		settings.fullscreen = index == 1
		settings.apply_display()
		changed.emit())
	volume_slider.focus_neighbor_bottom = display_cycler.get_path()
	display_cycler.focus_neighbor_top = volume_slider.get_path()
	for index in 2:
		var control: Control = [volume_slider, display_cycler][index]
		control.focus_entered.connect(_focus_row.bind(index))
	HubUI.rule(left)
	note = HubUI.label(left, NOTES[0], &"NoteLabel")
	# The hall stays open on the right, as beside the lobby menu.
	var hall := Control.new()
	hall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(hall)


func _row(caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"SettingsRow"
	row.custom_minimum_size.y = ROW_HEIGHT
	rows.add_child(row)
	_rows.append(row)
	var label := HubUI.label(row, caption, &"ItemNameLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = 150
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


func _hint(row: HBoxContainer, text: String) -> void:
	var hint := HubUI.label(row, text, &"NoteLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# The focused row stands on the lobby's warm band, pointing right at the
# note; the others are parted by faint rules.
func _draw_rows() -> void:
	var rail := rows.get_theme_color(&"rail", &"HubLobby")
	var band := rows.get_theme_color(&"band", &"HubLobby")
	var chosen := _rows[focused_row]
	var rect := UIMotion.of(rows).follow_mark(Rect2(chosen.position + Vector2(-EDGE_REACH, 4), chosen.size + Vector2(EDGE_REACH + BAND_TIP, -8)))
	var tip := rect.end.x
	var middle := rect.get_center().y
	var outline := PackedVector2Array([rect.position, Vector2(tip - BAND_TIP, rect.position.y), Vector2(tip, middle), Vector2(tip - BAND_TIP, rect.end.y), Vector2(rect.position.x, rect.end.y)])
	rows.draw_polygon(outline, PackedColorArray([Color(band, band.a * 0.5), Color(band, band.a * 1.6), Color(band, band.a * 1.8), Color(band, band.a * 1.6), Color(band, band.a * 0.5)]))
	rows.draw_polyline_colors(outline, PackedColorArray([Color(rail, 0.0), Color(rail, 0.85), rail, Color(rail, 0.85), Color(rail, 0.0)]), 1.5, true)
	for index in _rows.size() - 1:
		if index == focused_row or index + 1 == focused_row:
			continue
		var y := _rows[index].position.y + _rows[index].size.y
		rows.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(rows.size.x * 0.5, y), Vector2(rows.size.x, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.22), Color(rail, 0.0)]), 1.0, true)


func _focus_row(index: int) -> void:
	focused_row = index
	note.text = NOTES[index]
	rows.queue_redraw()
	UIMotion.reveal_selection([note])


func refresh(value: GameSettings) -> void:
	settings = value
	volume_slider.set_value_no_signal(settings.volume_percent())
	volume_slider.queue_redraw()
	volume_value.text = "%d%%" % settings.volume_percent()
	display_cycler.select(1 if settings.fullscreen else 0)


func focus_first() -> void:
	volume_slider.grab_focus()
	_focus_row(0)


# Opening the page: the rows arrive top first, the note a beat later.
func play_entrance() -> void:
	for index in _rows.size():
		UIMotion.of(_rows[index]).appear(UIMotion.ROW_STAGGER * index, UIMotion.ROW_TIME)
	UIMotion.of(note).appear(UIMotion.STAGGER_TIME)


func _volume_changed(percent: float) -> void:
	settings.volume = percent / 100.0
	settings.apply_volume()
	volume_value.text = "%d%%" % settings.volume_percent()
	changed.emit()
