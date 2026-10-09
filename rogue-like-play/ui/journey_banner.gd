extends CanvasLayer

const DISPLAY_TIME := 1.65
# The top of the one lane banners run in. The run sets it below the boss
# gauge's area (HUD.notice_lane_top()) before adding the banner.
var lane_top := 112.0

var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var lifetime: Timer
# Cues that arrived while another was showing, shown one after another
# instead of over each other: {title, subtitle}.
var queue: Array[Dictionary] = []


func _ready() -> void:
	layer = 7
	panel = PanelContainer.new()
	panel.theme = preload("res://ui/theme/dungeon_theme.tres")
	panel.theme_type_variation = &"BannerBand"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = lane_top
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	title_label = Label.new()
	title_label.theme_type_variation = &"TitleLabel"
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
	lifetime.timeout.connect(_advance)
	add_child(lifetime)
	hide()


# delay holds the entrance while something covers the screen (a floor change).
# A cue that arrives while another is showing waits for it to finish.
func present(title: String, subtitle: String = "", delay: float = 0.0) -> void:
	if showing():
		if title != title_label.text and not queue.any(func(cue: Dictionary) -> bool: return cue.title == title):
			queue.append({"title": title, "subtitle": subtitle})
		return
	_show(title, subtitle, delay)


func showing() -> bool:
	return visible and not lifetime.is_stopped()


# Whether title is on screen now or waiting its turn.
func announces(title: String) -> bool:
	return (showing() and title_label.text == title) or queue.any(func(cue: Dictionary) -> bool: return cue.title == title)


func _show(title: String, subtitle: String, delay: float) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = not subtitle.is_empty()
	show()
	UIMotion.of(panel).enter(delay)
	if delay <= 0.0:
		UIMotion.of(title_label).pulse(1.025, UIMotion.WINDOW_TIME)
	lifetime.start(DISPLAY_TIME + delay)


func _advance() -> void:
	if queue.is_empty():
		clear()
		return
	var next: Dictionary = queue.pop_front()
	UIMotion.of(panel).reset()
	UIMotion.of(title_label).reset()
	_show(next.title, next.subtitle, 0.0)


# Drops the cue on screen and any waiting ones.
func clear() -> void:
	queue.clear()
	lifetime.stop()
	UIMotion.of(panel).reset()
	UIMotion.of(title_label).reset()
	hide()
