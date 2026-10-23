class_name HeroView
extends Node2D

# How the hero looks, read from her motor each frame: the illustration rig
# turned to her facing and walking while she moves, each swing's own motion
# (AttackData.motion), the wound-back stance while she charges, the dash's
# lunge with its fading body and the afterimages it leaves, the flinch and
# flash of a hurt, the blink of her mercy time and the ring of a charge at
# her feet. It never changes what happens in the fight.

const MIO_RIG := preload("res://art/characters/mio_rig/mio_rig.tscn")
const RIG_HEIGHT := 64.0
# A facing changes only once the aim is this far (radians) past the middle
# of the eighth it is in, so aiming along a boundary does not flicker.
const TURN_HYSTERESIS := 0.12
const RING_RADIUS := 22.0
const CHARGE_COLOR := Color("ffd27a")
const DASH_ALPHA := 0.55
const HURT_TINT := Color(2.2, 0.75, 0.7)
# The dash's afterimages: one left every GHOST_GAP seconds of the dash, in
# her pose of that moment, cool and see-through, fading over GHOST_TIME.
const GHOST_GAP := 0.045
const GHOST_TIME := 0.26
const GHOST_TINT := Color(0.62, 0.74, 1.0, 0.55)
const FACINGS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i(1, 1), Vector2i.DOWN, Vector2i(-1, 1),
	Vector2i.LEFT, Vector2i(-1, -1), Vector2i.UP, Vector2i(1, -1)]

var hero: Hero
var rig: DirectionalRig
var rig_view: RigView
var _facing_index := 0
var _flash: Tween
var _charge_pulse := 0.0
var _down := false
var _ghost_left := 0.0


func setup(owner_hero: Hero) -> void:
	hero = owner_hero
	rig_view = RigView.new()
	rig_view.name = "RigView"
	add_child(rig_view)
	rig = MIO_RIG.instantiate()
	rig.world_height = RIG_HEIGHT
	rig_view.setup(rig)
	# A weapon other than the sword takes the sword's place in her hand.
	if hero.moveset != null and hero.moveset.art != null:
		WeaponMount.hold(rig, hero.moveset)
	_turn_to(Vector2.DOWN, true)


func _process(delta: float) -> void:
	if hero == null or _down:
		return
	var motor := hero.motor
	_turn_to(motor.facing)
	rig.braced = motor.charging()
	var moving := motor.motion()
	# Charging, she keeps her stance while she creeps.
	if motor.state == HeroMotor.State.FREE and moving.length() > 30.0:
		rig.step(moving)
	var dashing := motor.state == HeroMotor.State.DASH
	if dashing:
		_ghost_left -= delta
		if _ghost_left <= 0.0:
			_ghost_left = GHOST_GAP
			_leave_ghost()
	var alpha := DASH_ALPHA if dashing else 1.0
	# Her mercy time blinks.
	if hero.health.protected() and fmod(Time.get_ticks_msec() / 70.0, 2.0) < 1.0:
		alpha *= 0.45
	rig_view.modulate.a = alpha
	_charge_pulse = maxf(0.0, _charge_pulse - delta * 3.0)
	queue_redraw()


func swing(attack: AttackData) -> void:
	rig.attack(attack.motion)


func dash(direction: Vector2) -> void:
	rig.dash(direction)
	_ghost_left = 0.0


func charge_ready() -> void:
	_charge_pulse = 1.0


func hurt() -> void:
	rig.hurt()
	_tint(HURT_TINT, 0.18)


func fall() -> void:
	_down = true
	rig.braced = false
	rig.idle()
	rig_view.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(rig_view, "rotation", -1.35, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(rig_view, "modulate", Color(0.55, 0.55, 0.6), 0.6)
	tween.tween_callback(func(): rig.process_mode = Node.PROCESS_MODE_DISABLED)
	queue_redraw()


func _tint(color: Color, duration: float) -> void:
	if _flash != null:
		_flash.kill()
	rig.modulate = color
	_flash = create_tween()
	_flash.tween_property(rig, "modulate", Color.WHITE, duration)


# A still copy of the rig as it is now, left on the floor under the actors
# where she stands, fading away.
func _leave_ghost() -> void:
	var shown := rig.rig
	var layer: Node = hero.area.marks if hero.area != null else get_parent()
	var ghost := shown.duplicate() as CharacterRig
	ghost.frozen = true
	layer.add_child(ghost)
	ghost.global_transform = shown.global_transform
	ghost.modulate = GHOST_TINT
	var fade := ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, GHOST_TIME)
	fade.tween_callback(ghost.queue_free)


# Turns the rig to the nearest of the eight facings, holding the current one
# near a boundary.
func _turn_to(direction: Vector2, force: bool = false) -> void:
	if direction.length() < 0.01:
		return
	var eighth := PI / 4.0
	var index := wrapi(roundi(direction.angle() / eighth), 0, 8)
	if not force and index != _facing_index:
		var off := absf(angle_difference(direction.angle(), _facing_index * eighth))
		if off < eighth * 0.5 + TURN_HYSTERESIS:
			return
	_facing_index = index
	rig.facing = FACINGS[index]


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 15.0, Color(0.03, 0.035, 0.05, 0.45))
	if hero == null or _down:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var progress := hero.motor.charge_progress()
	if hero.motor.charging() or progress > 0.25:
		var full := progress >= 1.0
		var color := Color(CHARGE_COLOR, 0.95 if full else 0.6)
		draw_arc(Vector2.ZERO, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, color, 3.0 if full else 2.0)
	if _charge_pulse > 0.0:
		draw_arc(Vector2.ZERO, RING_RADIUS + (1.0 - _charge_pulse) * 14.0, 0.0, TAU, 40, Color(CHARGE_COLOR, _charge_pulse), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
