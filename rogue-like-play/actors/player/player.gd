extends Node2D

signal action_requested(kind: String, direction: Vector2i)
signal aim_changed

const BASE_SPRITE_POSITION := Vector2(0, -3)
const MOVE_VISUAL_OFFSET := 8.0
const MOVE_ANIMATION_DURATION := 0.12

@export var stats: ActorStats
@export_range(1, 20) var vision_range: int = 8
var hp: int
var mp: int
var cell := Vector2i.ZERO
var facing := Vector2i.RIGHT:
	set(value):
		facing = value
		_sync_sprite_direction()
		queue_redraw()
var input_enabled := true
var inventory := Inventory.new()
var active_effects := ActiveEffects.new()
var equipment := Equipment.new()
var equipment_effects := {"hp": 0, "defense": 0, "vision": 0, "damage": 0}
var weapon: WeaponData:
	get:
		return equipment.slots[Equipment.Slot.MAIN].weapon
	set(value):
		equipment.slots[Equipment.Slot.MAIN] = ItemData.from_weapon(value)
var aiming := false
var abilities := AbilitySystem.new()
var permanent_hp_bonus := 0
var move_tween: Tween
var combat_visual: Node2D
var idle_eyes: AnimatedSprite2D

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var weapon_visual: Node2D = $Sprite/Weapon
@onready var foot_marker: Node2D = $Sprite/FootMarker


func apply_permanent_hp(amount: int) -> void:
	stats.max_hp += amount - permanent_hp_bonus
	permanent_hp_bonus = amount
	hp = mini(hp, stats.max_hp)

const DIRECTIONS := {
	"move_n": Vector2i.UP, "move_ne": Vector2i(1, -1),
	"move_e": Vector2i.RIGHT, "move_se": Vector2i(1, 1),
	"move_s": Vector2i.DOWN, "move_sw": Vector2i(-1, 1),
	"move_w": Vector2i.LEFT, "move_nw": Vector2i(-1, -1),
}


func _ready() -> void:
	# Runtime growth must never mutate the shared definition Resource.
	stats = stats.duplicate()
	hp = stats.max_hp
	mp = stats.max_mp
	sprite.sprite_frames = MioAnimation.build_frame_set()
	idle_eyes = AnimatedSprite2D.new()
	idle_eyes.name = "IdleEyes"
	idle_eyes.sprite_frames = MioAnimation.build_front_idle_frames(true, true)
	idle_eyes.animation = &"idle_front"
	idle_eyes.centered = false
	idle_eyes.position = Vector2(-8, -6)
	sprite.add_child(idle_eyes)
	sprite.frame_changed.connect(func():
		if sprite.animation == &"idle_front":
			idle_eyes.set_frame_and_progress(sprite.frame, sprite.frame_progress)
	)
	sprite.position = BASE_SPRITE_POSITION
	combat_visual = Node2D.new()
	add_child(combat_visual)
	sprite.reparent(combat_visual, false)
	weapon_visual.draw.connect(_draw_weapon_silhouette)
	foot_marker.draw.connect(_draw_foot_marker)
	_sync_sprite_direction()


func play_step(direction: Vector2i, tile_size: int) -> void:
	if hp <= 0:
		return
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	var visual_direction := Vector2(direction).normalized()
	sprite.position = BASE_SPRITE_POSITION - visual_direction * minf(MOVE_VISUAL_OFFSET, tile_size * 0.25)
	_play_animation(&"walk")
	move_tween = create_tween()
	move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(sprite, "position", BASE_SPRITE_POSITION, MOVE_ANIMATION_DURATION)
	# Let the full walk cycle read without delaying logical turns or movement.
	var frames := sprite.sprite_frames
	var cycle_duration := frames.get_frame_count(sprite.animation) / frames.get_animation_speed(sprite.animation)
	move_tween.tween_interval(maxf(0.0, cycle_duration - MOVE_ANIMATION_DURATION))
	move_tween.finished.connect(reset_step)


func reset_step() -> void:
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	move_tween = null
	sprite.position = BASE_SPRITE_POSITION
	_play_animation(&"idle")
	if hp <= 0:
		sprite.stop()
	queue_redraw()


func gain_ability(ability: AbilityData) -> bool:
	if not abilities.upgrade(ability):
		return false
	match ability.effect:
		AbilityData.Effect.MAX_HP:
			stats.max_hp += ability.amount
			hp = mini(stats.max_hp, hp + ability.amount)
		AbilityData.Effect.ATTACK:
			stats.attack += ability.amount
		AbilityData.Effect.DEFENSE:
			stats.defense += ability.amount
		AbilityData.Effect.VISION:
			vision_range += ability.amount
	return true


func effective_weapon() -> WeaponData:
	var result: WeaponData = weapon.duplicate()
	var main: ItemData = equipment.slots[Equipment.Slot.MAIN]
	if weapon.kind == WeaponData.Kind.STAFF and main.socketed_scroll != null:
		result = main.socketed_scroll.weapon.duplicate()
	result.damage_bonus += int(equipment_effects.damage) + active_effects.amount(&"damage")
	match weapon.kind:
		WeaponData.Kind.SWORD:
			result.damage_bonus += abilities.total(AbilityData.Effect.SWORD_DAMAGE)
		WeaponData.Kind.SPEAR:
			result.damage_bonus += abilities.total(AbilityData.Effect.SPEAR_DAMAGE)
			result.reach += abilities.total(AbilityData.Effect.SPEAR_RANGE)
			result.pierces = result.pierces or abilities.total(AbilityData.Effect.SPEAR_PIERCE) > 0
		WeaponData.Kind.HAMMER:
			result.damage_bonus += abilities.total(AbilityData.Effect.HAMMER_DAMAGE)
	return result


func refresh_equipment_effects() -> void:
	var next := equipment.bonuses()
	next.defense += active_effects.amount(&"defense")
	next.vision += active_effects.amount(&"vision")
	stats.max_hp += int(next.hp) - int(equipment_effects.hp)
	stats.defense += int(next.defense) - int(equipment_effects.defense)
	vision_range += int(next.vision) - int(equipment_effects.vision)
	equipment_effects = next
	# Equipping extra maximum HP never provides free healing on repeated swaps.
	hp = mini(hp, stats.max_hp)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or hp <= 0 or event.is_echo():
		return
	if event.is_action_pressed("switch_weapon"):
		aiming = false
		action_requested.emit("switch", facing)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("attack"):
		if aiming:
			aiming = false
			action_requested.emit("attack", facing)
		else:
			aiming = true
		aim_changed.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cancel_attack") and aiming:
		aiming = false
		aim_changed.emit()
		get_viewport().set_input_as_handled()
		return
	for action: String in DIRECTIONS:
		if event.is_action_pressed(action):
			if aiming:
				facing = DIRECTIONS[action]
				queue_redraw()
				aim_changed.emit()
			else:
				action_requested.emit("move", DIRECTIONS[action])
			get_viewport().set_input_as_handled()
			return


func _draw() -> void:
	foot_marker.queue_redraw()
	weapon_visual.queue_redraw()


func _draw_foot_marker() -> void:
	var marker_color := Color("62d6cf") if hp > 0 else Color("59636b")
	foot_marker.draw_circle(Vector2.ZERO, 8, Color(0.0, 0.0, 0.0, 0.28))
	foot_marker.draw_arc(Vector2.ZERO, 8, 0, TAU, 24, Color(marker_color, 0.3), 1.0)


func _draw_weapon_silhouette() -> void:
	var direction := Vector2(facing).normalized()
	var side := Vector2(-direction.y, direction.x)
	# Side-facing weapons sit at hand height, not across the face.
	if direction.x < 0.0:
		side = -side
	var anchor := direction * 5.0 + side * (10.0 if facing.y < 0 else 6.0)
	var metal := Color("d9e4e8")
	var edge := Color("33414b")
	var handle := Color("8b633e")
	match weapon.kind:
		WeaponData.Kind.SWORD:
			weapon_visual.draw_line(anchor - direction * 3.0, anchor + direction * 4.0, handle, 3.0)
			weapon_visual.draw_line(anchor + direction * 3.0 - side * 3.0, anchor + direction * 3.0 + side * 3.0, edge, 2.0)
			weapon_visual.draw_line(anchor + direction * 4.0, anchor + direction * 15.0, edge, 5.0)
			weapon_visual.draw_line(anchor + direction * 4.0, anchor + direction * 15.0, metal, 2.0)
		WeaponData.Kind.SPEAR:
			weapon_visual.draw_line(anchor - direction * 4.0, anchor + direction * 18.0, edge, 4.0)
			weapon_visual.draw_line(anchor - direction * 4.0, anchor + direction * 18.0, handle, 2.0)
			var tip := anchor + direction * 20.0
			weapon_visual.draw_colored_polygon(PackedVector2Array([tip, tip - direction * 6.0 + side * 3.0, tip - direction * 6.0 - side * 3.0]), metal)
		WeaponData.Kind.STAFF:
			weapon_visual.draw_line(anchor - direction * 5, anchor + direction * 18, handle, 4)
			weapon_visual.draw_circle(anchor + direction * 18, 4, Color("bd9cff"))
		WeaponData.Kind.AXE:
			weapon_visual.draw_line(anchor - direction * 4, anchor + direction * 16, handle, 4)
			var head := anchor + direction * 12
			weapon_visual.draw_colored_polygon(PackedVector2Array([head - direction * 5, head + side * 9, head + direction * 5, head - side * 5]), metal)
		WeaponData.Kind.HAMMER:
			weapon_visual.draw_line(anchor - direction * 3.0, anchor + direction * 13.0, edge, 4.0)
			weapon_visual.draw_line(anchor - direction * 3.0, anchor + direction * 13.0, handle, 2.0)
			var head := anchor + direction * 13.0
			weapon_visual.draw_line(head - side * 5.0, head + side * 5.0, edge, 7.0)
			weapon_visual.draw_line(head - side * 4.0, head + side * 4.0, Color("aeb8bd"), 4.0)


func _sync_sprite_direction() -> void:
	if not is_node_ready():
		return
	weapon_visual.show_behind_parent = facing.y < 0
	weapon_visual.queue_redraw()
	var moving := move_tween != null and move_tween.is_valid() and move_tween.is_running()
	var motion: StringName = &"walk" if moving else &"idle"
	_play_animation(motion)


func _play_animation(motion: StringName) -> void:
	var animation := StringName("%s_%s" % [motion, MioAnimation.direction_name(facing)])
	var preserve_phase := String(sprite.animation).begins_with("%s_" % motion)
	var previous_frame := sprite.frame
	var previous_progress := sprite.frame_progress
	var previous_count := sprite.sprite_frames.get_frame_count(sprite.animation)
	sprite.play(animation)
	if preserve_phase:
		var next_count := sprite.sprite_frames.get_frame_count(animation)
		var next_phase := (previous_frame + previous_progress) * next_count / previous_count
		sprite.set_frame_and_progress(int(next_phase), fmod(next_phase, 1.0))
	sprite.scale = Vector2.ONE
	# The 64px sprite ends at row 60; align it to the existing foot marker.
	sprite.offset = Vector2(0, 1)
	# Compensate child transforms so weapons and floor markers keep world size.
	weapon_visual.position = Vector2(0, 3.0 / sprite.scale.y)
	weapon_visual.scale = Vector2.ONE * (1.5 / sprite.scale.x)
	foot_marker.position = Vector2(0, 29.0 / sprite.scale.y)
	foot_marker.scale = Vector2(1.0, 0.5) / sprite.scale
	idle_eyes.visible = animation == &"idle_front"
	if idle_eyes.visible:
		idle_eyes.set_frame_and_progress(sprite.frame, sprite.frame_progress)
