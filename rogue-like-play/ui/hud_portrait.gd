class_name HudPortrait
extends Panel

# The hero's face in the vitals plate, beside her HP: calm with an occasional blink, a wince for a
# moment when hit, and worn out once HP falls into the danger range. Frames
# come from art/ui/hud_portrait.png (normal, blink, hurt, near collapse).
const SHEET := preload("res://art/ui/hud_portrait.png")
enum Face { NORMAL, BLINK, HURT, WEARY }
const FRAME := 96
const HURT_TIME := 0.6
const BLINK_TIME := 0.14
const BLINK_INTERVAL := 3.6
# Shares the danger vignette's threshold so the face and the red edge agree.
const WEARY_RATIO := DangerVignette.THRESHOLD

var face := Face.NORMAL
var _hp := -1
var _max_hp := 1
var _hurt_left := 0.0
var _blink_clock := 0.0


func _ready() -> void:
	theme_type_variation = &"HudPortraitFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func show_health(hp: int, max_hp: int) -> void:
	# A drop from the last shown value is a hit landing; the first value
	# and any recovery are not.
	if _hp >= 0 and hp < _hp and hp > 0:
		_hurt_left = HURT_TIME
		UIMotion.of(self).pulse(1.05, HURT_TIME * 0.5)
	_hp = hp
	_max_hp = maxi(max_hp, 1)
	_update_face()


func reset() -> void:
	_hp = -1
	_hurt_left = 0.0
	_blink_clock = 0.0
	_update_face()


func weary() -> bool:
	return _hp >= 0 and float(_hp) / _max_hp <= WEARY_RATIO


func _process(delta: float) -> void:
	_hurt_left = maxf(0.0, _hurt_left - delta)
	_blink_clock = fmod(_blink_clock + delta, BLINK_INTERVAL)
	_update_face()


func _update_face() -> void:
	var next := Face.NORMAL
	if _hurt_left > 0.0:
		next = Face.HURT
	elif weary():
		next = Face.WEARY
	elif _blink_clock >= BLINK_INTERVAL - BLINK_TIME:
		next = Face.BLINK
	if next != face:
		face = next
		queue_redraw()


func _draw() -> void:
	var inner := Rect2((size - Vector2.ONE * FRAME) / 2.0, Vector2.ONE * FRAME).abs()
	inner.position = inner.position.floor()
	draw_texture_rect_region(SHEET, inner, Rect2(face * FRAME, 0, FRAME, FRAME))
