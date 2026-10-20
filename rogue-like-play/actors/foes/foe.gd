class_name Foe
extends CharacterBody2D

# An enemy of the real-time fight: walks where its FoeBrain steers, hurts the
# hero by touch, staggers and is pushed back when struck, and falls. Drawn
# as its illustration rig (EnemySprites.rig_path), mirrored when it walks
# left.

signal fell(foe: Foe)

const FLASH := Color(2.6, 2.6, 2.6)
const FLASH_TIME := 0.12
const FADE_DELAY := 0.35
const FADE_TIME := 0.3
const RIG_HEIGHT := 60.0

@export var data: FoeData = preload("res://data/foes/wandering_sentinel.tres")
var health: Combatant
var brain := FoeBrain.new()
var target: Hero
var hit_radius := 14.0
var dying := false
var walk := Vector2.ZERO
var rig: CharacterRig
var rig_view: RigView
var _speed := 95.0
var _push := Vector2.ZERO
var _stun_left := 0.0
var _contact_left := 0.0
var _facing_left := false
var _flash: Tween


func _ready() -> void:
	health = Combatant.new(data.max_hp, data.defense)
	hit_radius = data.hit_radius
	_speed = data.speed * (1.0 + randf_range(-data.speed_spread, data.speed_spread))
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Hero.FOES
	collision_mask = Hero.WALLS | Hero.FOES | Hero.HEROES
	# Bodies as wide as the hit circle plus a little, so a crowd keeps apart
	# about as far as the drawings are wide.
	var feet := $Feet as CollisionShape2D
	feet.shape = feet.shape.duplicate()
	(feet.shape as CircleShape2D).radius = hit_radius + 2.0
	_build_rig()


func _build_rig() -> void:
	var path := EnemySprites.rig_path(data.visual_id)
	if not ResourceLoader.exists(path):
		return
	rig_view = RigView.new()
	rig_view.name = "RigView"
	add_child(rig_view)
	rig = (load(path) as PackedScene).instantiate()
	rig.world_height = float(rig.get_meta(&"world_height", RIG_HEIGHT))
	rig_view.setup(rig)


func _physics_process(delta: float) -> void:
	step(delta)


# One physics frame: tests call it directly.
func step(delta: float) -> void:
	if dying:
		return
	health.step(delta)
	_stun_left = maxf(0.0, _stun_left - delta)
	_contact_left = maxf(0.0, _contact_left - delta)
	var desired := Vector2.ZERO
	if _stun_left <= 0.0 and target != null and target.health.alive():
		desired = brain.steer(global_position, target.global_position, _speed)
	walk = walk.move_toward(desired, data.acceleration * delta)
	_push = _push * exp(-8.0 * delta)
	if _push.length() < 1.0:
		_push = Vector2.ZERO
	velocity = walk + _push
	move_and_slide()
	_touch()
	_follow_rig()


# A blow from the hero; the health lost.
func receive(info: DamageInfo) -> int:
	if dying:
		return 0
	var lost := health.take(info)
	_push += info.direction * info.knockback * (1.0 - data.knockback_resist)
	_stun_left = data.hitstun
	walk = Vector2.ZERO
	_show_flash()
	if rig != null:
		rig.hurt()
	if not health.alive():
		_fall()
	return lost


func _touch() -> void:
	if _contact_left > 0.0 or target == null or not target.health.alive():
		return
	var offset := target.global_position - global_position
	if offset.length() > hit_radius + target.hit_radius + 4.0:
		return
	var lost := target.receive(DamageInfo.make(data.contact_damage, offset, data.contact_knockback, self))
	# A touch the hero dodged is tried again soon; one that landed waits.
	_contact_left = data.contact_cooldown if lost > 0 else 0.1


func _fall() -> void:
	dying = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	if rig != null:
		rig.fall()
	fell.emit(self)
	var tween := create_tween()
	tween.tween_interval(FADE_DELAY)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _show_flash() -> void:
	if rig_view == null:
		return
	if _flash != null:
		_flash.kill()
	rig_view.modulate = FLASH
	_flash = create_tween()
	_flash.tween_property(rig_view, "modulate", Color.WHITE, FLASH_TIME)


func _follow_rig() -> void:
	if rig == null:
		return
	if absf(walk.x) > 8.0:
		_facing_left = walk.x < 0.0
	rig_view.scale.x = -1.0 if _facing_left else 1.0
	if walk.length() > 20.0 and _stun_left <= 0.0:
		rig.step(walk)
