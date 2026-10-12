extends Node2D

signal action_requested(kind: String, direction: Vector2i)
signal aim_changed

const BASE_SPRITE_POSITION := Vector2(0, -3)
const MOVE_VISUAL_OFFSET := 8.0
const MOVE_ANIMATION_DURATION := 0.12
# The weapon she holds is its kind's picture, so a sword reads as a sword at a
# glance and every sword (wooden or iron alike) shows the same one. The
# pictures are the item icons shrunk to her sprite's pixel density
# (tools/build_held_weapons.py), each lying grip at the bottom left, tip at the
# top right.
const HELD := {
	WeaponData.Kind.SWORD: preload("res://art/characters/held/sword.png"),
	WeaponData.Kind.SPEAR: preload("res://art/characters/held/spear.png"),
	WeaponData.Kind.HAMMER: preload("res://art/characters/held/hammer.png"),
	WeaponData.Kind.AXE: preload("res://art/characters/held/axe.png"),
	WeaponData.Kind.STAFF: preload("res://art/characters/held/staff.png"),
}
# Where her hand closes on a picture, as a share of its size: a fifth of the
# way up the shaft from the pommel.
const GRIP := Vector2(0.21, 0.68)
# Her hand in each facing's frame, from the frame's centre: ahead of her in
# the side views, at her side from the front and from the back. The weapon is
# held up and outward, so a hand on the left mirrors the picture. It is drawn
# over her even from the back, where her wide hair would hide it, so what she
# holds always shows.
const HANDS := {
	&"front": Vector2(-8, 12), &"back": Vector2(13, 12),
	&"left": Vector2(-11, 12), &"right": Vector2(11, 12),
	&"front_left": Vector2(-7, 12), &"front_right": Vector2(7, 12),
	&"back_left": Vector2(-13, 12), &"back_right": Vector2(13, 12),
}

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
# Where the weapon rests in the sprite: her hand, after the facing's shift.
var _weapon_rest := Vector2.ZERO

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
	return weapon_with(equipment.slots[Equipment.Slot.MAIN], int(equipment_effects.damage))


# The attack the player would have with this Main item and equipment damage
# total; effective_weapon() is the current case, previews ask about others.
func weapon_with(main: ItemData, equipment_damage: int) -> WeaponData:
	var base: WeaponData = main.weapon
	var result: WeaponData = base.duplicate()
	if base.kind == WeaponData.Kind.STAFF and main.socketed_scroll != null:
		result = main.socketed_scroll.weapon.duplicate()
	result.damage_bonus += equipment_damage + active_effects.amount(&"damage")
	match base.kind:
		WeaponData.Kind.SWORD:
			result.damage_bonus += abilities.total(AbilityData.Effect.SWORD_DAMAGE)
		WeaponData.Kind.SPEAR:
			result.damage_bonus += abilities.total(AbilityData.Effect.SPEAR_DAMAGE)
			result.reach += abilities.total(AbilityData.Effect.SPEAR_RANGE)
			result.pierces = result.pierces or abilities.total(AbilityData.Effect.SPEAR_PIERCE) > 0
		WeaponData.Kind.HAMMER:
			result.damage_bonus += abilities.total(AbilityData.Effect.HAMMER_DAMAGE)
	return result


# Read-only preview of the values equipment changes, for a hypothetical gear
# set. Level-up abilities and active effects are kept exactly as they are now.
func stats_with(gear: Equipment) -> Dictionary:
	var bonus := gear.bonuses()
	var attack_weapon := weapon_with(gear.slots[Equipment.Slot.MAIN], int(bonus.damage))
	return {
		"hp": stats.max_hp - int(equipment_effects.hp) + int(bonus.hp),
		"attack": stats.attack + attack_weapon.damage_bonus,
		"defense": stats.defense - int(equipment_effects.defense) + int(bonus.defense) + active_effects.amount(&"defense"),
		"reach": attack_weapon.reach,
		"vision": vision_range - int(equipment_effects.vision) + int(bonus.vision) + active_effects.amount(&"vision"),
	}


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


# The held picture with its grip on the weapon node's origin, her hand, so an
# attack's swing turns it about the hand.
func _draw_weapon_silhouette() -> void:
	var held: ItemData = equipment.slots[Equipment.Slot.MAIN]
	if held == null or held.weapon == null:
		return
	var picture: Texture2D = HELD.get(held.weapon.kind)
	if picture == null:
		return
	var size := picture.get_size()
	var grip := size * GRIP
	var mirrored: bool = HANDS[MioAnimation.direction_name(facing)].x < 0.0
	if mirrored:
		weapon_visual.draw_set_transform(Vector2(grip.x, -grip.y), 0.0, Vector2(-1, 1))
	else:
		weapon_visual.draw_set_transform(-grip)
	weapon_visual.draw_texture(picture, Vector2.ZERO)


# The weapon node's place at rest, for the battle presentation's swings.
func weapon_rest() -> Vector2:
	return _weapon_rest


func _sync_sprite_direction() -> void:
	if not is_node_ready():
		return
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
	# Her boots stand on the shadow: each direction's picture moves sideways
	# by its measured shift (MioAnimation.foot_shift), and the sword she holds
	# moves with her; the shadow stays at the tile's centre.
	var direction := MioAnimation.direction_name(facing)
	var shift := MioAnimation.foot_shift(direction)
	sprite.offset = Vector2(shift, 0)
	# Compensate child transforms so weapons and floor markers keep world size;
	# the weapon sits in her hand, which moves with the picture.
	_weapon_rest = (Vector2(shift, 0) + HANDS[direction]) / sprite.scale
	weapon_visual.position = _weapon_rest
	weapon_visual.scale = Vector2.ONE / sprite.scale
	weapon_visual.queue_redraw()
	# The 64px frame's soles are on row 60, 28px below its centre: the shadow
	# is centred on them, half under the boots and half before them.
	foot_marker.position = Vector2(0, 28.0 / sprite.scale.y)
	foot_marker.scale = Vector2(1.0, 0.5) / sprite.scale
