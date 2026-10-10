extends CanvasLayer

const DISPLAY_TIME := 1.65
const WIDTH := 800.0
# The top of the one lane banners run in: the band at the screen's top edge
# (HUD.notice_lane_top()), set by the run before adding the banner. The band
# is one line, title and place side by side, so it stays off the floor round
# the hero.
var lane_top := 12.0

# A banner began or ended; the boss gauge, which shares the band, steps aside.
signal showing_changed(showing: bool)

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
	panel.offset_left = -WIDTH * 0.5
	panel.offset_right = WIDTH * 0.5
	panel.offset_top = lane_top
	var column := HBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.theme_type_variation = &"ShopColumns"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	title_label = Label.new()
	title_label.theme_type_variation = &"HeadingLabel"
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)
	# The place stands a little apart from the title on the one line.
	var gap := Control.new()
	gap.custom_minimum_size.x = 28
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	subtitle_label = Label.new()
	subtitle_label.theme_type_variation = &"MutedLabel"
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	showing_changed.emit(true)
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
	showing_changed.emit(false)
