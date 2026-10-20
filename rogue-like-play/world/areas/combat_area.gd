class_name CombatArea
extends Node2D

# A battlefield of the real-time fight. It holds the ground, the hero and
# the foes (its `foes` list is what her swings are measured against), the
# hit stop and the camera, and shows what the fight reports: the swing's
# painted effect, the numbers, the shake and the sounds. The open field, the
# arena and the boss hall build on it.

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
# Death sounds closer together than this (ms) are one sound.
const DEATH_SOUND_GAP := 70

var ground: AreaGround
var actors: Node2D
var effects: Node2D
var popups: DamagePopups
var hit_stop: HitStop
var camera: Camera2D
var hero: Hero
var foes: Array[Foe] = []
var kills := 0
var shake_scale := 1.0
var _shake: Tween
var _last_death_sound := -DEATH_SOUND_GAP


func _ready() -> void:
	ground = AreaGround.new()
	ground.name = "Ground"
	add_child(ground)
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
	hit_stop = HitStop.new()
	hit_stop.name = "HitStop"
	add_child(hit_stop)
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2.ONE * CAMERA_ZOOM
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTHING
	add_child(camera)
	StrikeEffect.warm()


func _process(_delta: float) -> void:
	if hero != null:
		camera.global_position = hero.global_position + CAMERA_LEAD


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
	var foe: Foe = FOE_SCENE.instantiate()
	foe.data = data
	foe.target = hero
	foe.position = at
	actors.add_child(foe)
	foes.append(foe)
	foe.fell.connect(_on_foe_fell)
	return foe


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
	var effect := StrikeEffect.new()
	effect.scale = Vector2.ONE * 1.3
	effect.position = target.global_position + BODY_MIDDLE
	effects.add_child(effect)
	var points: Array[Vector2] = [Vector2.ZERO]
	effect.start(&"hit", points, info.direction)
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
	var effect := StrikeEffect.new()
	effect.scale = Vector2.ONE * 1.2
	effect.position = foe.global_position + BODY_MIDDLE * 0.7
	effects.add_child(effect)
	var points: Array[Vector2] = [Vector2.ZERO]
	effect.start(&"death", points, Vector2.RIGHT)
	var now := Time.get_ticks_msec()
	if now - _last_death_sound >= DEATH_SOUND_GAP:
		_last_death_sound = now
		GameAudio.play(self, &"death", -22.0)
	foe_fell.emit(foe)


func _on_hero_fell() -> void:
	GameAudio.play(self, &"defeat", -16.0)
	hero_fell.emit()
