class_name RouteNode
extends Button

# One area on the route map, drawn as node maps in roguelites draw them: a
# round medallion showing what clearing it gives (a boon's light, a heart,
# an echo coin; the boss's skull), its kind and difficulty under it. Open
# (the layer to choose from now) it is bright and takes focus; taken, it
# keeps a gold ring; passed by or still ahead, it is dimmed. The selected
# node wears the gold ring and a soft glow, the focused one a light edge.

const SIZE := 76.0
const BOSS_SIZE := 104.0
const BACK := Color(0.05, 0.055, 0.065, 0.96)
const EDGE := Color(0.32, 0.32, 0.31)
const GOLD := Color("d6b77b")
const FOCUS := Color(0.94, 0.92, 0.86)
const GLOW := Color(1.0, 0.82, 0.48, 0.22)
# The emblem showing each reward, and the boss's.
const REWARD_EMBLEMS := {AreaData.Reward.BOON: "attack", AreaData.Reward.HEAL: "max_hp"}
const BOSS_EMBLEM := "kill_heal"
const PASSED := Color(1, 1, 1, 0.32)
const AHEAD := Color(1, 1, 1, 0.62)

enum Mark { OPEN, TAKEN, PASSED, AHEAD }

var waypoint: RouteMap.Waypoint
var mark := Mark.OPEN
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var _icon: Texture2D
var _caption: Label


# The boss's glow and how long one breath takes.
const BOSS_GLOW := Color(0.72, 0.16, 0.12, 0.32)
const BOSS_BEAT := 1.8


func setup(point: RouteMap.Waypoint, state: Mark) -> void:
	waypoint = point
	mark = state
	theme_type_variation = &"RouteNode"
	text = ""
	var boss := point.area.boss != null
	var across := BOSS_SIZE if boss else SIZE
	custom_minimum_size = Vector2(across, across)
	size = custom_minimum_size
	_icon = EmblemIcons.texture(BOSS_EMBLEM if boss else REWARD_EMBLEMS.get(point.reward, ""))
	tooltip_text = "%s\n%s　%s\n報酬：%s" % [point.area.display_name, point.area.kind_name(), point.area.stars(), AreaData.reward_name(point.reward)]
	focus_mode = Control.FOCUS_ALL if state == Mark.OPEN else Control.FOCUS_NONE
	modulate = {Mark.OPEN: Color.WHITE, Mark.TAKEN: Color.WHITE, Mark.PASSED: PASSED, Mark.AHEAD: AHEAD}[state]
	_caption = Label.new()
	_caption.theme_type_variation = &"MutedLabel" if state != Mark.OPEN else &"BodyLabel"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.text = "%s %s" % [point.area.kind_name(), point.area.stars()]
	add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.offset_top = 6
	_caption.offset_bottom = 30
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	set_process(boss)


# The boss's node breathes a red glow, slow, like a heartbeat ahead.
func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.5 - 4.0
	if waypoint != null and waypoint.area.boss != null:
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / BOSS_BEAT)
		draw_circle(center, radius + 8.0 + beat * 6.0, Color(BOSS_GLOW, BOSS_GLOW.a * (0.35 + 0.65 * beat)))
	if selected:
		draw_circle(center, radius + 12.0, GLOW)
	draw_circle(center, radius, BACK)
	if _icon != null:
		draw_texture_rect(_icon, Rect2(center - Vector2.ONE * radius * 0.86, Vector2.ONE * radius * 1.72), false)
	elif waypoint != null and waypoint.reward == AreaData.Reward.ECHO:
		_draw_coin(center, radius * 0.55)
	var gold_ring := selected or mark == Mark.TAKEN
	var edge := GOLD if gold_ring else EDGE
	if mark == Mark.OPEN and is_hovered() and not gold_ring:
		edge = GOLD.darkened(0.25)
	draw_arc(center, radius, 0.0, TAU, 48, edge, 3.0 if gold_ring else 2.0, true)
	if has_focus():
		draw_arc(center, radius + 5.0, 0.0, TAU, 48, FOCUS, 1.5, true)


# The echo's coin, as the hub's purse draws it.
func _draw_coin(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, GOLD.darkened(0.45))
	draw_circle(center, radius - 3.0, GOLD)
	draw_arc(center, radius - 7.0, 0, TAU, 32, GOLD.darkened(0.35), 2.0, true)
	draw_circle(center + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.18, Color(1, 1, 1, 0.45))
