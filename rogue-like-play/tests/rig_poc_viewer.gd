extends Node2D

# Visual check of the illustration rig PoC. The left panel is a patch of
# real dungeon floor at the dungeon camera's 1.5 zoom, with the rig hero, an
# enemy and potions; the real
# BattlePresentation plays the attack. Below it the eight facings stand side
# by side at the same size, and the right panel shows the hero's rig three
# times larger to inspect joints and seams.
#
# Arrows / WASD, Q E Z C: step (and face)   R: turn in place   Space: attack
# where she faces   1 / 2 / 3: height 56 / 64 / 72 world px   P: pixel snap
# on / off   T: 30 rigs for load

const RIG_SCENE := preload("res://art/characters/mio_rig/mio_rig.tscn")
const Dungeon := preload("res://world/dungeon/dungeon.gd")
const EnemyScene := preload("res://actors/enemy/enemy.tscn")
const BattlePresentation := preload("res://combat/battle_presentation.gd")
const RigActor := preload("res://tests/rig_poc_actor.gd")
const TERRAIN := preload("res://art/tiles/painted/slate_terrain.png")
const POTION := preload("res://art/items/painted/healing_potion.png")
const SWORD := preload("res://data/weapons/sword.tres")
const TILE_SIZE := 48
const ZOOM := 1.5
const MAP_SIZE := Vector2i(9, 7)
const WORLD_ORIGIN := Vector2(40, 96)
const MAGNIFY := 3.0
const MAGNIFIED_FEET := Vector2(1180, 640)
const LINEUP_FEET := Vector2(84, 742)
const LINEUP_GAP := 80.0
const HEIGHTS: Array[float] = [56.0, 64.0, 72.0]
const STRESS_COUNT := 30
const KEYS := {
	KEY_UP: Vector2i.UP, KEY_W: Vector2i.UP, KEY_DOWN: Vector2i.DOWN, KEY_S: Vector2i.DOWN,
	KEY_LEFT: Vector2i.LEFT, KEY_A: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_D: Vector2i.RIGHT,
	KEY_Q: Vector2i(-1, -1), KEY_E: Vector2i(1, -1), KEY_Z: Vector2i(-1, 1), KEY_C: Vector2i(1, 1),
}
# Clockwise from the front, for turning in place.
const TURN_ORDER: Array[Vector2i] = [Vector2i.DOWN, Vector2i(-1, 1), Vector2i.LEFT, Vector2i(-1, -1),
	Vector2i.UP, Vector2i(1, -1), Vector2i.RIGHT, Vector2i(1, 1)]
const FACING_LABELS := {&"front": "正面", &"front_left": "左前", &"left": "左", &"back_left": "左後",
	&"back": "背面", &"back_right": "右後", &"right": "右", &"front_right": "右前"}

var world: Node2D
var actors: Node2D
var actor: Node2D
var enemy: Node2D
var presentation: Node2D
var magnified_holder: Node2D
var magnified: DirectionalRig
var lineup: Array[DirectionalRig] = []
var world_height := 64.0
var stress: Array[Node2D] = []
var stress_timer: Timer
var state_label: Label
var potion_cells: Array[Vector2i] = [Vector2i(3, 2), Vector2i(1, 2)]


func _ready() -> void:
	world = Node2D.new()
	world.position = WORLD_ORIGIN
	world.scale = Vector2.ONE * ZOOM
	world.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(world)
	var floor_layer := Node2D.new()
	floor_layer.draw.connect(_draw_floor.bind(floor_layer))
	world.add_child(floor_layer)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	actor = RigActor.new()
	actors.add_child(actor)
	actor.setup(RIG_SCENE, world_height)
	actor.cell = Vector2i(3, 3)
	actor.position = _cell_center(actor.cell)
	enemy = EnemyScene.instantiate()
	enemy.stats = enemy.stats.duplicate()
	enemy.cell = Vector2i(3, 4)
	actors.add_child(enemy)
	enemy.position = _cell_center(enemy.cell)
	presentation = BattlePresentation.new()
	presentation.z_index = 20
	world.add_child(presentation)
	magnified_holder = Node2D.new()
	magnified_holder.position = MAGNIFIED_FEET
	magnified_holder.scale = Vector2.ONE * ZOOM * MAGNIFY
	add_child(magnified_holder)
	magnified = RIG_SCENE.instantiate()
	magnified.world_height = world_height
	magnified_holder.add_child(magnified)
	for index in TURN_ORDER.size():
		var holder := Node2D.new()
		holder.position = LINEUP_FEET + Vector2(index * LINEUP_GAP, 0)
		holder.scale = Vector2.ONE * ZOOM
		add_child(holder)
		var standing: DirectionalRig = RIG_SCENE.instantiate()
		standing.world_height = world_height
		standing.facing = TURN_ORDER[index]
		holder.add_child(standing)
		lineup.append(standing)
		_add_label(FACING_LABELS[MioAnimation.direction_name(TURN_ORDER[index])], holder.position + Vector2(-14, 6), 14, Color("b9c5d8"))
	_add_label("白峰 澪　イラストリグ PoC（8方向）", Vector2(40, 30), 28, Color("e9edf7"))
	_add_label("ダンジョン実寸（zoom 1.5）　左：現行ドット絵　中央：リグ", Vector2(40, 72), 16, Color("b9c5d8"))
	_add_label("8方向の待機（実寸）", Vector2(40, 612), 16, Color("b9c5d8"))
	_add_label("リグ 3倍（関節・継ぎ目の確認）", Vector2(860, 72), 16, Color("b9c5d8"))
	_add_label("矢印/WASD・QEZC：歩く　R：その場で向きを変える　Space：攻撃　1/2/3：高さ 56/64/72　P：ピクセルスナップ　T：30体の負荷", Vector2(40, 820), 16, Color("8f9caf"))
	state_label = _add_label("", Vector2(40, 784), 18, Color("f0c77b"))


func _add_label(text_value: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2.ONE * TILE_SIZE / 2.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1600, 900)), Color("05070c"))
	draw_rect(Rect2(40, 636, 648, 140), Color("101722"))
	draw_rect(Rect2(860, 96, 660, 660), Color("101722"))
	draw_rect(Rect2(860, 96, 660, 660), Color("4f5c6b"), false, 2.0)


func _draw_floor(layer: Node2D) -> void:
	# The painted floor, spread over its period as the dungeon lays it.
	var tile_px := Dungeon.PAINTED_CELL
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var tile := Dungeon.PAINTED_FLOOR_START + posmod(y, Dungeon.PAINTED_PERIOD) * Dungeon.PAINTED_PERIOD + posmod(x, Dungeon.PAINTED_PERIOD)
			var source := Rect2(Vector2(tile % Dungeon.PAINTED_COLUMNS, tile / Dungeon.PAINTED_COLUMNS) * tile_px, Vector2.ONE * tile_px)
			layer.draw_texture_rect_region(TERRAIN, Rect2(Vector2(x, y) * TILE_SIZE, Vector2.ONE * TILE_SIZE), source)
	# Potions as the floor draws them: the icon at 0.8 with a soft shadow.
	var half := Vector2.ONE * TILE_SIZE * 0.8 * 0.5
	for cell in potion_cells:
		var center := _cell_center(cell)
		layer.draw_set_transform(center + Vector2(0, 12), 0.0, Vector2(1, 0.32))
		layer.draw_circle(Vector2.ZERO, 12, Color(0.04, 0.045, 0.05, 0.45))
		layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		layer.draw_texture_rect(POTION, Rect2(center - half, half * 2.0), false)


func _process(_delta: float) -> void:
	# The large copy follows the small one's slide and the presentation's lunge.
	var visual: Node2D = actor.combat_visual
	magnified_holder.position = MAGNIFIED_FEET + (visual.position + actor.slide.position) * ZOOM * MAGNIFY
	magnified_holder.rotation = visual.rotation
	magnified_holder.scale = Vector2.ONE * ZOOM * MAGNIFY * visual.scale
	var fps := maxf(1.0, Engine.get_frames_per_second())
	state_label.text = "高さ %d px（画面 %d px）　向き %s　スナップ %s　%s　FPS %d（1フレーム %.2f ms）　描画 %d 回" % [
		world_height, world_height * ZOOM, FACING_LABELS[actor.rig.facing_name],
		"ON" if get_viewport().snap_2d_transforms_to_pixel else "OFF",
		"負荷 %d体" % (stress.size() + 1) if not stress.is_empty() else "",
		fps, 1000.0 / fps, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	if KEYS.has(key):
		do_step(KEYS[key])
	elif key == KEY_R:
		face(TURN_ORDER[(TURN_ORDER.find(actor.facing) + 1) % TURN_ORDER.size()])
	elif key == KEY_SPACE:
		do_attack()
	elif key >= KEY_1 and key <= KEY_3:
		set_world_height(HEIGHTS[key - KEY_1])
	elif key == KEY_P:
		set_snap(not get_viewport().snap_2d_transforms_to_pixel)
	elif key == KEY_T:
		set_stress(stress.is_empty())


# Faces direction without moving, as the game's aim does.
func face(direction: Vector2i) -> void:
	actor.facing = direction
	magnified.facing = direction


# One step towards direction; into a wall or the enemy, she only turns, as in
# the game.
func do_step(direction: Vector2i) -> void:
	if presentation.playing:
		return
	var next: Vector2i = actor.cell + direction
	face(direction)
	if next.x < 0 or next.y < 0 or next.x >= MAP_SIZE.x or next.y >= MAP_SIZE.y or next == enemy.cell:
		return
	actor.step_to(next, TILE_SIZE)
	magnified.step(Vector2(direction))


# The sword attack where she faces, played by the real presentation: the
# lunge, the hit on the enemy if it stands there, and the slash; the rig
# swings with it.
func do_attack() -> void:
	if presentation.playing:
		return
	var direction: Vector2i = actor.facing
	var target: Vector2i = actor.cell + direction
	var events: Array[Dictionary] = [{"kind": "attack", "actor": actor, "origin": actor.cell,
		"direction": direction, "weapon": SWORD, "cells": [target]}]
	if enemy.cell == target:
		events.append({"kind": "hit", "actor": enemy, "origin": enemy.cell, "damage": 3, "dead": false,
			"source": actor, "direction": direction})
	var visible := {}
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			visible[Vector2i(x, y)] = true
	presentation.present(events, actor, visible, TILE_SIZE)
	actor.rig.attack()
	magnified.attack()


func set_world_height(height: float) -> void:
	world_height = height
	actor.rig.world_height = height
	magnified.world_height = height
	for standing in lineup:
		standing.world_height = height
	for extra in stress:
		extra.rig.world_height = height


func set_snap(enabled: bool) -> void:
	get_viewport().snap_2d_transforms_to_pixel = enabled
	get_viewport().snap_2d_vertices_to_pixel = enabled


# Thirty more rigs across the floor in every facing, a third of them walking,
# to read the frame time and draw calls against one.
func set_stress(enabled: bool) -> void:
	for extra in stress:
		extra.queue_free()
	stress.clear()
	if stress_timer != null:
		stress_timer.queue_free()
		stress_timer = null
	if not enabled:
		return
	for index in STRESS_COUNT:
		var extra := RigActor.new()
		extra.facing = TURN_ORDER[index % TURN_ORDER.size()]
		actors.add_child(extra)
		extra.setup(RIG_SCENE, world_height)
		extra.cell = Vector2i(index % MAP_SIZE.x, 5 + index / MAP_SIZE.x % 2)
		extra.position = _cell_center(extra.cell) + Vector2(0, (index / (MAP_SIZE.x * 2)) * 6)
		stress.append(extra)
	stress_timer = Timer.new()
	stress_timer.wait_time = 0.4
	stress_timer.autostart = true
	add_child(stress_timer)
	stress_timer.timeout.connect(func():
		for index in stress.size():
			if index % 3 == 0:
				stress[index].rig.step(Vector2(stress[index].facing)))
