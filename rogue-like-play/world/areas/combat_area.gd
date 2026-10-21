class_name CombatArea
extends Node2D

# A battlefield of the real-time fight. It holds the ground, the hero and
# the foes (its `foes` list is what her swings are measured against), the
# hit stop and the camera, and shows what the fight reports: the swing's
# painted effect, the foes' warnings on the floor, the numbers, the shake
# and the sounds. A fallen foe is kept in a pool, out of the world, and
# brought back for the next spawn of its kind, and drops experience gems
# (GemField). Blows other than the hero's swing go through deal() as hers
# do: waves (launch), blasts and chained lightning (a build's triggers),
# burns. What happens is told on `events` (CombatEvents). The open field,
# the arena and the boss hall build on it.

signal hero_fell
signal foe_fell(foe: Foe)

const HERO_SCENE := preload("res://actors/hero/hero.tscn")
const FOE_SCENE := preload("res://actors/foes/foe.tscn")
const StrikeEffect := preload("res://combat/strike_effect.gd")
const CAMERA_ZOOM := 1.3
const CAMERA_LEAD := Vector2(0, -24)
const CAMERA_SMOOTHING := 9.0
const SHAKE_PATTERN: Array[Vector2] = [Vector2(1, -0.6), Vector2(-0.8, 0.5), Vector2(0.45, 0.3), Vector2.ZERO]
const SHAKE_STEP_TIME := 0.035
const HEAVY_SHAKE := 3.0
const HURT_SHAKE := 6.0
const HURT_STOP := 0.06
# A blow pushing this hard (world px/s) is a heavy one and shakes the view.
const HEAVY_KNOCKBACK := 400.0
# How high on a body its effects and numbers show.
const BODY_MIDDLE := Vector2(0, -26)
const NUMBER_HEIGHT := Vector2(0, -58)
# Hit and death sounds closer together than this (ms) are one sound, so a
# crowd struck at once does not use up every voice.
const HIT_SOUND_GAP := 45
const DEATH_SOUND_GAP := 70
# Painted effects of a kind shown at once, at most: past this a crowd's hits
# and falls add no more, so the hero is never buried in smoke.
const EFFECT_CAPS := {&"hit": 18, &"death": 10}
const DEATH_SCALE := 0.9
const BURN_NUMBER := Color("ffa45c")
const BURN_OUTLINE := Color("2a1004")
const LIGHTNING := Color(0.7, 0.88, 1.0)
const LIGHTNING_TIME := 0.22
const LIGHTNING_JAGS := 5

var ground: AreaGround
# The foes' warnings: over the ground, under the actors.
var marks: Node2D
var actors: Node2D
var effects: Node2D
var popups: DamagePopups
var gems: GemField
var events: CombatEvents
var hit_stop: HitStop
var camera: Camera2D
var hero: Hero
var foes: Array[Foe] = []
var kills := 0
var shake_scale := 1.0
# Spawns since the area opened, and foes brought back from the pool.
var spawned := 0
var reused := 0
var _shake: Tween
var _last_hit_sound := -HIT_SOUND_GAP
var _last_death_sound := -DEATH_SOUND_GAP
var _effects_shown: Dictionary = {}
# Retired foes by their FoeData, kept under a node that neither processes
# nor collides.
var _pool: Dictionary = {}
var _pool_holder: Node


func _ready() -> void:
	ground = AreaGround.new()
	ground.name = "Ground"
	add_child(ground)
	marks = Node2D.new()
	marks.name = "Marks"
	marks.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(marks)
	gems = GemField.new()
	gems.name = "Gems"
	gems.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(gems)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	actors.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(actors)
	effects = Node2D.new()
	effects.name = "Effects"
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)
	popups = DamagePopups.new()
	popups.name = "Popups"
	add_child(popups)
	events = CombatEvents.new()
	events.name = "Events"
	add_child(events)
	hit_stop = HitStop.new()
	hit_stop.name = "HitStop"
	add_child(hit_stop)
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2.ONE * CAMERA_ZOOM
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTHING
	add_child(camera)
	_pool_holder = Node.new()
	_pool_holder.name = "Pool"
	_pool_holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_pool_holder)
	StrikeEffect.warm()


func _process(_delta: float) -> void:
	if hero != null:
		camera.global_position = hero.global_position + CAMERA_LEAD


func _physics_process(delta: float) -> void:
	if hero != null and hero.health.alive() and not get_tree().paused:
		gems.step(hero.global_position, delta)


func spawn_hero(at: Vector2) -> Hero:
	hero = HERO_SCENE.instantiate()
	hero.area = self
	hero.position = at
	actors.add_child(hero)
	hero.fell.connect(_on_hero_fell)
	camera.global_position = at + CAMERA_LEAD
	camera.reset_smoothing()
	return hero


func spawn_foe(data: FoeData, at: Vector2) -> Foe:
	spawned += 1
	var kept: Array = _pool.get(data, [])
	var foe: Foe
	if not kept.is_empty():
		foe = kept.pop_back()
		reused += 1
		_pool_holder.remove_child(foe)
		foe.revive(at)
	else:
		foe = FOE_SCENE.instantiate()
		foe.data = data
		foe.position = at
		foe.fell.connect(_on_foe_fell)
		foe.retired.connect(_on_foe_retired)
	foe.target = hero
	foe.area = self
	actors.add_child(foe)
	foes.append(foe)
	return foe


# Every foe leaves without falling (the area is cleared).
func dismiss_foes() -> void:
	for foe in foes:
		foe.vanish()
	foes.clear()


func pooled(data: FoeData) -> int:
	return (_pool.get(data, []) as Array).size()


# The world rectangle the camera shows now.
func view_rect() -> Rect2:
	var size := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)


func show_telegraph(attack: AttackData, origin: Vector2, facing: Vector2) -> Telegraph:
	var telegraph := Telegraph.new()
	telegraph.setup(attack, origin, facing)
	marks.add_child(telegraph)
	return telegraph


# A blow from the hero's side landing on a foe: it is dealt, shown, and told
# (a burn's tick is shown smaller and told to no one). The health lost.
func deal(foe: Foe, info: DamageInfo) -> int:
	if foe == null or foe.dying:
		return 0
	var lost := foe.receive(info)
	if info.flinch:
		report_hit(foe, lost, info)
		events.attack_hit.emit(foe, info)
	elif lost > 0:
		popups.show_number(str(lost), foe.global_position + NUMBER_HEIGHT, BURN_NUMBER, BURN_OUTLINE, DamagePopups.FONT_SIZE - 6)
	return lost


func launch(shot: ProjectileData, from: Vector2, toward: Vector2, power: float) -> Projectile:
	var wave := Projectile.new()
	effects.add_child(wave)
	wave.launch(shot, self, from, toward, power)
	return wave


# Every foe whose body is inside the circle takes the blow.
func blast(center: Vector2, radius: float, power: float, knockback: float, inflicts: Array[StringName], effect: StringName) -> void:
	var across: float = StrikeEffect.PAINTED.get(effect, StrikeEffect.PAINTED[&"heavy"])[0]
	_effect(effect, center + BODY_MIDDLE * 0.4, Vector2.RIGHT, radius * 2.0 / across)
	for foe in foes.duplicate():
		if foe.dying or foe.global_position.distance_to(center) > radius + foe.hit_radius:
			continue
		var info := DamageInfo.make(power, foe.global_position - center, knockback, hero)
		info.inflicts = inflicts
		deal(foe, info)
	shake(HEAVY_SHAKE * 0.6)


# Lightning from `from`, jumping to the nearest foe not yet struck within
# `reach` of the last one, `jumps` times. `skip` (the foe it started from)
# is never struck.
func chain(from: Vector2, skip: Foe, jumps: int, reach: float, power: float, inflicts: Array[StringName]) -> void:
	var struck := {}
	if skip != null:
		struck[skip] = true
	var points := PackedVector2Array([from + BODY_MIDDLE])
	var at := from
	for jump in jumps:
		var next: Foe = null
		var nearest := reach
		for foe in foes:
			if foe.dying or struck.has(foe):
				continue
			var distance := foe.global_position.distance_to(at)
			if distance <= nearest:
				nearest = distance
				next = foe
		if next == null:
			break
		struck[next] = true
		at = next.global_position
		points.append(at + BODY_MIDDLE)
		var info := DamageInfo.make(power, at - from, 60.0, hero)
		info.inflicts = inflicts
		deal(next, info)
	if points.size() > 1:
		_lightning(points)


func _lightning(points: PackedVector2Array) -> void:
	var bolt := Line2D.new()
	bolt.width = 3.0
	bolt.default_color = LIGHTNING
	bolt.z_index = 13
	var light := CanvasItemMaterial.new()
	light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	bolt.material = light
	var jagged := PackedVector2Array([points[0]])
	for index in range(1, points.size()):
		var start := points[index - 1]
		var end := points[index]
		var side := (end - start).orthogonal().normalized()
		for jag in range(1, LIGHTNING_JAGS):
			var share := float(jag) / LIGHTNING_JAGS
			jagged.append(start.lerp(end, share) + side * randf_range(-9.0, 9.0))
		jagged.append(end)
	bolt.points = jagged
	effects.add_child(bolt)
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, LIGHTNING_TIME)
	tween.tween_callback(bolt.queue_free)


func report_swing(by: Hero, attack: AttackData, facing: Vector2) -> void:
	var effect := StrikeEffect.new()
	var across: float = StrikeEffect.PAINTED.get(attack.effect, StrikeEffect.PAINTED[&"slash"])[0]
	var spread := 1.5
	effect.scale = Vector2.ONE * attack.reach * spread / across
	var points: Array[Vector2] = [Vector2.ZERO]
	effect.position = by.global_position + BODY_MIDDLE * 0.6
	if attack.shape != AttackData.Shape.CIRCLE:
		effect.position += facing * attack.reach * 0.45
	effects.add_child(effect)
	effect.start(attack.effect, points, facing)
	GameAudio.play(self, &"heavy" if attack.shape == AttackData.Shape.CIRCLE else &"slash", -18.0)


func report_hit(target: Node2D, lost: int, info: DamageInfo) -> void:
	if lost > 0:
		popups.dealt(lost, target.global_position + NUMBER_HEIGHT)
	_effect(&"hit", target.global_position + BODY_MIDDLE, info.direction, 1.3)
	var now := Time.get_ticks_msec()
	if now - _last_hit_sound >= HIT_SOUND_GAP:
		_last_hit_sound = now
		GameAudio.play(self, &"hit", -20.0)
	if info.knockback >= HEAVY_KNOCKBACK:
		shake(HEAVY_SHAKE)


func report_hero_hurt(by: Hero, lost: int, _info: DamageInfo) -> void:
	popups.taken(lost, by.global_position + NUMBER_HEIGHT)
	hit_stop.request(HURT_STOP)
	shake(HURT_SHAKE)
	GameAudio.play(self, &"heavy", -16.0)


func shake(strength: float) -> void:
	strength *= shake_scale
	if strength <= 0.0:
		return
	if _shake != null:
		_shake.kill()
	_shake = create_tween()
	_shake.set_ignore_time_scale(true)
	for index in SHAKE_PATTERN.size():
		var falloff := 1.0 - float(index) / SHAKE_PATTERN.size()
		_shake.tween_property(camera, "offset", SHAKE_PATTERN[index] * strength * falloff, SHAKE_STEP_TIME)


func _on_foe_fell(foe: Foe) -> void:
	foes.erase(foe)
	kills += 1
	gems.drop(foe.global_position, foe.data.exp_reward)
	_effect(&"death", foe.global_position + BODY_MIDDLE * 0.7, Vector2.RIGHT, DEATH_SCALE)
	var now := Time.get_ticks_msec()
	if now - _last_death_sound >= DEATH_SOUND_GAP:
		_last_death_sound = now
		GameAudio.play(self, &"death", -22.0)
	foe_fell.emit(foe)
	events.enemy_killed.emit(foe)


# A painted effect at a point, unless its kind is at its cap.
func _effect(kind: StringName, at: Vector2, direction: Vector2, size: float) -> void:
	var shown: int = _effects_shown.get(kind, 0)
	if shown >= EFFECT_CAPS.get(kind, 1000):
		return
	_effects_shown[kind] = shown + 1
	var effect := StrikeEffect.new()
	effect.scale = Vector2.ONE * size
	effect.position = at
	effects.add_child(effect)
	effect.tree_exited.connect(func(): _effects_shown[kind] = _effects_shown[kind] - 1)
	var points: Array[Vector2] = [Vector2.ZERO]
	effect.start(kind, points, direction)


func _on_foe_retired(foe: Foe) -> void:
	actors.remove_child(foe)
	_pool_holder.add_child(foe)
	if not _pool.has(foe.data):
		_pool[foe.data] = []
	_pool[foe.data].append(foe)


func _on_hero_fell() -> void:
	GameAudio.play(self, &"defeat", -16.0)
	hero_fell.emit()
