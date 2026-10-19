extends SceneTree

# Captures the wandering sentinel drawn as its illustration rig in the real
# run (seed 47): standing beside the hero facing either way, its own attack
# on her, the hero's blow on it, and its fall. Frames are kept in memory and
# written at the end to .godot/enemy_rig_*.png.

const ENEMY := preload("res://actors/enemy/enemy.tscn")
const BASIC := preload("res://data/enemies/basic_enemy.tres")

var shots: Dictionary = {}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	root.size = Vector2i(1600, 900)
	var main := load("res://game/main.gd").new() as Node
	var run = (load("res://game/run/run.tscn") as PackedScene).instantiate()
	main.add_child(run)
	run.generation_seed = 47
	run.dungeon_settings = run.dungeon_settings.duplicate()
	run.dungeon_settings.enemy_count = 0
	run.dungeon_settings.monster_house_chance = 0.0
	run.dungeon_settings.reinforcement_total_cap = 0
	root.add_child(main)
	await create_timer(0.5).timeout
	var hero: Node2D = run.turns.player
	var grid: GridState = run.dungeon.grid
	var sides: Array[Vector2i] = []
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var cell: Vector2i = hero.cell + direction
		if grid.is_floor(cell) and not grid.occupants.has(cell):
			sides.append(direction)
	var enemies: Array[Node2D] = []
	for index in mini(2, sides.size()):
		var enemy: Node2D = ENEMY.instantiate()
		enemy.stats = BASIC.duplicate()
		enemy.stats.exp_reward = 0
		run.dungeon.get_node("Actors").add_child(enemy)
		grid.place(enemy, hero.cell + sides[index])
		enemy.hp = enemy.stats.max_hp
		enemy.facing = -sides[index]
		run.turns.enemies.append(enemy)
		enemies.append(enemy)
	run._refresh()
	await create_timer(1.0).timeout
	await _grab("enemy_rig_idle")
	var foe: Node2D = enemies[0]
	# The sentinel strikes the hero.
	var events: Array[Dictionary] = [
		{"kind": "attack", "actor": foe, "origin": foe.cell, "direction": hero.cell - foe.cell, "weapon": null, "cells": [hero.cell]},
		{"kind": "hit", "actor": hero, "origin": hero.cell, "damage": 1, "dead": false, "source": foe, "direction": hero.cell - foe.cell}]
	run.presentation.present(events, hero, run.dungeon.fog.visible, run.dungeon.TILE_SIZE)
	await _grab_at(Time.get_ticks_msec(), {"enemy_rig_attack_050": 0.05, "enemy_rig_attack_090": 0.09, "enemy_rig_attack_200": 0.2})
	await create_timer(0.8).timeout
	# The hero's blow: a flinch, then a killing one and the fall.
	hero.facing = foe.cell - hero.cell
	foe.hp = 999
	run._on_action("attack", hero.facing)
	await _grab_at(Time.get_ticks_msec(), {"enemy_rig_hurt_150": 0.15})
	await create_timer(0.9).timeout
	foe.hp = 1
	run._on_action("attack", hero.facing)
	await _grab_at(Time.get_ticks_msec(), {"enemy_rig_down_150": 0.15, "enemy_rig_down_300": 0.3, "enemy_rig_down_450": 0.45})
	await create_timer(1.0).timeout
	await _grab("enemy_rig_after")
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the enemy rig.")
	quit(0 if result == OK else 1)


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()


func _grab_at(started: int, times: Dictionary) -> void:
	for file_name: String in times:
		while (Time.get_ticks_msec() - started) / 1000.0 < float(times[file_name]):
			await process_frame
		await _grab(file_name)
