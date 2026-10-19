class_name CharacterRig
extends Node2D

# A character drawn as an illustration cut into parts and moved by bones.
# The scene (built by tools/build_character_rig.gd) holds a Skeleton2D, one
# Polygon2D per part skinned to its bones (drawn in sibling order, so the
# parts never leak a z_index into the actors' y-sort), and an AnimationPlayer
# with idle, walk and attack. This script plays them and adds what keys
# cannot know in advance: the lean into a step, the hair and hem that trail
# the body on springs, and the blink. It never reads or changes game rules.
#
# Its origin is between the soles, where the shadow is. Bones rest at
# rotation 0, so an animation's rotation keys are offsets from the rest pose.
# Motion is read in the rig's own space, so a rig shown mirrored (a parent
# with a negative x scale, as DirectionalRig does) leans and swings the right
# way.

const IDLE := &"idle"
const WALK := &"walk"
const ATTACK := &"attack_sword"
# Optional motions (an enemy's): flinching from a hit, and falling, which
# holds its last pose.
const HURT := &"hurt"
const DOWN := &"down"
# Optional: a looping held wind-up, shown while `braced` (an enemy's warning
# turn) whenever nothing else plays.
const BRACE := &"brace"
# Blending between motions, in seconds: a step starts at once, an attack
# snaps to its wind-up, and the body settles into the idle more slowly.
const WALK_BLEND := 0.08
const ATTACK_BLEND := 0.03
const IDLE_BLEND := 0.18
# The lean into a step's direction, on the chest, and how it eases back.
const LEAN_ANGLE := 0.07
const LEAN_FREQUENCY := 2.2
const LEAN_DAMPING := 0.75
# A bone marked "spring" swings on its own damped spring: it trails its
# parent's motion and keeps hanging when its parent turns.
const SPRING_FREQUENCY := 1.6
const SPRING_DAMPING := 0.32
const SPRING_LIMIT := 0.5
# A slow drift of their own, so the hair never hangs dead still in the idle.
const SPRING_DRIFT := 0.035
const SPRING_DRIFT_PERIOD := 3.3
# A move longer than this in one frame (world px) is a placement, not motion.
const TELEPORT_DISTANCE := 24.0
const BLINK_GAP := Vector2(2.5, 6.0)
const BLINK_STEPS := [[0.05, 1], [0.08, 2], [0.05, 1]]

# The illustration's figure height in its texture pixels, set by the builder.
@export var figure_height := 280.0
# How tall the figure stands in the world, in world px (64 is about 96 px on
# a 1600x900 screen at the dungeon camera's 1.5 zoom).
@export var world_height := 64.0:
	set(value):
		world_height = value
		if figure_height > 0.0:
			scale = Vector2.ONE * world_height / figure_height
# The chest bone the lean turns; eye parts open, half and closed.
@export var lean_bone: NodePath
@export var eye_parts: Array[NodePath] = []
@export var weapon_anchor_path: NodePath
# Shown flipped: parts marked "mirror_hide" (the flower and ribbon on her
# left, which a flipped picture would put on the wrong side) are hidden.
var mirrored := false:
	set(value):
		mirrored = value
		for part in find_children("*", "Polygon2D", true, false):
			if part.get_meta(&"mirror_hide", false):
				part.visible = not mirrored

var animation_player: AnimationPlayer
var braced := false:
	set(value):
		if value == braced:
			return
		braced = value
		_follow_brace()
var time := 0.0
var rng := RandomNumberGenerator.new()
var _springs: Array[Dictionary] = []
var _walk_left := 0.0
var _lean := 0.0
var _lean_velocity := 0.0
var _lean_target := 0.0
var _impulse := Vector2.ZERO
var _next_blink := 0.0
var _blink_time := -1.0
var _lean_node: Bone2D


func _ready() -> void:
	rng.randomize()
	world_height = world_height
	animation_player = get_node(^"AnimationPlayer")
	# The rig steps the player itself, so the lean and springs apply after it.
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_lean_node = get_node_or_null(lean_bone) as Bone2D
	for bone: Bone2D in find_children("*", "Bone2D", true, false):
		if bone.get_meta(&"spring", false):
			_springs.append({"bone": bone, "angle": 0.0, "velocity": 0.0, "phase": _springs.size() * 1.7,
				"gain": float(bone.get_meta(&"spring_gain", 1.0)), "last": bone.global_position})
	_next_blink = rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	animation_player.play(IDLE)
	# Rigs side by side do not breathe in unison.
	animation_player.seek(rng.randf() * animation_player.get_animation(IDLE).length, true)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))


func _process(delta: float) -> void:
	advance(delta)


# Steps every motion by delta seconds; tests call it to run time forward.
func advance(delta: float) -> void:
	time += delta
	if animation_player.current_animation == WALK:
		_walk_left -= delta
		if _walk_left <= 0.0:
			_lean_target = 0.0
			animation_player.play(IDLE, IDLE_BLEND)
	if braced and animation_player.current_animation == IDLE:
		_follow_brace()
	animation_player.advance(delta)
	_apply_lean(delta)
	_apply_springs(delta)
	_step_blink(delta)


# One step of the walk towards direction. Steps in a row keep the stride's
# phase; the walk ends on a half cycle, where both feet are under her.
func step(direction: Vector2) -> void:
	var walk_length := animation_player.get_animation(WALK).length
	var half := walk_length * 0.5
	if animation_player.current_animation == WALK:
		var position := animation_player.current_animation_position
		_walk_left = ceilf((position + walk_length) / half - 0.001) * half - position
	else:
		animation_player.play(WALK, WALK_BLEND)
		_walk_left = walk_length
	var local := _local(direction).normalized()
	_lean_target = clampf(local.x, -1.0, 1.0) * LEAN_ANGLE
	# The hair and hem are left behind for a moment.
	_impulse = -local


func attack() -> void:
	_walk_left = 0.0
	_lean_target = 0.0
	animation_player.play(ATTACK, ATTACK_BLEND)
	animation_player.queue(IDLE)


func idle() -> void:
	_walk_left = 0.0
	_lean_target = 0.0
	animation_player.play(IDLE, IDLE_BLEND)


func _follow_brace() -> void:
	if not animation_player.has_animation(BRACE):
		return
	var current := animation_player.current_animation
	if braced and current == IDLE:
		animation_player.play(BRACE, ATTACK_BLEND * 3.0)
	elif not braced and current == BRACE:
		animation_player.play(IDLE, IDLE_BLEND)


func hurt() -> void:
	if not animation_player.has_animation(HURT) or animation_player.current_animation == DOWN:
		return
	_walk_left = 0.0
	animation_player.play(HURT, ATTACK_BLEND)
	animation_player.queue(IDLE)


func fall() -> void:
	if not animation_player.has_animation(DOWN):
		return
	_walk_left = 0.0
	animation_player.clear_queue()
	animation_player.play(DOWN, ATTACK_BLEND)


func weapon_anchor() -> Node2D:
	return get_node_or_null(weapon_anchor_path) as Node2D


# What another facing's rig needs to carry on from this one: the motion and
# where it is in it, and the swing of each spring bone by name.
func pose_state() -> Dictionary:
	var swings := {}
	for spring in _springs:
		swings[spring.bone.name] = [spring.angle, spring.velocity]
	return {"animation": animation_player.current_animation, "position": animation_player.current_animation_position,
		"walk_left": _walk_left, "lean": [_lean, _lean_velocity, _lean_target], "swings": swings, "time": time}


func resume(state: Dictionary) -> void:
	var animation: StringName = state.get("animation", IDLE)
	if animation_player.has_animation(animation):
		animation_player.play(animation)
		animation_player.seek(float(state.get("position", 0.0)), true)
		if animation == ATTACK:
			animation_player.queue(IDLE)
	_walk_left = float(state.get("walk_left", 0.0))
	var lean: Array = state.get("lean", [0.0, 0.0, 0.0])
	_lean = lean[0]
	_lean_velocity = lean[1]
	_lean_target = lean[2]
	time = float(state.get("time", time))
	var swings: Dictionary = state.get("swings", {})
	for spring in _springs:
		var swing: Array = swings.get(spring.bone.name, [0.0, 0.0])
		spring.angle = swing[0]
		spring.velocity = swing[1]
		spring.last = spring.bone.global_position


func _local(vector: Vector2) -> Vector2:
	return global_transform.affine_inverse().basis_xform(vector)


# How far a node is turned within the rig, summed up its bones; a mirrored
# parent's negative scale makes global_rotation unreliable here.
func _turn_within(node: Node) -> float:
	var turn := 0.0
	while node != null and node != self:
		if node is Node2D:
			turn += (node as Node2D).rotation
		node = node.get_parent()
	return turn


func _apply_lean(delta: float) -> void:
	var omega := TAU * LEAN_FREQUENCY
	_lean_velocity += (omega * omega * (_lean_target - _lean) - 2.0 * LEAN_DAMPING * omega * _lean_velocity) * delta
	_lean += _lean_velocity * delta
	if _lean_node != null:
		_lean_node.rotation += _lean


func _apply_springs(delta: float) -> void:
	if delta <= 0.0:
		return
	var omega := TAU * SPRING_FREQUENCY
	var steps := maxi(1, ceili(delta / 0.01))
	var step_time := delta / steps
	for spring in _springs:
		var bone: Bone2D = spring.bone
		var parent := bone.get_parent() as Node2D
		var moved: Vector2 = bone.global_position - spring.last
		spring.last = bone.global_position
		# In the rig's own pixels, so a smaller or mirrored figure swings the
		# same way.
		var velocity := Vector2.ZERO
		if moved.length() < TELEPORT_DISTANCE:
			velocity = _local(moved) / delta
		# Trail the motion sideways, and hang straight when the parent turns.
		var parent_turn := _turn_within(parent)
		var gain: float = spring.gain
		var drift := sin(time * TAU / SPRING_DRIFT_PERIOD + float(spring.phase)) * SPRING_DRIFT
		var target := (-velocity.x * 0.0009 + _impulse.x * 0.18 + drift) * gain - parent_turn * 0.6
		var angle: float = spring.angle
		var speed: float = spring.velocity
		for i in steps:
			speed += (omega * omega * (target - angle) - 2.0 * SPRING_DAMPING * omega * speed) * step_time
			angle += speed * step_time
		spring.angle = angle
		spring.velocity = speed
		bone.rotation = SPRING_LIMIT * tanh(angle / SPRING_LIMIT)
	_impulse = _impulse.move_toward(Vector2.ZERO, delta * 8.0)


func _step_blink(delta: float) -> void:
	if eye_parts.size() < 3:
		return
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_time = 0.0
		_next_blink = rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	var frame := 0
	if _blink_time >= 0.0:
		_blink_time += delta
		var elapsed := 0.0
		frame = -1
		for blink_step: Array in BLINK_STEPS:
			elapsed += blink_step[0]
			if _blink_time < elapsed:
				frame = blink_step[1]
				break
		if frame < 0:
			frame = 0
			_blink_time = -1.0
	for index in 3:
		var part := get_node_or_null(eye_parts[index]) as CanvasItem
		if part != null:
			part.visible = index == frame
