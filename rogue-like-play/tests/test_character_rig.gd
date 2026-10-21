extends SceneTree

# The illustration rig PoC: every facing's built rig loads, keys what the
# game's timing needs (each swing of the combo, the slam, the held charge,
# the dash and the flinch), stays within its budget, ends every motion back
# on its idle and keeps its origin on the soles; a still copy keeps its pose;
# the eight facings resolve to drawn
# or mirrored rigs, a mirrored rig hides what a flip puts on the wrong side,
# and turning mid-stride carries the step on. It touches no game state.

const SET_SCENE := "res://art/characters/mio_rig/mio_rig.tscn"
# A budget that keeps thirty rigs on screen cheap.
const MAX_PARTS := 20
const MAX_BONES := 28
const MAX_VERTICES := 400
const FRAME := 1.0 / 60.0
# The hero's motions besides idle, walk and the plain swing.
const SWINGS: Array[StringName] = [&"attack_back", &"attack_heavy", &"attack_slam"]
const ONCE: Array[StringName] = [&"dash", CharacterRig.HURT]

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
	var set_scene: PackedScene = load(SET_SCENE)
	check(set_scene != null, "The hero's directional rig loads")
	if set_scene == null:
		quit(1)
		return
	var set_rig: DirectionalRig = set_scene.instantiate()
	check(set_rig.facing_scenes.has(&"front"), "The front is drawn")
	for facing_name: StringName in set_rig.facing_scenes:
		await _check_rig(facing_name, set_rig.facing_scenes[facing_name])
	root.add_child(set_rig)
	await process_frame
	_check_facings(set_rig)
	await _check_turn(set_rig)
	set_rig.free()
	print("Character rig tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check_rig(facing_name: StringName, scene: PackedScene) -> void:
	var rig: CharacterRig = scene.instantiate()
	root.add_child(rig)
	await process_frame
	rig.set_process(false)
	var player := rig.animation_player
	for animation_name: StringName in [&"RESET", CharacterRig.IDLE, CharacterRig.WALK, CharacterRig.ATTACK]:
		check(player.has_animation(animation_name), "%s has %s" % [facing_name, animation_name])
	var walk := player.get_animation(CharacterRig.WALK)
	check(is_equal_approx(walk.length, 0.4) and walk.loop_mode == Animation.LOOP_LINEAR, "%s walks the hero's 0.4 s step" % facing_name)
	var attack := player.get_animation(CharacterRig.ATTACK)
	var impact := float(attack.get_meta(&"impact", -1.0))
	check(impact > 0.0 and impact < attack.length, "%s's sword lands within its swing" % facing_name)
	check(player.get_animation(CharacterRig.IDLE).loop_mode == Animation.LOOP_LINEAR, "%s's idle loops" % facing_name)
	for swing in SWINGS:
		var motion := player.get_animation(swing) if player.has_animation(swing) else null
		var lands := float(motion.get_meta(&"impact", -1.0)) if motion != null else -1.0
		check(motion != null and lands > 0.0 and lands < motion.length and motion.loop_mode == Animation.LOOP_NONE, "%s has %s, its sword landing within it" % [facing_name, swing])
	for once in ONCE:
		check(player.has_animation(once) and player.get_animation(once).loop_mode == Animation.LOOP_NONE, "%s has %s" % [facing_name, once])
	check(player.has_animation(CharacterRig.BRACE) and player.get_animation(CharacterRig.BRACE).loop_mode == Animation.LOOP_LINEAR, "%s holds a looping charge stance" % facing_name)
	var tracks := {}
	for animation_name in player.get_animation_list():
		var animation := player.get_animation(animation_name)
		for index in animation.get_track_count():
			tracks[animation.track_get_path(index)] = true
	for animation_name in player.get_animation_list():
		check(player.get_animation(animation_name).get_track_count() == tracks.size(), "%s %s keys every animated bone" % [facing_name, animation_name])
	var bones := rig.find_children("*", "Bone2D", true, false)
	var parts := rig.get_node("Parts").get_children()
	var vertices := 0
	for part: Polygon2D in parts:
		vertices += part.polygon.size()
		check(part.get_bone_count() > 0 and part.skeleton != NodePath(), "%s %s is skinned to the skeleton" % [facing_name, part.name])
		check(part.z_index == 0, "%s %s draws in sibling order, leaking no z_index into the y-sort" % [facing_name, part.name])
	check(parts.size() <= MAX_PARTS and bones.size() <= MAX_BONES and vertices <= MAX_VERTICES,
		"%s stays within budget (%d parts, %d bones, %d vertices)" % [facing_name, parts.size(), bones.size(), vertices])
	check(rig.weapon_anchor() != null and rig.weapon_anchor().get_parent() is Bone2D, "%s's sword hangs from a hand bone" % facing_name)
	check(rig.eye_parts.size() == 3 or rig.eye_parts.is_empty(), "%s blinks between three eye parts or shows no eyes" % facing_name)
	_check_soles(facing_name, parts)
	rig.world_height = 64.0
	check(is_equal_approx(rig.global_scale.y * rig.figure_height, 64.0), "%s stands 64 world px tall" % facing_name)
	# Steps in a row keep the stride; the walk ends on a half cycle.
	rig.step(Vector2.DOWN)
	_advance(rig, 0.2)
	rig.step(Vector2.DOWN)
	check(player.current_animation == CharacterRig.WALK, "%s: a second step keeps walking" % facing_name)
	var left := rig._walk_left
	var remainder := fposmod(player.current_animation_position + left, 0.2)
	check(left >= 0.399 and (remainder < 0.001 or remainder > 0.199), "%s's walk stops with both feet under her" % facing_name)
	_advance(rig, left + 0.3)
	check(player.current_animation == CharacterRig.IDLE, "%s's walk settles into the idle" % facing_name)
	rig.attack()
	check(player.current_animation == CharacterRig.ATTACK, "%s's attack plays at once" % facing_name)
	_advance(rig, attack.length + 0.4)
	check(player.current_animation == CharacterRig.IDLE, "%s's attack returns to the idle" % facing_name)
	rig.attack(&"attack_heavy")
	check(player.current_animation == &"attack_heavy", "%s plays the swing it is asked for" % facing_name)
	rig.attack(&"no_such_swing")
	check(player.current_animation == CharacterRig.ATTACK, "%s falls back to the plain swing" % facing_name)
	_advance(rig, attack.length + 0.4)
	rig.braced = true
	_advance(rig, FRAME * 3)
	check(player.current_animation == CharacterRig.BRACE, "%s takes the charge stance while braced" % facing_name)
	rig.braced = false
	_advance(rig, 0.4)
	rig.dash(Vector2.RIGHT)
	check(player.current_animation == &"dash", "%s lunges on a dash" % facing_name)
	_advance(rig, 0.6)
	rig.hurt()
	check(player.current_animation == CharacterRig.HURT, "%s flinches when hurt" % facing_name)
	_advance(rig, 0.6)
	check(player.current_animation == CharacterRig.IDLE, "%s is back in the idle after them" % facing_name)
	_check_idle_pose(facing_name, rig)
	# An afterimage: a copy that keeps the pose it was copied in.
	rig.attack(&"attack_slam")
	_advance(rig, 0.12)
	var ghost := rig.duplicate() as CharacterRig
	ghost.frozen = true
	root.add_child(ghost)
	await process_frame
	var hand := rig.weapon_anchor().get_parent() as Bone2D
	var copied := ghost.get_node(rig.get_path_to(hand)) as Bone2D
	await create_timer(0.3).timeout
	check(not ghost.is_processing() and is_equal_approx(copied.rotation, hand.rotation), "%s's still copy keeps its pose" % facing_name)
	ghost.free()
	# The slam's swing in the hair settles before the next check.
	_advance(rig, 2.5)
	# Being placed on a new cell is not a swing: the hair must not whip. A
	# frame's change, so the swing still settling from the attack is not counted.
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
	check(largest < 0.02, "%s: a jump to another cell leaves the springs calm (%.3f rad in a frame)" % [facing_name, largest])
	rig.free()


func _check_facings(set_rig: DirectionalRig) -> void:
	var heights := {}
	for index in MioAnimation.DIRECTIONS.size():
		var facing_name := MioAnimation.DIRECTIONS[index]
		set_rig.facing = MioAnimation.FACINGS[index]
		var source: Array = set_rig.source_of(facing_name)
		check(set_rig.facing_name == facing_name and set_rig.rig == set_rig._rigs[source[0]], "%s shows its rig" % facing_name)
		var holder: Node2D = set_rig.rig.get_parent()
		check(holder.visible and (holder.scale.x < 0.0) == source[1] and set_rig.rig.mirrored == source[1], "%s is %s" % [facing_name, "mirrored" if source[1] else "drawn as is"])
		if DirectionalRig.MIRRORED.has(facing_name) and set_rig.facing_scenes.has(DirectionalRig.MIRRORED[facing_name]):
			check(source[1], "%s mirrors %s" % [facing_name, DirectionalRig.MIRRORED[facing_name]])
			# A drawn rig (not a one-piece placeholder) has the flower cut apart to hide.
			var drawn: bool = set_rig.rig.get_node_or_null(^"Parts/Whole") == null
			var hideable := set_rig.rig.find_children("*", "Polygon2D", true, false).any(func(part): return part.get_meta(&"mirror_hide", false))
			check(not drawn or hideable, "%s has the flower and ribbon apart, to hide when mirrored" % facing_name)
		for part in set_rig.rig.find_children("*", "Polygon2D", true, false):
			if part.get_meta(&"mirror_hide", false):
				check(part.visible != source[1], "%s %s shows only when not mirrored" % [facing_name, part.name])
		for other in set_rig._rigs.values():
			if other != set_rig.rig:
				check(not other.is_visible_in_tree() and not other.is_processing(), "%s leaves the other rigs hidden and idle" % facing_name)
		# A flipped parent shows up as a negative y scale in global_scale.
		heights[facing_name] = absf(set_rig.rig.global_scale.y) * set_rig.rig.figure_height
	for facing_name in heights:
		check(is_equal_approx(heights[facing_name], heights[&"front"]), "%s is as tall as the front" % facing_name)


# Turning mid-stride keeps the motion and its phase.
func _check_turn(set_rig: DirectionalRig) -> void:
	set_rig.facing = Vector2i.DOWN
	set_rig.step(Vector2.DOWN)
	_advance(set_rig.rig, 0.13)
	var position := set_rig.rig.animation_player.current_animation_position
	set_rig.facing = Vector2i(-1, -1)
	check(set_rig.rig.animation_player.current_animation == CharacterRig.WALK
		and is_equal_approx(set_rig.rig.animation_player.current_animation_position, position), "A turn mid-stride carries the step on")
	await process_frame


func _advance(rig: CharacterRig, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		rig.advance(FRAME)
		elapsed += FRAME


# The rig's origin is between her soles: the lowest drawn point is on it.
func _check_soles(facing_name: StringName, parts: Array) -> void:
	var lowest := -INF
	for part: Polygon2D in parts:
		for point in part.polygon:
			lowest = maxf(lowest, point.y)
	# The layout trims each part to its pixels plus a small pad.
	check(lowest >= -1.0 and lowest <= 12.0, "%s's soles are on the origin (lowest point %.1f)" % [facing_name, lowest])


# After any motion, the bones the idle does not key are back at rest.
func _check_idle_pose(facing_name: StringName, rig: CharacterRig) -> void:
	var idle := rig.animation_player.get_animation(CharacterRig.IDLE)
	var moving := {}
	for index in idle.get_track_count():
		var first: Variant = idle.track_get_key_value(index, 0)
		for key in idle.track_get_key_count(index):
			if idle.track_get_key_value(index, key) != first:
				moving[String(idle.track_get_path(index)).get_slice(":", 0)] = true
	var lean := rig.get_node(rig.lean_bone)
	for bone: Bone2D in rig.find_children("*", "Bone2D", true, false):
		if bone.get_meta(&"spring", false) or bone == lean or moving.has("Skeleton/" + String(rig.get_node("Skeleton").get_path_to(bone))):
			continue
		check(absf(bone.rotation) < 0.002 and bone.position.is_equal_approx(bone.rest.origin), "%s %s is back at rest after the attack" % [facing_name, bone.name])
