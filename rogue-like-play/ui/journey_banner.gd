extends CanvasLayer

const DISPLAY_TIME := 1.65

var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var lifetime: Timer


func _ready() -> void:
	layer = 7
	panel = PanelContainer.new()
	panel.theme = preload("res://ui/theme/dungeon_theme.tres")
	panel.theme_type_variation = &"InsetPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = 110
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	title_label = Label.new()
	title_label.theme_type_variation = &"HeadingLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.theme_type_variation = &"MutedLabel"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(subtitle_label)
	lifetime = Timer.new()
	lifetime.one_shot = true
	lifetime.timeout.connect(clear)
	add_child(lifetime)
	hide()


func present(title: String, subtitle: String = "") -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = not subtitle.is_empty()
	show()
	UIMotion.of(panel).reveal(UIMotion.WINDOW_TIME)
	UIMotion.of(title_label).pulse(1.025, UIMotion.WINDOW_TIME)
	lifetime.start(DISPLAY_TIME)


func clear() -> void:
	lifetime.stop()
	UIMotion.of(panel).reset()
	UIMotion.of(title_label).reset()
	hide()
