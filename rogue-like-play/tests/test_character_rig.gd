extends SceneTree

# The illustration rig PoC (Phase 1): the built front rig loads, keys what the
# game's timing needs, stays within its budget, ends every motion back on its
# idle, and keeps its origin on the soles. It touches no game state.

const RIG_SCENE := "res://art/characters/mio_rig/mio_rig_front.tscn"
const BattlePresentation := preload("res://combat/battle_presentation.gd")
const SWORD := preload("res://data/weapons/sword.tres")
# A budget that keeps thirty rigs on screen cheap.
const MAX_PARTS := 20
const MAX_BONES := 28
const MAX_VERTICES := 400
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
	var scene: PackedScene = load(RIG_SCENE)
	check(scene != null, "The front rig scene loads")
	if scene == null:
		quit(1)
		return
	var rig: CharacterRig = scene.instantiate()
	root.add_child(rig)
	await process_frame
	rig.set_process(false)
	var player := rig.animation_player
	for animation_name: StringName in [&"RESET", CharacterRig.IDLE, CharacterRig.WALK, CharacterRig.ATTACK]:
		check(player.has_animation(animation_name), "The rig has %s" % animation_name)
	var walk := player.get_animation(CharacterRig.WALK)
	check(is_equal_approx(walk.length, 0.4) and walk.loop_mode == Animation.LOOP_LINEAR, "The walk cycle keeps the hero's 0.4 s step")
	var attack := player.get_animation(CharacterRig.ATTACK)
	check(is_equal_approx(float(attack.get_meta(&"impact", -1.0)), BattlePresentation._impact_delay(SWORD)), "The sword lands when the presentation's hit does")
	check(player.get_animation(CharacterRig.IDLE).loop_mode == Animation.LOOP_LINEAR, "The idle loops")
	var tracks := {}
	for animation_name in player.get_animation_list():
		var animation := player.get_animation(animation_name)
		for index in animation.get_track_count():
			tracks[animation.track_get_path(index)] = true
	for animation_name in player.get_animation_list():
		check(player.get_animation(animation_name).get_track_count() == tracks.size(), "%s keys every animated bone" % animation_name)
	var bones := rig.find_children("*", "Bone2D", true, false)
	var parts := rig.get_node("Parts").get_children()
	var vertices := 0
	for part: Polygon2D in parts:
		vertices += part.polygon.size()
		check(part.get_bone_count() > 0 and part.skeleton != NodePath(), "%s is skinned to the skeleton" % part.name)
		check(part.z_index == 0, "%s draws in sibling order, leaking no z_index into the y-sort" % part.name)
	check(parts.size() <= MAX_PARTS and bones.size() <= MAX_BONES and vertices <= MAX_VERTICES,
		"The rig stays within budget (%d parts, %d bones, %d vertices)" % [parts.size(), bones.size(), vertices])
	check(rig.weapon_anchor() != null and rig.weapon_anchor().get_parent() is Bone2D, "The sword hangs from a hand bone")
	check(rig.eye_parts.size() == 3, "The rig blinks between three eye parts")
	_check_soles(rig, parts)
	rig.world_height = 64.0
	check(is_equal_approx(rig.global_scale.y * rig.figure_height, 64.0), "The figure stands 64 world px tall")
	# Steps in a row keep the stride; the walk ends on a half cycle.
	rig.step(Vector2.DOWN)
	_advance(rig, 0.2)
	rig.step(Vector2.DOWN)
	check(player.current_animation == CharacterRig.WALK, "A second step keeps walking")
	var left := rig._walk_left
	var finish := player.current_animation_position + left
	var remainder := fposmod(finish, 0.2)
	check(left >= 0.399 and (remainder < 0.001 or remainder > 0.199), "The walk stops with both feet under her")
	_advance(rig, left + 0.3)
	check(player.current_animation == CharacterRig.IDLE, "The walk settles into the idle")
	rig.attack()
	check(player.current_animation == CharacterRig.ATTACK, "The attack plays at once")
	_advance(rig, attack.length + 0.4)
	check(player.current_animation == CharacterRig.IDLE, "The attack returns to the idle")
	_check_idle_pose(rig)
	# Being placed on a new cell is not a swing: the hair must not whip.
	# A frame's change, so the swing still settling from the attack is not counted.
	_advance(rig, FRAME)
	var before := {}
	for bone: Bone2D in bones:
		before[bone] = bone.rotation
	rig.position += Vector2(48, 0)
	_advance(rig, FRAME)
	var largest := 0.0
	for bone: Bone2D in bones:
		if bone.get_meta(&"spring", false):
			largest = maxf(largest, absf(bone.rotation - before[bone]))
	check(largest < 0.02, "A jump to another cell leaves the springs calm (%.3f rad in a frame)" % largest)
	rig.free()
	print("Character rig tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _advance(rig: CharacterRig, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		rig.advance(FRAME)
		elapsed += FRAME


# The rig's origin is between her soles: the lowest drawn point is on it.
func _check_soles(rig: CharacterRig, parts: Array) -> void:
	var lowest := -INF
	for part: Polygon2D in parts:
		for point in part.polygon:
			lowest = maxf(lowest, point.y)
	# The layout trims each part to its pixels plus a small pad.
	check(lowest >= -1.0 and lowest <= 12.0, "Her soles are on the origin (lowest point %.1f)" % lowest)


# After any motion, the bones the idle does not key are back at rest.
func _check_idle_pose(rig: CharacterRig) -> void:
	var idle := rig.animation_player.get_animation(CharacterRig.IDLE)
	var moving := {}
	for index in idle.get_track_count():
		var keys := idle.track_get_key_count(index)
		var first: Variant = idle.track_get_key_value(index, 0)
		for key in keys:
			if idle.track_get_key_value(index, key) != first:
				moving[String(idle.track_get_path(index)).get_slice(":", 0)] = true
	for bone: Bone2D in rig.find_children("*", "Bone2D", true, false):
		if bone.get_meta(&"spring", false) or moving.has("Skeleton/" + String(rig.get_node("Skeleton").get_path_to(bone))):
			continue
		if bone.get_path() == rig.get_node(rig.lean_bone).get_path():
			continue
		check(absf(bone.rotation) < 0.002 and bone.position.is_equal_approx(bone.rest.origin), "%s is back at rest after the attack" % bone.name)
