class_name BossSigil
extends Node2D

# The sigil that burns on the floor where a boss is about to stand
# (BattleArea): a great seal of light (art/effects/painted/boss_sigil.png)
# lying on the floor, seen from above as the floor is. It comes up out of
# nothing as the boss's mark runs (rise()), turning slowly and throbbing
# faster as the moment nears; when the boss stands in it (flare()) it
# blazes, opens outward and is gone. Drawn under the fighters, added as
# light; it never changes what happens in the fight.

const SEAL: Texture2D = preload("res://art/effects/painted/boss_sigil.png")
const COLOUR := Color(1.0, 0.24, 0.2)
const HEART := Color(1.0, 0.72, 0.5)
# How wide it lies (world px), how fast it turns (radians a second) and how
# it throbs.
const ACROSS := 300.0
const TURN := 0.35
const THROB := Vector2(2.4, 9.0)
const FLARE_TIME := 0.5
const FLARE_GROW := 1.7

# How much of it has come up (0 to 1), and how far its flare has gone.
var shown := 0.0
var flared := -1.0
var _clock := 0.0
var _rise: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var added := CanvasItemMaterial.new()
	added.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = added


# Comes up over `time` seconds.
func rise(time: float) -> void:
	_rise = create_tween()
	_rise.tween_property(self, "shown", 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# The boss stands in it: it blazes, opens outward and is gone.
func flare() -> void:
	if flared >= 0.0:
		return
	if _rise != null:
		_rise.kill()
	shown = 1.0
	flared = 0.0
	var going := create_tween().set_ignore_time_scale(true)
	going.tween_property(self, "flared", 1.0, FLARE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	going.tween_callback(queue_free)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var throb := 0.82 + 0.18 * sin(_clock * lerpf(THROB.x, THROB.y, shown))
	var across := ACROSS * lerpf(0.86, 1.0, shown)
	var alpha := shown * throb
	if flared >= 0.0:
		across *= lerpf(1.0, FLARE_GROW, flared)
		alpha = (1.0 - flared) * 1.4
	var rect := Rect2(Vector2.ONE * -across * 0.5, Vector2.ONE * across)
	draw_set_transform(Vector2.ZERO, _clock * TURN)
	draw_texture_rect(SEAL, rect, false, Color(COLOUR, minf(alpha, 1.0)))
	# Its heart burns hotter than its rim.
	draw_texture_rect(SEAL, Rect2(rect.position * 0.62, rect.size * 0.62), false, Color(HEART, minf(alpha * 0.5, 1.0)))
	draw_set_transform(Vector2.ZERO)
