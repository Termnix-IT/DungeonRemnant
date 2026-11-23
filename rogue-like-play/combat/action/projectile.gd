class_name Projectile
extends Node2D

# A ProjectileData in flight: it moves straight on, hits each foe its circle
# touches once (through the CombatArea, which shows the hit), and frees
# itself when its distance is spent or it meets a wall. A hostile one (a
# foe's shot) strikes the hero instead, once, and is spent on her. Drawn as its painted
# effect, turned along its way and fading at the end.

const StrikeEffect := preload("res://combat/strike_effect.gd")

var data: ProjectileData
var area: CombatArea
var direction := Vector2.RIGHT
var power := 10.0
var travelled := 0.0
var hostile := false
# The foe that shot it, when it is a foe's (so a fall to it names who).
var shooter: FoeData
var _spent := {}
# Where it was as the last physics frame began; it is drawn between that and
# where it is (TickSmoothing).
var _tick_from := Vector2.ZERO
var _image: Texture2D
# The streak it trails (the painted blade's trail, laid along its way),
# coloured by what it is: a foe's shot burns red.
const TRAIL: Texture2D = preload("res://art/effects/vfx/slash_trail.png")
const TINTS := {&"slash": Color(1.0, 0.92, 0.72), &"thrust": Color(1.0, 0.92, 0.72), &"heavy": Color(1.0, 0.74, 0.42), &"magic": Color(0.62, 0.72, 1.0), &"flame": Color(1.0, 0.56, 0.26)}
const HOSTILE_TINT := Color(1.0, 0.42, 0.32)
# The trail's length and half width, as shares of the shot's size.
const TRAIL_LENGTH := 2.8
const TRAIL_HALF := 0.4
var _tint := Color.WHITE
var _clock := 0.0


func launch(shot: ProjectileData, combat_area: CombatArea, from: Vector2, toward: Vector2, hero_power: float, from_foe: bool = false) -> void:
	hostile = from_foe
	data = shot
	area = combat_area
	position = from
	_tick_from = from
	direction = toward.normalized()
	power = hero_power
	z_index = 12
	_image = StrikeEffect.image(data.effect)
	_tint = HOSTILE_TINT if hostile else TINTS.get(data.effect, TINTS[&"slash"])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var light := CanvasItemMaterial.new()
	light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = light


func _physics_process(delta: float) -> void:
	step(delta)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


# One physics frame; tests call it directly.
func step(delta: float) -> void:
	if data == null:
		return
	var move := minf(data.speed * delta, data.distance - travelled)
	_tick_from = position
	position += direction * move
	travelled += move
	if hostile:
		_strike_hero()
		return
	for foe in area.foes:
		if _spent.has(foe) or foe.dying:
			continue
		if foe.global_position.distance_to(global_position) <= data.radius + foe.hit_radius:
			_spent[foe] = true
			var info := DamageInfo.make(power * data.damage_scale, direction, data.knockback, self)
			info.inflicts = data.inflicts
			area.deal(foe, info)
	queue_redraw()
	if travelled >= data.distance or not area.ground.is_open(global_position):
		queue_free()


func _strike_hero() -> void:
	var hero := area.hero
	queue_redraw()
	if hero != null and hero.health.alive() and hero.global_position.distance_to(global_position) <= data.radius + hero.hit_radius:
		hero.receive(DamageInfo.make(power * data.damage_scale, direction, data.knockback, self))
		queue_free()
		return
	if travelled >= data.distance or not area.ground.is_open(global_position):
		queue_free()


func _draw() -> void:
	if _image == null:
		return
	var left := 1.0 - travelled / data.distance
	var alpha := clampf(left * 3.0, 0.0, 1.0)
	draw_set_transform(TickSmoothing.lag(_tick_from, position), direction.angle(), Vector2.ONE)
	# Its trail behind it: the painted streak mirrored about its way, so
	# its sharp edge is the core; it shivers as it flies.
	var length := data.size * TRAIL_LENGTH * minf(1.0, travelled / maxf(data.size, 1.0))
	var half := data.size * TRAIL_HALF * (0.9 + 0.1 * sin(_clock * 43.0))
	var trail := Color(_tint, alpha * (0.8 + 0.2 * sin(_clock * 31.0)))
	draw_texture_rect(TRAIL, Rect2(Vector2(data.size * 0.25 - length, 0.0), Vector2(length, half)), false, trail)
	draw_texture_rect(TRAIL, Rect2(Vector2(data.size * 0.25 - length, 0.0), Vector2(length, -half)), false, trail)
	draw_texture_rect(_image, Rect2(Vector2.ONE * -data.size * 0.5, Vector2.ONE * data.size), false, Color(1, 1, 1, alpha))
