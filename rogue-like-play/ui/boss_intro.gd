class_name BossIntro
extends CanvasLayer

# A boss hall's opening, staged the way action games stage one. It is the
# start of the fight, not something that happens a while into it: the area
# (BattleArea) stops the world before the hall's first frame and keeps it
# stopped until `finished`, so nothing moves, nothing is taken and no key
# does anything in between. With the world stopped this plays, on its own
# clock:
#
#   she is seen where she stands as black bars slide in at the top and
#   bottom and the fight's HUD goes;
#   the view leaves her and travels up the hall to where the boss will
#   stand, closing in as it goes, while its sigil burns up out of the floor
#   there and the hall reddens (the omen: `foretold`);
#   the boss comes up out of the sigil, dark at first, and stands;
#   it roars (`roared`): it swells and flashes, a ring bursts from it, the
#   view punches in, the screen shakes and flushes red, and its epithet and
#   name rise in the lower third over a crimson rule as its health comes up
#   across the top;
#   after a hold the view goes back to her and draws out to the fight's
#   (`returning`), the bars leave, the HUD comes back, and `finished` lets
#   the area start the fight.
#
# The area asks nothing of this to be let go: it frees the world on
# `finished`, and by itself if this is ever gone or late.

# The omen begins where the boss will stand.
signal foretold
# The boss roars (the view has settled on it).
signal roared
# The view starts back to her.
signal returning
signal finished

const BAR_HEIGHT := 78.0
const BAR_TIME := 0.3
# She is seen where she stands until the view leaves her, and it takes this
# long to reach the boss's place.
const LEAVE_AT := 0.3
const PAN_TIME := 0.95
# The sigil begins to rise at OMEN_AT and is full at ARRIVE_AT, when the
# boss comes up out of it over RISE_TIME: from this much of its size, dark.
const OMEN_AT := 0.2
const ARRIVE_AT := 1.4
const RISE_TIME := 0.34
const RISE_FROM := 0.72
const RISE_DARK := Color(0.08, 0.02, 0.04, 0.0)
# The roar comes once it stands; the name rises with it.
const ROAR_AT := ARRIVE_AT + RISE_TIME + 0.16
const SWELL := 1.2
const SWELL_TIME := 0.14
const SETTLE_TIME := 0.32
const ROAR_RING := 260.0
const FLUSH := Color(0.7, 0.05, 0.03, 0.32)
const FLUSH_TIME := 0.45
const NAME_TIME := 0.42
const RULE_WIDTH := 560.0
const HOLD_TIME := 1.1
const RETURN_TIME := 0.6
const OUT_TIME := 0.35
# The name sits this share of the way down the screen.
const NAME_PLACE := 0.74
# The view closes in as it travels (APPROACH), punches in at the roar (ZOOM)
# over PUNCH_TIME and creeps closer through the hold (CREEP).
const APPROACH := 1.46
const ZOOM := 1.64
const PUNCH_TIME := 0.16
const CREEP := 0.05

# Whether the entrance may be ended early (set by the area before begin()),
# and from how long after it began.
const SKIP_AFTER := 0.6
var skippable := false
var _stage: Tween
var _swell: Tween
var _glare: Tween
var _rising: Tween
var _began := -1
var _done := false

var _area: BattleArea
var _boss: Foe
var _place := Vector2.ZERO
var _root: Control
var _top: ColorRect
var _bottom: ColorRect
var _flush: ColorRect
var _rule: Control
var _rule_reach := 0.0
var _epithet: Label
var _name: Label


# From the hall's first sight to the fight going on.
static func total_time() -> float:
	return ROAR_AT + NAME_TIME + HOLD_TIME + RETURN_TIME + OUT_TIME


# A key, a button or a click ends it early, once it has run for SKIP_AFTER:
# only an entrance that may be skipped (a boss met on a run before; the
# first sight of one always plays whole).
func _input(event: InputEvent) -> void:
	if not skippable or _done or _began < 0 or Time.get_ticks_msec() - _began < SKIP_AFTER * 1000.0:
		return
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		skip()


# Ends it here, whatever it was in the middle of: the boss stands as it will
# in the fight (brought in now if it was not yet), the view is back on her.
func skip() -> void:
	if _done:
		return
	# Its roar may be in the middle of swelling it, and its rising of
	# lighting it: they end here too, or it would be left so for the fight.
	for running: Tween in [_stage, _swell, _glare, _rising]:
		if running != null:
			running.kill()
	_stage = null
	_boss = _area.bring_boss()
	_boss.scale = Vector2.ONE
	_boss.modulate = Color.WHITE
	_area.camera.global_position = _area.hero.global_position + CombatArea.CAMERA_LEAD
	_end()


# Builds what it shows, at its first moment: called with the world already
# stopped, before the hall's first frame. `place` is where the boss will
# stand.
func present(area: BattleArea, place: Vector2, theme: Theme) -> void:
	_area = area
	_place = place
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = theme
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flush = ColorRect.new()
	_flush.color = Color(FLUSH, 0.0)
	_flush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flush)
	_flush.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar_color := _root.get_theme_color(&"bar", &"BossIntro")
	_top = _bar(bar_color, true)
	_bottom = _bar(bar_color, false)
	_rule = Control.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.draw.connect(_draw_rule)
	_root.add_child(_rule)
	_rule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var boss: FoeData = area.data.boss
	_epithet = _label(tr(boss.epithet), &"BossEpithet")
	_name = _label(tr(boss.display_name), &"BossName")
	var screen := _root.get_viewport_rect().size
	_name.position.y = screen.y * NAME_PLACE - _name.get_combined_minimum_size().y * 0.5
	_epithet.position.y = _name.position.y - _epithet.get_combined_minimum_size().y - 2.0
	for label: Label in [_epithet, _name]:
		label.modulate.a = 0.0
	area.camera.position_smoothing_enabled = false


# Starts its clock (the area calls this once the hall's first, long frames
# have been drawn, so none of it goes by unseen).
func begin() -> void:
	if _began >= 0 or _done:
		return
	_began = Time.get_ticks_msec()
	var screen := _root.get_viewport_rect().size
	var camera := _area.camera
	var stage := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC)
	_stage = stage
	stage.tween_property(_top, "position:y", 0.0, BAR_TIME).set_ease(Tween.EASE_OUT)
	stage.tween_property(_bottom, "position:y", screen.y - BAR_HEIGHT, BAR_TIME).set_ease(Tween.EASE_OUT)
	# Up the hall to where it will stand, closing in.
	stage.tween_property(camera, "global_position", _place + CombatArea.CAMERA_LEAD, PAN_TIME).set_delay(LEAVE_AT).set_ease(Tween.EASE_IN_OUT)
	stage.tween_property(camera, "zoom", Vector2.ONE * APPROACH, PAN_TIME).set_delay(LEAVE_AT).set_ease(Tween.EASE_IN_OUT)
	stage.tween_callback(func(): foretold.emit()).set_delay(OMEN_AT)
	stage.tween_callback(_arrive).set_delay(ARRIVE_AT)
	stage.tween_callback(_roar).set_delay(ROAR_AT)
	stage.tween_property(camera, "zoom", Vector2.ONE * ZOOM, PUNCH_TIME).set_delay(ROAR_AT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stage.tween_property(camera, "zoom", Vector2.ONE * (ZOOM + CREEP), NAME_TIME + HOLD_TIME - PUNCH_TIME).set_delay(ROAR_AT + PUNCH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	stage.tween_method(_reach, 0.0, 1.0, NAME_TIME).set_delay(ROAR_AT)
	for label: Label in [_epithet, _name]:
		var rest := label.position.y
		label.position.y = rest + 18.0
		var delay := ROAR_AT + (0.0 if label == _epithet else 0.1)
		stage.tween_property(label, "position:y", rest, NAME_TIME).set_delay(delay).set_ease(Tween.EASE_OUT)
		stage.tween_property(label, "modulate:a", 1.0, NAME_TIME).set_delay(delay)
	# Then back to her, and away.
	var back_at := ROAR_AT + NAME_TIME + HOLD_TIME
	stage.tween_callback(func(): returning.emit()).set_delay(back_at)
	stage.tween_method(_return_camera, 0.0, 1.0, RETURN_TIME).set_delay(back_at).set_ease(Tween.EASE_IN_OUT)
	stage.tween_property(camera, "zoom", Vector2.ONE * CombatArea.CAMERA_ZOOM, RETURN_TIME).set_delay(back_at).set_ease(Tween.EASE_IN_OUT)
	for label: Label in [_epithet, _name]:
		stage.tween_property(label, "modulate:a", 0.0, RETURN_TIME).set_delay(back_at)
	stage.tween_method(_reach, 1.0, 0.0, RETURN_TIME).set_delay(back_at)
	stage.tween_property(_top, "position:y", -BAR_HEIGHT, OUT_TIME).set_delay(back_at + RETURN_TIME).set_ease(Tween.EASE_IN)
	stage.tween_property(_bottom, "position:y", screen.y, OUT_TIME).set_delay(back_at + RETURN_TIME).set_ease(Tween.EASE_IN)
	stage.chain().tween_callback(_end)


# The boss comes up out of its sigil: small and dark, to its size and light.
func _arrive() -> void:
	_boss = _area.bring_boss()
	_boss.scale = Vector2.ONE * RISE_FROM
	_boss.modulate = RISE_DARK
	_rising = create_tween().set_parallel()
	_rising.tween_property(_boss, "scale", Vector2.ONE, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rising.tween_property(_boss, "modulate", Color.WHITE, RISE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_area.shake(CombatArea.HEAVY_SHAKE * 0.8)


# The boss's roar: it swells and flashes, a red ring bursts from it, the
# screen shakes and flushes red.
func _roar() -> void:
	if _boss == null:
		_boss = _area.bring_boss()
	roared.emit()
	GameAudio.play(self, &"boss", -12.0)
	_area.shake(CombatArea.HEAVY_SHAKE * 1.6)
	# One roar at a time: an earlier one's swelling ends as this begins.
	for earlier: Tween in [_swell, _glare, _rising]:
		if earlier != null:
			earlier.kill()
	_swell = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swell.tween_property(_boss, "scale", Vector2.ONE * SWELL, SWELL_TIME)
	_swell.tween_property(_boss, "scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_SINE)
	_glare = create_tween()
	_boss.modulate = Color(1.8, 1.25, 1.2)
	_glare.tween_property(_boss, "modulate", Color.WHITE, SETTLE_TIME + SWELL_TIME)
	var ring := GroundRing.new()
	ring.process_mode = Node.PROCESS_MODE_ALWAYS
	_area.marks.add_child(ring)
	ring.start(_boss.global_position, ROAR_RING, &"roar")
	_flush.color = FLUSH
	create_tween().tween_property(_flush, "color", Color(FLUSH, 0.0), FLUSH_TIME)


func _return_camera(progress: float) -> void:
	var from := _place + CombatArea.CAMERA_LEAD
	var to := _area.hero.global_position + CombatArea.CAMERA_LEAD
	_area.camera.global_position = from.lerp(to, progress)


func _end() -> void:
	if _done:
		return
	_done = true
	_area.camera.zoom = Vector2.ONE * CombatArea.CAMERA_ZOOM
	_area.camera.position_smoothing_enabled = true
	_area.camera.reset_smoothing()
	finished.emit()
	queue_free()


func _bar(color: Color, top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	var screen := _root.get_viewport_rect().size
	bar.size = Vector2(screen.x, BAR_HEIGHT)
	bar.position = Vector2(0, -BAR_HEIGHT if top else screen.y)
	return bar


func _label(text: String, role: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = role
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	label.size.x = _root.get_viewport_rect().size.x
	return label


func _reach(value: float) -> void:
	_rule_reach = value
	_rule.queue_redraw()


# A crimson line under the name, out from the middle both ways, fading at its ends.
func _draw_rule() -> void:
	var color := _root.get_theme_color(&"rule", &"BossIntro")
	var middle := Vector2(_rule.size.x * 0.5, _name.position.y + _name.size.y + 6.0)
	var half := RULE_WIDTH * 0.5 * _rule_reach
	_rule.draw_polyline_colors(PackedVector2Array([middle - Vector2(half, 0), middle, middle + Vector2(half, 0)]), PackedColorArray([Color(color, 0.0), color, Color(color, 0.0)]), 2.0, true)
	HubUI.mark(_rule, middle, 7.0, Color(color, _rule_reach))
