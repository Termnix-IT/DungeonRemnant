extends Node2D

# Visual check of the illustration rig PoC (Phase 1, front view only). The
# left panel is a patch of real dungeon floor at the dungeon camera's 1.5
# zoom, with the rig hero, the current pixel hero for comparison, an enemy
# and potions; the real BattlePresentation plays the attack. The right panel
# shows the same rig three times larger to inspect joints and seams.
#
# Arrows / WASD: step   Space: attack the enemy below   1 / 2 / 3: height
# 56 / 64 / 72 world px   P: pixel snap on / off   T: 30 rigs for load

const RIG_SCENE := preload("res://art/characters/mio_rig/mio_rig_front.tscn")
const PlayerScene := preload("res://actors/player/player.tscn")
const EnemyScene := preload("res://actors/enemy/enemy.tscn")
const BattlePresentation := preload("res://combat/battle_presentation.gd")
const RigActor := preload("res://tests/rig_poc_actor.gd")
const TERRAIN := preload("res://art/tiles/dungeon_terrain.png")
const POTION := preload("res://art/items/healing_potion.png")
const SWORD := preload("res://data/weapons/sword.tres")
const TILE_SIZE := 48
const FLOOR_TILES: Array[int] = [0, 3, 4]
const ZOOM := 1.5
const MAP_SIZE := Vector2i(9, 7)
const WORLD_ORIGIN := Vector2(40, 96)
const MAGNIFY := 3.0
const MAGNIFIED_FEET := Vector2(1180, 640)
const HEIGHTS: Array[float] = [56.0, 64.0, 72.0]
const STRESS_COUNT := 30
const KEYS := {
	KEY_UP: Vector2i.UP, KEY_W: Vector2i.UP, KEY_DOWN: Vector2i.DOWN, KEY_S: Vector2i.DOWN,
	KEY_LEFT: Vector2i.LEFT, KEY_A: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_D: Vector2i.RIGHT,
}

var world: Node2D
var actors: Node2D
var actor: Node2D
var pixel_hero: Node2D
var enemy: Node2D
var presentation: Node2D
var magnified_holder: Node2D
var magnified: CharacterRig
var world_height := 64.0
var stress: Array[Node2D] = []
var stress_timer: Timer
var state_label: Label
var potion_cells: Array[Vector2i] = [Vector2i(3, 2), Vector2i(1, 2)]


func _ready() -> void:
	world = Node2D.new()
	world.position = WORLD_ORIGIN
	world.scale = Vector2.ONE * ZOOM
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	pixel_hero = PlayerScene.instantiate()
	pixel_hero.input_enabled = false
	actors.add_child(pixel_hero)
	pixel_hero.facing = Vector2i.DOWN
	pixel_hero.position = _cell_center(Vector2i(1, 3))
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
	magnified_holder.add_child(magnified)
	magnified.world_height = world_height
	_add_label("白峰 澪　イラストリグ PoC（正面）", Vector2(40, 30), 28, Color("e9edf7"))
	_add_label("ダンジョン実寸（zoom 1.5）　左：現行ドット絵　中央：リグ", Vector2(40, 72), 16, Color("b9c5d8"))
	_add_label("リグ 3倍（関節・継ぎ目の確認）", Vector2(860, 72), 16, Color("b9c5d8"))
	_add_label("矢印/WASD：歩く　Space：攻撃　1/2/3：高さ 56/64/72　P：ピクセルスナップ　T：30体の負荷", Vector2(40, 820), 16, Color("8f9caf"))
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
	draw_rect(Rect2(860, 96, 660, 660), Color("101722"))
	draw_rect(Rect2(860, 96, 660, 660), Color("4f5c6b"), false, 2.0)


func _draw_floor(layer: Node2D) -> void:
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var variant := FLOOR_TILES[absi(x * 73856093 ^ y * 19349663) % FLOOR_TILES.size()]
			layer.draw_texture_rect_region(TERRAIN, Rect2(Vector2(x, y) * TILE_SIZE, Vector2.ONE * TILE_SIZE), Rect2(variant * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE))
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
	state_label.text = "高さ %d px（画面 %d px）　スナップ %s　%s　FPS %d　処理 %.2f ms　描画 %d 回" % [
		world_height, world_height * ZOOM, "ON" if get_viewport().snap_2d_transforms_to_pixel else "OFF",
		"負荷 %d体" % (stress.size() + 1) if not stress.is_empty() else "",
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	if KEYS.has(key):
		do_step(KEYS[key])
	elif key == KEY_SPACE:
		do_attack()
	elif key >= KEY_1 and key <= KEY_3:
		set_world_height(HEIGHTS[key - KEY_1])
	elif key == KEY_P:
		set_snap(not get_viewport().snap_2d_transforms_to_pixel)
	elif key == KEY_T:
		set_stress(stress.is_empty())


func do_step(direction: Vector2i) -> void:
	if presentation.playing:
		return
	var next: Vector2i = actor.cell + direction
	if next.x < 0 or next.y < 0 or next.x >= MAP_SIZE.x or next.y >= MAP_SIZE.y or next == enemy.cell or next == Vector2i(1, 3):
		return
	actor.step_to(next, TILE_SIZE)
	magnified.step(Vector2(direction))
	pixel_hero.play_step(Vector2i.DOWN, TILE_SIZE)


# The sword attack downwards, played by the real presentation: the lunge, the
# hit on the enemy if it stands there, and the slash; the rig swings with it.
func do_attack() -> void:
	if presentation.playing:
		return
	var target: Vector2i = actor.cell + Vector2i.DOWN
	var events: Array[Dictionary] = [{"kind": "attack", "actor": actor, "origin": actor.cell,
		"direction": Vector2i.DOWN, "weapon": SWORD, "cells": [target]}]
	if enemy.cell == target:
		events.append({"kind": "hit", "actor": enemy, "origin": enemy.cell, "damage": 3, "dead": false,
			"source": actor, "direction": Vector2i.DOWN})
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
	for extra in stress:
		extra.rig.world_height = height


func set_snap(enabled: bool) -> void:
	get_viewport().snap_2d_transforms_to_pixel = enabled
	get_viewport().snap_2d_vertices_to_pixel = enabled


# Thirty more rigs across the floor, a third of them walking, to read the
# frame time and draw calls against one.
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
				stress[index].rig.step(Vector2.RIGHT if index % 2 == 0 else Vector2.LEFT))
