class_name Projectile
extends Node2D

# A ProjectileData in flight: it moves straight on, hits each foe its circle
# touches once (through the CombatArea, which shows the hit), and frees
# itself when its distance is spent or it meets a wall. Drawn as its painted
# effect, turned along its way and fading at the end.

const StrikeEffect := preload("res://combat/strike_effect.gd")

var data: ProjectileData
var area: CombatArea
var direction := Vector2.RIGHT
var power := 10.0
var travelled := 0.0
var _spent := {}
var _image: Texture2D


func launch(shot: ProjectileData, combat_area: CombatArea, from: Vector2, toward: Vector2, hero_power: float) -> void:
	data = shot
	area = combat_area
	position = from
	direction = toward.normalized()
	power = hero_power
	z_index = 12
	_image = StrikeEffect.image(data.effect)
	var light := CanvasItemMaterial.new()
	light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = light


func _physics_process(delta: float) -> void:
	step(delta)


# One physics frame; tests call it directly.
func step(delta: float) -> void:
	if data == null:
		return
	var move := minf(data.speed * delta, data.distance - travelled)
	position += direction * move
	travelled += move
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


func _draw() -> void:
	if _image == null:
		return
	var left := 1.0 - travelled / data.distance
	var alpha := clampf(left * 3.0, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, direction.angle(), Vector2.ONE)
	draw_texture_rect(_image, Rect2(Vector2.ONE * -data.size * 0.5, Vector2.ONE * data.size), false, Color(1, 1, 1, alpha))
