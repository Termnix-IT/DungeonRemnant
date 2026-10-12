extends Node2D

# A stand-in hero for the rig PoC. It offers what BattlePresentation reads
# from the player (combat_visual, weapon_visual, weapon_rest(), reset_step(),
# cell, hp, facing), so the real presentation plays its lunge, flash and
# effects on the rig unchanged. A step moves it like Player.play_step: the
# node jumps to the new cell and only the picture slides the last 8 px.

const MOVE_VISUAL_OFFSET := 8.0
const MOVE_ANIMATION_DURATION := 0.12
# The soles sit this far below the cell's centre, as the hero's do.
const SOLE_OFFSET := 25.0

var cell := Vector2i.ZERO
var hp := 10
var facing := Vector2i.DOWN
var combat_visual: Node2D
# The presentation turns this for a sword; the rig swings its own sword, so
# the presentation's turn lands on an empty node.
var weapon_visual: Node2D
var rig: CharacterRig
var slide: Node2D
var move_tween: Tween


func setup(rig_scene: PackedScene, world_height: float) -> void:
	combat_visual = Node2D.new()
	add_child(combat_visual)
	slide = Node2D.new()
	combat_visual.add_child(slide)
	var shadow := Node2D.new()
	shadow.position = Vector2(0, SOLE_OFFSET)
	shadow.scale = Vector2(1.0, 0.5)
	shadow.draw.connect(func(): shadow.draw_circle(Vector2.ZERO, 9, Color(0, 0, 0, 0.32)))
	slide.add_child(shadow)
	rig = rig_scene.instantiate()
	rig.position = Vector2(0, SOLE_OFFSET)
	slide.add_child(rig)
	rig.world_height = world_height
	weapon_visual = Node2D.new()
	combat_visual.add_child(weapon_visual)


func weapon_rest() -> Vector2:
	return Vector2.ZERO


func reset_step() -> void:
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	slide.position = Vector2.ZERO


func step_to(next_cell: Vector2i, tile_size: int) -> void:
	var direction := Vector2(next_cell - cell).normalized()
	cell = next_cell
	position = Vector2(cell * tile_size) + Vector2.ONE * tile_size / 2.0
	reset_step()
	slide.position = -direction * MOVE_VISUAL_OFFSET
	move_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(slide, "position", Vector2.ZERO, MOVE_ANIMATION_DURATION)
	rig.step(direction)
