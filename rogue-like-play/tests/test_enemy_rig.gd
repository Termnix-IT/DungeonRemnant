extends SceneTree

# An enemy with an illustration rig (the wandering sentinel): it is drawn
# through its RigView instead of its strip, faces the way it looks, follows
# the presentation's offset, swings, flinches and falls on its cues, stops
# when out of sight, keeps its health bar over its head, and the strip is
# still one switch away. Enemies without a rig keep their strip.

const ENEMY := preload("res://actors/enemy/enemy.tscn")
const BASIC := preload("res://data/enemies/basic_enemy.tres")
const FAST := preload("res://data/enemies/fast_enemy.tres")
const TURRET := preload("res://data/enemies/turret_enemy.tres")
const BOSS := preload("res://data/enemies/boss.tres")
# Each named boss's display name, as EnemySprites maps them.
const MESH_ENEMIES := [
	"proximity", "fast", "charge", "summoner", "turret",
	"boss_stone_gate", "boss_gale_warden", "boss_cannon_watcher", "boss_summoning_priest", "boss_ruin_king",
	"boss_root_warden", "boss_gale_wolf_king", "boss_spore_cannon", "boss_swarm_lord", "boss_ancient_tree_king"]
const BattlePresentation := preload("res://combat/battle_presentation.gd")
const FRAME := 1.0 / 60.0

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
	var sentinel: Node2D = _enemy(BASIC)
	await process_frame
	check(sentinel.rig != null and sentinel.rig_view != null and sentinel.has_sprite(), "The sentinel is drawn as its rig")
	var view: SubViewport = sentinel.rig_view.viewport
	check(not view.snap_2d_transforms_to_pixel and sentinel.rig_view.show_behind_parent, "Its rig is drawn unsnapped, behind the facing arrow and health bar")
	# The rig lives in its view's space; in the enemy's (scaled) space it is
	# world_height tall.
	check(is_equal_approx(sentinel.rig.world_height * sentinel.scale.y, 60.0) and is_equal_approx(sentinel.rig_height(), 60.0), "It stands 60 world px tall, as its rig says")
	sentinel.facing = Vector2i.RIGHT
	sentinel.visual_offset = Vector2.ZERO
	check(sentinel.rig_view.scale.x > 0.0, "Facing right shows the rig as drawn")
	sentinel.facing = Vector2i.LEFT
	sentinel.visual_offset = Vector2(3, 0)
	check(sentinel.rig_view.scale.x < 0.0 and sentinel.rig_view.position == Vector2(3, 0) + sentinel.SOLE, "Facing left mirrors it, and it follows the presentation's offset")
	check(sentinel._health_bar_top() < sentinel.SOLE.y - sentinel.rig_height() / sentinel.scale.x + 1.0, "The health bar stays over its head")
	var motion: AnimationPlayer = sentinel.rig.animation_player
	for animation_name: StringName in [CharacterRig.IDLE, CharacterRig.WALK, CharacterRig.ATTACK, CharacterRig.HURT, CharacterRig.DOWN]:
		check(motion.has_animation(animation_name), "The sentinel has %s" % animation_name)
	check(is_equal_approx(float(motion.get_animation(CharacterRig.ATTACK).get_meta(&"impact", -1.0)), BattlePresentation._impact_delay(null)),
		"Its blow lands when the presentation's hit does")
	# The presentation's cues.
	check(sentinel.play_attack(null) and motion.current_animation == CharacterRig.ATTACK, "Its attack is the rig's swing")
	_advance(sentinel.rig, 0.8)
	sentinel.pose_frame = EnemySprites.FRAME_HURT
	check(motion.current_animation == CharacterRig.HURT, "A hit makes it flinch")
	sentinel.pose_frame = -1
	_advance(sentinel.rig, 0.6)
	check(motion.current_animation == CharacterRig.IDLE, "It recovers into the idle")
	sentinel.play_walk(Vector2i.LEFT)
	check(motion.current_animation == CharacterRig.WALK, "A step walks it")
	_advance(sentinel.rig, 0.8)
	sentinel.hp = 0
	sentinel.pose_frame = EnemySprites.FRAME_HURT
	sentinel.pose_frame = -1
	check(motion.current_animation == CharacterRig.DOWN, "A killing blow makes it fall")
	sentinel.pose_frame = EnemySprites.FRAME_HURT
	check(motion.current_animation == CharacterRig.DOWN, "Once fallen it does not flinch up again")
	# Out of sight, its rig stops.
	sentinel.hp = sentinel.stats.max_hp
	sentinel.visible = false
	check(sentinel.rig.process_mode == Node.PROCESS_MODE_DISABLED, "Out of sight its rig stops")
	sentinel.visible = true
	check(sentinel.rig.process_mode == Node.PROCESS_MODE_INHERIT, "Back in sight it moves again")
	sentinel.free()
	# The real presentation cues a walk, the swing and the fall.
	var presentation := BattlePresentation.new()
	root.add_child(presentation)
	var walker: Node2D = _enemy(BASIC)
	walker.cell = Vector2i(1, 0)
	await process_frame
	var hero := Node2D.new()
	root.add_child(hero)
	var seen := {Vector2i(1, 0): true, Vector2i(2, 0): true}
	presentation.present([{"kind": "move", "actor": walker, "origin": Vector2i(2, 0), "direction": Vector2i.LEFT}] as Array[Dictionary], hero, seen, 48)
	await create_timer(0.05).timeout
	check(walker.rig.animation_player.current_animation == CharacterRig.WALK, "The presentation's step walks the rig")
	if presentation.playing:
		await presentation.finished
	# Out of the finished signal before the presentation goes.
	await process_frame
	presentation.free()
	walker.free()
	hero.free()
	# Every other enemy is one bent picture, at its strip's size, with the
	# motions the presentation cues and a brace for its warning turns.
	await _check_meshes()
	# Without a rig (the unnamed fallback boss), or switched off, the strip
	# or the drawn body stays.
	var fallback: Node2D = _enemy(BOSS)
	check(fallback.rig == null and EnemySprites.visual_id(fallback.stats) == "boss", "An enemy without a rig keeps its own drawing")
	fallback.free()
	var plain: Node2D = ENEMY.instantiate()
	plain.stats = BASIC.duplicate()
	plain.illustrated = false
	root.add_child(plain)
	check(plain.rig == null and not plain.has_node(^"RigView"), "The strip is one switch away")
	plain.free()
	print("Enemy rig tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check_meshes() -> void:
	var names := {}
	for display_name: String in EnemySprites.BOSS_IDS:
		names[EnemySprites.BOSS_IDS[display_name]] = display_name
	for id: String in MESH_ENEMIES:
		check(ResourceLoader.exists(_rig_path(id)), "%s has a rig" % id)
		var stats := _stats_for(id, names)
		if stats == null:
			check(false, "%s has enemy data to try it with" % id)
			continue
		var enemy: Node2D = _enemy(stats)
		await process_frame
		check(enemy.rig != null and EnemySprites.visual_id(enemy.stats) == id, "%s is drawn as its rig" % id)
		if enemy.rig == null:
			enemy.free()
			continue
		var strip_height := EnemySprites.body_height(EnemySprites.sheet_for(enemy.stats)) * EnemySprites.WORLD_SCALE
		check(is_equal_approx(enemy.rig_height(), strip_height), "%s keeps its strip's height (%.0f world px)" % [id, strip_height])
		for animation_name: StringName in [CharacterRig.IDLE, CharacterRig.WALK, CharacterRig.ATTACK, CharacterRig.HURT, CharacterRig.DOWN, CharacterRig.BRACE]:
			check(enemy.rig.animation_player.has_animation(animation_name), "%s has %s" % [id, animation_name])
		var box: Rect2 = enemy.rig_view.box
		check(box.has_point(enemy.SOLE * 0.0) and box.size.y * enemy.scale.y >= strip_height, "%s's view holds its whole figure" % id)
		enemy.free()
	# A turret taking aim holds its brace until it fires.
	var turret: Node2D = _enemy(TURRET)
	await process_frame
	turret.shot_direction = Vector2i.LEFT
	turret._process(FRAME)
	turret.rig.advance(FRAME)
	check(turret.rig.animation_player.current_animation == CharacterRig.BRACE, "A turret taking aim braces")
	turret.shot_direction = Vector2i.ZERO
	turret._process(FRAME)
	check(turret.rig.animation_player.current_animation == CharacterRig.IDLE, "It eases back once the shot is gone")
	turret.free()


func _rig_path(id: String) -> String:
	return "res://art/enemies/rig/%s_rig.tscn" % id


# Enemy data whose visual id is this one: a named boss by its display name,
# the others from their own data.
func _stats_for(id: String, boss_names: Dictionary) -> EnemyStats:
	if boss_names.has(id):
		var stats: EnemyStats = BOSS.duplicate()
		stats.display_name = boss_names[id]
		return stats
	for path in ["basic_enemy", "proximity_enemy", "fast_enemy", "charge_enemy", "summoner_enemy", "turret_enemy"]:
		var stats: EnemyStats = (load("res://data/enemies/%s.tres" % path) as EnemyStats).duplicate()
		if EnemySprites.visual_id(stats) == id:
			return stats
	return null


func _enemy(stats: EnemyStats) -> Node2D:
	var enemy: Node2D = ENEMY.instantiate()
	enemy.stats = stats.duplicate()
	root.add_child(enemy)
	return enemy


func _advance(rig: CharacterRig, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		rig.advance(FRAME)
		elapsed += FRAME
