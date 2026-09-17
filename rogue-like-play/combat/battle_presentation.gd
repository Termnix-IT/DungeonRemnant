extends Node2D

signal finished

const ENEMY := preload("res://actors/enemy/enemy.tscn")
var playing := false
var timeline: Tween
var tweens: Array[Tween] = []
var touched: Array[Node2D] = []
var popup_serial := 0
var pending_events: Array[Dictionary] = []
var sound_cache: Dictionary = {}


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
	for actor in touched:
		if is_instance_valid(actor):
			_reset_actor(actor)
	touched.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	playing = false
	pending_events.clear()


func _reset_actor(actor: Node2D) -> void:
	actor.modulate = Color.WHITE
	if actor.get("combat_visual") != null:
		actor.combat_visual.position = Vector2.ZERO
		actor.weapon_visual.rotation = 0.0
		actor.weapon_visual.position = Vector2(0, 3.75)
	else:
		actor.visual_offset = Vector2.ZERO


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
	var positioned: Dictionary = {}
	timeline = create_tween()
	timeline.set_parallel(true)
	for event in events:
		var actor: Node2D = event.actor
		if not is_instance_valid(actor):
			continue
		if actor != player and not visible_cells.has(event.origin) and not visible_cells.has(actor.cell):
			continue
		if actor != player and actor.hp > 0 and not positioned.has(actor):
			actor.visual_offset = Vector2((event.origin - actor.cell) * tile_size) / actor.scale
			positioned[actor] = true
		if event.kind == "move":
			if actor != player and actor.hp > 0:
				timeline.tween_callback(_step.bind(actor, event.origin, event.origin + event.direction, tile_size)).set_delay(at)
				at += 0.12
				scheduled = true
			continue
		if event.kind == "attack":
			last_attacker = actor
			hit_at = at + 0.08
			timeline.tween_callback(_attack.bind(actor, event.direction, event.weapon)).set_delay(at)
			at += 0.26
		else:
			if event.dead and actor != player:
				var ghost := ENEMY.instantiate()
				ghost.stats = actor.stats
				add_child(ghost)
				ghost.position = Vector2(event.origin * tile_size) + Vector2.ONE * tile_size / 2.0
				ghost.hp = 0
				ghost.facing = actor.facing
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
	timeline.tween_interval(maxf(at + 0.04, hit_at + 0.3))
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
	sound(230 if weapon == null else {WeaponData.Kind.SWORD: 360, WeaponData.Kind.SPEAR: 500, WeaponData.Kind.HAMMER: 170, WeaponData.Kind.AXE: 210}.get(weapon.kind, 420))
	var vector := Vector2(direction).normalized()
	var visual: Node2D = actor.combat_visual if actor.get("combat_visual") != null else actor
	var property := "position" if visual != actor else "visual_offset"
	var tween := create_tween()
	tweens.append(tween)
	tween.tween_property(visual, property, vector * 9.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, property, Vector2.ZERO, 0.12)
	if weapon == null or actor.get("weapon_visual") == null:
		return
	var blade: Node2D = actor.weapon_visual
	var swing := create_tween()
	tweens.append(swing)
	if weapon.kind == WeaponData.Kind.SPEAR:
		blade.position = Vector2(0, 3.75) - vector * 5.0
		swing.tween_property(blade, "position", Vector2(0, 3.75) + vector * 15.0, 0.08)
		swing.tween_property(blade, "position", Vector2(0, 3.75), 0.12)
	else:
		blade.rotation = -1.0 if weapon.kind == WeaponData.Kind.SWORD else -1.6
		swing.tween_property(blade, "rotation", 0.8 if weapon.kind == WeaponData.Kind.SWORD else 0.35, 0.08)
		swing.tween_property(blade, "rotation", 0.0, 0.12)


func _hit(event: Dictionary, player: Node2D, tile_size: int) -> void:
	var actor: Node2D = event.actor
	if not is_instance_valid(actor):
		return
	sound(110)
	var center := Vector2(event.origin * tile_size) + Vector2.ONE * tile_size / 2.0
	popup(str(event.damage), center + Vector2(0, -48), Color("ff8c8c") if actor == player else Color("fff0be"))
	if event.dead and actor != player:
		popup("EXP +%d  Gold +%d" % [actor.stats.exp_reward, actor.stats.gold_reward], center + Vector2(0, 48), Color("f1d581"), 16)
	_track(actor)
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


func sound(frequency: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not sound_cache.has(frequency):
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var samples := PackedByteArray()
		samples.resize(2205 * 2)
		for index in 2205:
			var phase := float(index) / 2205.0
			var envelope := sin(phase * PI) * (1.0 - phase)
			samples.encode_s16(index * 2, int(sin(TAU * frequency * index / 22050.0) * envelope * 5000))
		stream.data = samples
		sound_cache[frequency] = stream
	var audio := AudioStreamPlayer.new()
	add_child(audio)
	audio.stream = sound_cache[frequency]
	audio.volume_db = -10.0
	audio.finished.connect(audio.queue_free)
	audio.play()
