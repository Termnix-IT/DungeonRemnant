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
var _spent := {}
# Where it was as the last physics frame began; it is drawn between that and
# where it is (TickSmoothing).
var _tick_from := Vector2.ZERO
var _image: Texture2D


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
	var light := CanvasItemMaterial.new()
	light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = light


func _physics_process(delta: float) -> void:
	step(delta)


func _process(_delta: float) -> void:
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
	draw_texture_rect(_image, Rect2(Vector2.ONE * -data.size * 0.5, Vector2.ONE * data.size), false, Color(1, 1, 1, alpha))
