extends Node2D

signal finished
signal impact(player_hit: bool)

const ENEMY := preload("res://actors/enemy/enemy.tscn")
const GameAudio := preload("res://audio/game_audio.gd")
const StrikeEffect := preload("res://combat/strike_effect.gd")
# Presentation-only freeze on heavy moments. Logic is already resolved, and
# Engine.time_scale is untouched so audio, UI and timers keep running.
const HIT_STOP_TIME := 0.05
const DAMAGE_FONT_SIZE := 30
const DEATH_SMOKE_DELAY := 0.12
const ITEM_POPUP_ICON := 36.0
const ITEM_POPUP_FONT_SIZE := 16
const ITEM_POPUP_POP := 0.22
const ITEM_POPUP_RISE := 40.0
const ITEM_POPUP_TIME := 0.9
# Damage the hero takes reads hotter and larger than damage dealt; a killing
# blow is the largest. Each keeps a dark outline in its own hue.
const DEALT_COLOR := Color("ffe9b0")
const DEALT_OUTLINE := Color("241606")
const KILL_COLOR := Color("ffc94d")
const TAKEN_COLOR := Color("ff5a4e")
const TAKEN_OUTLINE := Color("2e0707")
var playing := false
var timeline: Tween
var tweens: Array[Tween] = []
var touched: Array[Node2D] = []
var popup_serial := 0
var pending_events: Array[Dictionary] = []
var planned_duration := 0.0
var poses: Dictionary = {}
# Damage the player has taken in rules but not yet seen land. The HUD adds it
# back so HP drops together with each hit.
var pending_player_damage := 0


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
	pending_player_damage = 0
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
		_hold_frame(actor, -1)


# Only sprite enemies hold frames; the hero and drawn bodies ignore this.
func _hold_frame(actor: Node2D, frame: int) -> void:
	if is_instance_valid(actor) and actor.get("pose_frame") != null:
		actor.pose_frame = frame


func present(events: Array[Dictionary], player: Node2D, visible_cells: Dictionary, tile_size: int) -> void:
	if events.is_empty():
		return
	for event in events:
		if event.kind == "hit" and event.actor == player:
			pending_player_damage += int(event.damage)
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
				timeline.tween_callback(_effect.bind(_effect_kind(event.weapon), effect_points, Vector2(event.direction))).set_delay(hit_at)
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
		pending_player_damage = 0
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
			# Already counted when the events were queued.
			var queued_damage := pending_player_damage
			present(next, player, visible_cells, tile_size)
			pending_player_damage = queued_damage if playing else 0
			if playing:
				return
		pending_player_damage = 0
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
	_hold_frame(actor, EnemySprites.FRAME_WIND_UP)
	tween.tween_property(visual, property, baseline - vector * 4.0, anticipation)
	tween.tween_callback(_hold_frame.bind(actor, EnemySprites.FRAME_STRIKE))
	tween.tween_property(visual, property, baseline + vector * 9.0, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, property, baseline, 0.12)
	tween.tween_callback(_hold_frame.bind(actor, -1))
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
	if actor == player:
		pending_player_damage = maxi(0, pending_player_damage - int(event.damage))
	impact.emit(actor == player)
	var center := Vector2(event.origin * tile_size) + Vector2.ONE * tile_size / 2.0
	var taken: bool = actor == player
	var color := TAKEN_COLOR if taken else (KILL_COLOR if event.dead else DEALT_COLOR)
	var font_size := DAMAGE_FONT_SIZE + (4 if taken or event.dead else 0)
	var damage := popup(str(event.damage), center + Vector2(0, -48), color, font_size, TAKEN_OUTLINE if taken else DEALT_OUTLINE)
	damage.pivot_offset = damage.size * 0.5
	damage.scale = Vector2.ONE * (1.55 if taken else 1.35)
	var punch := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tweens.append(punch)
	punch.tween_property(damage, "scale", Vector2.ONE, 0.14)
	if event.dead and actor != player:
		GameAudio.play(self, &"death", -20.0)
		# Smoke rises as the defeated enemy drops and fades.
		var smoke := create_tween()
		tweens.append(smoke)
		var smoke_at: Array[Vector2] = [center]
		smoke.tween_callback(_effect.bind(&"death", smoke_at, Vector2(event.direction))).set_delay(DEATH_SMOKE_DELAY)
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
	_hold_frame(actor, EnemySprites.FRAME_HURT)
	var sprite_death: bool = event.dead and actor != player and actor.has_method("has_sprite") and actor.has_sprite()
	tween.tween_property(visual, property, baseline + offset, 0.045)
	# A defeated sprite drops to its down frame as the recoil peaks, so the
	# fall is seen before the fade instead of a flinch dissolving away.
	if sprite_death:
		tween.tween_callback(_hold_frame.bind(actor, -1))
	tween.tween_property(visual, property, baseline, 0.12)
	tween.tween_callback(_hold_frame.bind(actor, -1))
	actor.modulate = Color(1.8, 1.35, 1.35)
	var flash := create_tween()
	tweens.append(flash)
	flash.tween_property(actor, "modulate", Color.WHITE, 0.12)
	if event.dead and actor != player:
		if sprite_death:
			flash.tween_interval(0.16)
		flash.tween_property(actor, "modulate:a", 0.0, 0.22 if sprite_death else 0.18)
		flash.tween_callback(actor.queue_free)
	if actor == player or event.dead:
		hit_stop()


# Pauses every running presentation tween, including the ones this hit just
# started, so the flash and damage number hold for a beat.
func hit_stop(duration: float = HIT_STOP_TIME) -> void:
	var frozen: Array[Tween] = []
	for tween: Tween in [timeline] + tweens:
		if tween != null and tween.is_valid() and tween.is_running():
			tween.pause()
			frozen.append(tween)
	if frozen.is_empty() or not is_inside_tree():
		return
	get_tree().create_timer(duration).timeout.connect(func():
		for tween in frozen:
			if tween.is_valid():
				tween.play())


func popup(text: String, center: Vector2, color: Color, font_size: int = 24, outline: Color = Color("12141e")) -> Label:
	var label := _popup_label(text, color, font_size, outline)
	popup_serial += 1
	label.position = center - label.size * 0.5 + Vector2((popup_serial % 3 - 1) * 8, 0)
	label.z_index = 30
	add_child(label)
	var tween := create_tween()
	tweens.append(tween)
	tween.tween_property(label, "position:y", label.position.y - 26, 0.65)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.4)
	tween.tween_callback(label.queue_free)
	return label


# A picked-up item pops out of the floor as its icon with its name beneath,
# rises and fades: the pickup reads as the thing gained, not a log sentence.
func item_popup(item: ItemData, text: String, center: Vector2, color: Color) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.z_index = 30
	holder.position = center
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = Vector2.ONE * ITEM_POPUP_ICON
	icon.position = Vector2(-ITEM_POPUP_ICON * 0.5, -ITEM_POPUP_ICON - 4)
	icon.draw.connect(func(): ItemGlyph.paint(icon, Rect2(Vector2.ZERO, icon.size), item, Color.WHITE))
	holder.add_child(icon)
	var label := _popup_label(text, color, ITEM_POPUP_FONT_SIZE, Color("12141e"))
	label.position = Vector2(-label.size.x * 0.5, 0)
	holder.add_child(label)
	add_child(holder)
	holder.scale = Vector2.ONE * 0.5
	var tween := create_tween()
	tweens.append(tween)
	tween.tween_property(holder, "scale", Vector2.ONE, ITEM_POPUP_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(holder, "position:y", center.y - ITEM_POPUP_RISE, ITEM_POPUP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(holder, "modulate:a", 0.0, 0.3).set_delay(ITEM_POPUP_TIME - 0.3)
	tween.tween_callback(holder.queue_free)
	return holder


func _popup_label(text: String, color: Color, font_size: int, outline: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", 8 if font_size >= DAMAGE_FONT_SIZE else 5)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(320, font_size + 12)
	return label


# The hero sinks to the floor and dims after the killing blow. Presentation
# only: the run has already ended and the result is saved.
func collapse(actor: Node2D) -> void:
	if not is_instance_valid(actor) or actor.get("combat_visual") == null:
		return
	var old: Tween = poses.get(actor)
	if old != null and old.is_valid():
		old.kill()
	_track(actor)
	var visual: Node2D = actor.combat_visual
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tweens.append(tween)
	tween.tween_property(visual, "rotation", -1.35 * (1.0 if actor.facing.x <= 0 else -1.0), 0.45)
	tween.tween_property(visual, "position", Vector2(0, 10), 0.45)
	tween.tween_property(actor, "modulate", Color(0.62, 0.52, 0.58), 0.6)


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


# The effect an attack plays: a staff shows its spell (bolt, flame wave or
# heal) or, without one, the sword-like swing it makes.
static func _effect_kind(weapon: WeaponData) -> StringName:
	if weapon != null and weapon.kind == WeaponData.Kind.STAFF:
		if weapon.mana_cost == 0:
			return &"slash"
		if weapon.spell_heal > 0:
			return &"heal"
		return &"flame" if weapon.sweeps_sides else &"magic"
	return _weapon_cue(weapon)


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
	# Drawn bodies flatten to show death; sprites have their own down frame.
	var flatten: bool = dead and not (actor.has_method("has_sprite") and actor.has_sprite())
	tween.tween_property(visual, scale_key, Vector2(1.2, 0.25) if flatten else Vector2.ONE, duration * 0.7)
	tween.tween_property(visual, rotation_key, tilt * 2 if flatten else 0.0, duration * 0.7)
	tween.finished.connect(func(): poses.erase(actor))
