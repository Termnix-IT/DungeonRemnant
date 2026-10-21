class_name DirectionalRig
extends Node2D

# A character's rigs for the eight facings. Each facing drawn has its own
# CharacterRig scene; a facing listed in MIRRORED shows another's rig flipped
# (the right-hand facings show the left-hand ones), with the parts that a
# flip would put on the wrong side hidden. A facing with no scene of its own
# falls back to the front. Only the shown rig runs. On a turn the new rig
# carries on from the old one: the same motion at the same point, and the
# hair swinging as it was, so turning mid-stride does not restart the step.

const MIRRORED := {&"right": &"left", &"front_right": &"front_left", &"back_right": &"back_left"}
const FALLBACK := &"front"

# Facing name (MioAnimation.DIRECTIONS) to its rig scene.
@export var facing_scenes: Dictionary[StringName, PackedScene] = {}
@export var world_height := 64.0:
	set(value):
		world_height = value
		for rig in _rigs.values():
			rig.world_height = value
var facing := Vector2i.DOWN:
	set(value):
		facing = value
		if is_node_ready():
			_show(MioAnimation.direction_name(value))
# Held in every facing's rig, so a turn keeps it (CharacterRig.braced).
var braced := false:
	set(value):
		braced = value
		for each in _rigs.values():
			each.braced = value
# The facing name now shown, and the rig showing it.
var facing_name: StringName = &""
var rig: CharacterRig

var _rigs: Dictionary[StringName, CharacterRig] = {}
var _holders: Dictionary[StringName, Node2D] = {}


func _ready() -> void:
	for facing_key: StringName in facing_scenes:
		var holder := Node2D.new()
		holder.name = String(facing_key).capitalize().replace(" ", "")
		add_child(holder)
		var instance: CharacterRig = facing_scenes[facing_key].instantiate()
		holder.add_child(instance)
		instance.world_height = world_height
		holder.visible = false
		_rigs[facing_key] = instance
		_holders[facing_key] = holder
	_show(MioAnimation.direction_name(facing))


# The facing whose rig is shown for a facing name, and whether it is flipped.
func source_of(name: StringName) -> Array:
	if _rigs.has(name):
		return [name, false]
	if MIRRORED.has(name) and _rigs.has(MIRRORED[name]):
		return [MIRRORED[name], true]
	return [FALLBACK, false]


func step(direction: Vector2) -> void:
	rig.step(direction)


func attack(motion: StringName = CharacterRig.ATTACK) -> void:
	rig.attack(motion)


func dash(direction: Vector2) -> void:
	rig.dash(direction)


func hurt() -> void:
	rig.hurt()


func idle() -> void:
	rig.idle()


func weapon_anchor() -> Node2D:
	return rig.weapon_anchor()


# Shows or hides a part (the sword, when another weapon is held) in every
# facing's rig.
func set_part_shown(part_name: StringName, shown: bool) -> void:
	for each in _rigs.values():
		var part := each.get_node_or_null(NodePath("Parts/" + String(part_name))) as CanvasItem
		if part != null:
			part.visible = shown


func _show(name: StringName) -> void:
	if name == facing_name:
		return
	var source: Array = source_of(name)
	var next: CharacterRig = _rigs.get(source[0])
	if next == null:
		return
	var state := rig.pose_state() if rig != null else {}
	for key in _holders:
		_holders[key].visible = key == source[0]
	_holders[source[0]].scale = Vector2(-1.0 if source[1] else 1.0, 1.0)
	next.mirrored = source[1]
	if not state.is_empty() and next != rig:
		next.resume(state)
	facing_name = name
	rig = next
