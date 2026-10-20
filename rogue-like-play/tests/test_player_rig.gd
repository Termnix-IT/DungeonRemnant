extends SceneTree

# The hero drawn as the illustration rig: it follows her facing, walks with
# the step's slide, shows the weapon she holds, swings with the battle
# presentation's timing (which then leaves the held picture unturned), lies
# still once fallen, and draws at the screen's scale.

const PLAYER := preload("res://actors/player/player.tscn")
const ENEMY := preload("res://actors/enemy/enemy.tscn")
const BattlePresentation := preload("res://combat/battle_presentation.gd")
const SWORD := preload("res://data/weapons/sword.tres")
const SPEAR := preload("res://data/weapons/spear.tres")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func run_tests() -> void:
	var main := preload("res://game/main.gd").new()
	root.add_child(main)
	var player = PLAYER.instantiate()
	root.add_child(player)
	await process_frame
	check(player.rig != null and player.get_node_or_null(^"Sprite") == null, "The hero is drawn as the rig")
	check(player.rig.get_parent() == player.rig_view and player.rig_view.find_children("*", "SubViewport", true, false).is_empty(),
		"The rig is drawn straight into the world, with no view of its own")
	check(player.foot_marker.get_parent() == player.body and player.foot_marker.position == Vector2(0, player.SOLE_OFFSET), "Her shadow stays under her soles")
	check(player.get_child_count() == 1 and player.combat_visual.get_parent() == player, "The presentation's pivot is still her only child")
	for index in MioAnimation.FACINGS.size():
		player.facing = MioAnimation.FACINGS[index]
		check(player.rig.facing_name == MioAnimation.DIRECTIONS[index], "She faces %s" % MioAnimation.DIRECTIONS[index])
		await process_frame
		var hand: Node2D = player.rig.weapon_anchor()
		check(player.hand_follower.get_parent() == hand and player.weapon_visual.get_parent() == player.rig_view and player.weapon_visual.get_index() > player.rig.get_index() and player.weapon_visual.global_position.is_equal_approx(hand.global_position) and player.weapon_rest() == Vector2.ZERO,
			"The held picture follows her hand, drawn over her, facing %s" % MioAnimation.DIRECTIONS[index])
		check(is_zero_approx(player.weapon_visual.z_index), "The held picture lifts no z_index into the actors' y-sort")
	player.facing = Vector2i.DOWN
	# A step: the picture slides the last 8 px and the rig walks.
	player.play_step(Vector2i.RIGHT, 48)
	check(player.body.position == Vector2(-8, 0) and player.rig.rig.animation_player.current_animation == CharacterRig.WALK, "A step slides the picture in and walks")
	await create_timer(0.2).timeout
	check(player.body.position.is_zero_approx(), "The slide settles on the cell")
	await create_timer(0.6).timeout
	check(player.rig.rig.animation_player.current_animation == CharacterRig.IDLE, "The walk settles into the idle on its own")
	# The rig shows its own sword; another weapon is its painted icon.
	player.weapon = SWORD
	player.queue_redraw()
	await process_frame
	check(_sword_shown(player.rig, true), "A sword is the rig's own")
	player.weapon = SPEAR
	player.queue_redraw()
	await process_frame
	check(_sword_shown(player.rig, false), "Another weapon hides the rig's sword in every facing")
	player.weapon = SWORD
	player.queue_redraw()
	# The real presentation: the lunge is kept, the swing is the rig's.
	var presentation := BattlePresentation.new()
	root.add_child(presentation)
	var enemy = ENEMY.instantiate()
	enemy.stats = enemy.stats.duplicate()
	enemy.cell = Vector2i(0, 1)
	root.add_child(enemy)
	enemy.hp = 50
	var visible := {Vector2i.ZERO: true, Vector2i(0, 1): true}
	var events: Array[Dictionary] = [
		{"kind": "attack", "actor": player, "origin": Vector2i.ZERO, "direction": Vector2i.DOWN, "weapon": SWORD, "cells": [Vector2i(0, 1)]},
		{"kind": "hit", "actor": enemy, "origin": Vector2i(0, 1), "damage": 2, "dead": false, "source": player, "direction": Vector2i.DOWN}]
	presentation.present(events, player, visible, 48)
	await create_timer(0.07).timeout
	check(player.rig.rig.animation_player.current_animation == CharacterRig.ATTACK, "The presentation's attack plays the rig's swing")
	check(is_equal_approx(player.weapon_visual.global_rotation, player.rig.weapon_anchor().global_rotation), "The presentation leaves the held picture in her hand, unturned")
	check(not player.combat_visual.position.is_zero_approx(), "The presentation's lunge still moves her")
	if presentation.playing:
		await presentation.finished
	await process_frame
	check(player.combat_visual.position.is_zero_approx() and is_equal_approx(player.weapon_visual.global_rotation, player.rig.weapon_anchor().global_rotation), "Her pose recovers after the attack")
	# Fallen: she collapses and lies still.
	player.hp = 0
	presentation.collapse(player)
	await process_frame
	await process_frame
	check(player.rig.process_mode == Node.PROCESS_MODE_DISABLED, "A fallen hero's rig stops breathing")
	player.play_step(Vector2i.LEFT, 48)
	check(player.body.position == Vector2.ZERO, "A fallen hero takes no step")
	presentation.free()
	enemy.free()
	player.free()
	main.free()
	print("Player rig tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _sword_shown(rig: DirectionalRig, shown: bool) -> bool:
	for each: CharacterRig in rig._rigs.values():
		var sword := each.get_node_or_null(^"Parts/Sword") as CanvasItem
		if sword != null and sword.visible != shown:
			return false
	return true
