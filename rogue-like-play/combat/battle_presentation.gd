extends Node2D

signal finished
signal impact(player_hit: bool)

const ENEMY := preload("res://actors/enemy/enemy.tscn")
const GameAudio := preload("res://audio/game_audio.gd")
const StrikeEffect := preload("res://combat/strike_effect.gd")
var playing := false
var timeline: Tween
var tweens: Array[Tween] = []
var touched: Array[Node2D] = []
var popup_serial := 0
var pending_events: Array[Dictionary] = []
var planned_duration := 0.0
var poses: Dictionary = {}


func _exit_tree() -> void:
	_stop_audio()


func _stop_audio() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null


func clear() -> void:
	_stop_audio()
	if timeline != null and timeline.is_valid():
		timeline.kill()
	for tween in tweens:
		if tween.is_valid():
			tween.kill()
	tweens.clear()
	poses.clear()
	for actor in touched:
		if is_instance_valid(actor):
			_reset_actor(actor)
	touched.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	playing = false
	pending_events.clear()
	planned_duration = 0.0


func _reset_actor(actor: Node2D) -> void:
	actor.modulate = Color.WHITE
	if actor.get("combat_visual") != null:
		actor.combat_visual.position = Vector2.ZERO
		actor.combat_visual.scale = Vector2.ONE
		actor.combat_visual.rotation = 0.0
		actor.weapon_visual.rotation = 0.0
		actor.weapon_visual.position = Vector2(0, 3.75)
	else:
		actor.visual_offset = Vector2.ZERO
		actor.visual_scale = Vector2.ONE
		actor.visual_rotation = 0.0


func present(events: Array[Dictionary], player: Node2D, visible_cells: Dictionary, tile_size: int) -> void:
	if events.is_empty():
		return
	if playing:
		pending_events.append_array(events)
		return
	tweens = tweens.filter(func(tween: Tween): return tween.is_valid())
	for index in range(touched.size() - 1, -1, -1):
		if not is_instance_valid(touched[index]):
			touched.remove_at(index)
	var at := 0.0
	var hit_at := 0.06
	var last_attacker: Node2D
	var scheduled := false
	var has_hit := false
	var positioned: Dictionary = {}
	var move_cells: Array[Vector2i] = []
	var move_actors: Array[Node2D] = []
	timeline = create_tween()
	timeline.set_parallel(true)
	for event in events:
		var actor: Node2D = event.actor
		if not is_instance_valid(actor):
			continue
		if actor != player and not visible_cells.has(event.origin) and not visible_cells.has(actor.cell):
			continue
		if actor != player and actor.hp > 0 and not positioned.has(actor):
			_track(actor)
			actor.visual_offset = Vector2((event.origin - actor.cell) * tile_size) / actor.scale
			positioned[actor] = true
		if event.kind == "move":
			if actor != player and actor.hp > 0:
				var destination: Vector2i = event.origin + event.direction
				var path: Array[Vector2i] = [event.origin, destination]
				if event.direction.x != 0 and event.direction.y != 0:
					path.append(event.origin + Vector2i(event.direction.x, 0))
					path.append(event.origin + Vector2i(0, event.direction.y))
				var intersects := actor in move_actors
				for cell in path:
					intersects = intersects or cell in move_cells
				# Only disjoint paths share time; followers and multi-step actors
				# retain their order, as do knockback and retaliation.
				if intersects:
					at += 0.12
					move_cells.clear()
					move_actors.clear()
				timeline.tween_callback(_step.bind(actor, event.origin, event.origin + event.direction, tile_size)).set_delay(at)
				move_cells.append_array(path)
				move_actors.append(actor)
				scheduled = true
			continue
		if not move_actors.is_empty():
			at += 0.12
			move_cells.clear()
			move_actors.clear()
		if event.kind == "attack":
			last_attacker = actor
			hit_at = at + _impact_delay(event.weapon)
			var effect_points: Array[Vector2] = []
			for cell: Vector2i in event.get("cells", []):
				if visible_cells.has(cell):
					effect_points.append(Vector2(cell * tile_size) + Vector2.ONE * tile_size / 2)
			timeline.tween_callback(_attack.bind(actor, event.direction, event.weapon)).set_delay(at)
			if not effect_points.is_empty():
				timeline.tween_callback(_effect.bind(_weapon_cue(event.weapon), effect_points, Vector2(event.direction))).set_delay(hit_at)
			at += 0.26
		else:
			has_hit = true
			if event.dead and actor != player:
				var ghost := ENEMY.instantiate()
				ghost.stats = actor.stats
				add_child(ghost)
				ghost.position = Vector2(event.origin * tile_size) + Vector2.ONE * tile_size / 2.0
				ghost.hp = 0
				ghost.facing = actor.facing
				ghost.scale = actor.scale
				event.actor = ghost
			# Turret hits have no melee attack event.
			var delay := hit_at
			if event.source != last_attacker:
				delay = maxf(delay, at)
				at = delay + 0.18
			timeline.tween_callback(_hit.bind(event, player, tile_size)).set_delay(delay)
			hit_at = delay
			scheduled = true
		scheduled = true
	if not scheduled:
		timeline.kill()
		return
	playing = true
	if not move_actors.is_empty():
		at += 0.12
	planned_duration = maxf(at + 0.04, hit_at + 0.3 if has_hit else 0.0)
	timeline.tween_interval(planned_duration)
	timeline.finished.connect(func():
		playing = false
		if not pending_events.is_empty():
			var next := pending_events.duplicate()
			pending_events.clear()
			present(next, player, visible_cells, tile_size)
			if playing:
				return
		finished.emit()
	)


func _step(actor: Node2D, origin: Vector2i, destination: Vector2i, tile_size: int) -> void:
	if not is_instance_valid(actor):
		return
	_track(actor)
	_pose(actor, Vector2(1.07, 0.92), 0.0, 0.12)
	actor.visual_offset = Vector2((origin - actor.cell) * tile_size) / actor.scale
	var tween := create_tween()
	tweens.append(tween)
	tween.tween_property(actor, "visual_offset", Vector2((destination - actor.cell) * tile_size) / actor.scale, 0.12).set_trans(Tween.TRANS_SINE)


func _attack(actor: Node2D, direction: Vector2i, weapon: WeaponData) -> void:
	if not is_instance_valid(actor):
		return
	if actor.has_method("reset_step"):
		actor.reset_step()
	_track(actor)
	GameAudio.play(self, &"magic" if _weapon_cue(weapon) == &"heal" else _weapon_cue(weapon))
	var vector := Vector2(direction).normalized()
	var visual: Node2D = actor.combat_visual if actor.get("combat_visual") != null else actor
	var property := "position" if visual != actor else "visual_offset"
	var tween := create_tween()
	tweens.append(tween)
	var baseline: Vector2 = visual.get(property)
	var anticipation := _impact_delay(weapon) - 0.04
	tween.tween_property(visual, property, baseline - vector * 4.0, anticipation)
	tween.tween_property(visual, property, baseline + vector * 9.0, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, property, baseline, 0.12)
	_pose(actor, Vector2(0.94, 1.05), vector.x * -0.08, _impact_delay(weapon) + 0.12)
	if weapon == null or actor.get("weapon_visual") == null:
		return
	var blade: Node2D = actor.weapon_visual
	var swing := create_tween()
	tweens.append(swing)
	if weapon.kind == WeaponData.Kind.SPEAR:
		blade.position = Vector2(0, 3.75) - vector * 5.0
		swing.tween_interval(anticipation)
		swing.tween_property(blade, "position", Vector2(0, 3.75) + vector * 15.0, 0.04)
		swing.tween_property(blade, "position", Vector2(0, 3.75), 0.12)
	else:
		blade.rotation = -1.0 if weapon.kind == WeaponData.Kind.SWORD else -1.6
		swing.tween_interval(anticipation)
		swing.tween_property(blade, "rotation", 0.8 if weapon.kind == WeaponData.Kind.SWORD else 0.35, 0.04)
		swing.tween_property(blade, "rotation", 0.0, 0.12)


func _hit(event: Dictionary, player: Node2D, tile_size: int) -> void:
	var actor: Node2D = event.actor
	if not is_instance_valid(actor):
		return
	GameAudio.play(self, &"hit")
	impact.emit(actor == player)
	var center := Vector2(event.origin * tile_size) + Vector2.ONE * tile_size / 2.0
	popup(str(event.damage), center + Vector2(0, -48), Color("ff8c8c") if actor == player else Color("fff0be"))
	if event.dead and actor != player:
		GameAudio.play(self, &"death", -20.0)
		popup("EXP +%d  Gold +%d" % [actor.stats.exp_reward, actor.stats.gold_reward], center + Vector2(0, 48), Color("f1d581"), 16)
	_track(actor)
	_effect(&"hit", [center], Vector2(event.direction))
	_pose(actor, Vector2(1.14, 0.85), signf(event.direction.x) * 0.12, 0.2, event.dead)
	var visual: Node2D = actor.combat_visual if actor.get("combat_visual") != null else actor
	var property := "position" if visual != actor else "visual_offset"
	var offset := Vector2(event.direction).normalized() * 7.0
	var baseline: Vector2 = visual.get(property)
	var tween := create_tween()
	tweens.append(tween)
	tween.tween_property(visual, property, baseline + offset, 0.045)
	tween.tween_property(visual, property, baseline, 0.12)
	actor.modulate = Color(1.8, 1.35, 1.35)
	var flash := create_tween()
	tweens.append(flash)
	flash.tween_property(actor, "modulate", Color.WHITE, 0.12)
	if event.dead and actor != player:
		flash.tween_property(actor, "modulate:a", 0.0, 0.18)
		flash.tween_callback(actor.queue_free)


func popup(text: String, center: Vector2, color: Color, font_size: int = 24) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("12141e"))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(320, 36)
	popup_serial += 1
	label.position = center - Vector2(160, 18) + Vector2((popup_serial % 3 - 1) * 8, 0)
	label.z_index = 30
	add_child(label)
	var tween := create_tween()
	tweens.append(tween)
	tween.tween_property(label, "position:y", label.position.y - 26, 0.65)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.4)
	tween.tween_callback(label.queue_free)
	return label


func _track(actor: Node2D) -> void:
	if not touched.has(actor):
		touched.append(actor)


static func _impact_delay(weapon: WeaponData) -> float:
	return 0.12 if weapon != null and weapon.kind == WeaponData.Kind.HAMMER else 0.09


static func _weapon_cue(weapon: WeaponData) -> StringName:
	if weapon == null:
		return &"slash"
	if weapon.spell_heal > 0:
		return &"heal"
	match weapon.kind:
		WeaponData.Kind.SPEAR: return &"thrust"
		WeaponData.Kind.HAMMER: return &"heavy"
		WeaponData.Kind.STAFF: return &"magic"
	return &"slash"


func _effect(kind: StringName, points: Array[Vector2], direction: Vector2) -> void:
	var effect := StrikeEffect.new()
	add_child(effect)
	effect.start(kind, points, direction)


func _pose(actor: Node2D, stretch: Vector2, tilt: float, duration: float, dead: bool = false) -> void:
	var old: Tween = poses.get(actor)
	if old != null and old.is_valid():
		old.kill()
	var visual: Node2D = actor.combat_visual if actor.get("combat_visual") != null else actor
	var scale_key := "scale" if visual != actor else "visual_scale"
	var rotation_key := "rotation" if visual != actor else "visual_rotation"
	var tween := create_tween().set_parallel(true)
	tweens.append(tween)
	poses[actor] = tween
	tween.tween_property(visual, scale_key, stretch, duration * 0.3)
	tween.tween_property(visual, rotation_key, tilt, duration * 0.3)
	tween.chain()
	tween.tween_property(visual, scale_key, Vector2(1.2, 0.25) if dead else Vector2.ONE, duration * 0.7)
	tween.tween_property(visual, rotation_key, tilt * 2 if dead else 0.0, duration * 0.7)
	tween.finished.connect(func(): poses.erase(actor))
