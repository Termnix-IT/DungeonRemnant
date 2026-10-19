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
# Drawn as the illustration rig (art/characters/mio_rig/mio_rig.tscn) instead
# of the pixel sprite. The rig is drawn into its own SubViewport at the
# screen's resolution with pixel snap off, so its parts move smoothly while
# the project snaps everything else (the floor's pixel art) to pixels; the
# picture is then placed in the world as one sprite. Her soles are
# SOLE_OFFSET below the cell's centre, on her shadow, as the sprite's are.
const MIO_RIG := preload("res://art/characters/mio_rig/mio_rig.tscn")
const SOLE_OFFSET := 25.0
const RIG_HEIGHT := 64.0
# The world px around her soles the rig's picture covers: the beret, a sword
# raised overhead and swung out to either side.
const RIG_BOX := Rect2(-60, -100, 120, 128)
# A held pixel picture (no illustrated weapon yet for its kind) stands upright
# in the rig's hand, head up beside her, as a spear or staff is carried; the
# pictures lie with their tip at the top right.
const RIG_HELD_TURN := -PI * 0.25

@export var stats: ActorStats
# Off draws her as the pixel sprite, as before the rig.
@export var illustrated := true
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
# The illustrated body: the rig, the SubViewport it is drawn in, the sprite
# showing that picture, and the node a step slides (the picture and shadow).
var rig: DirectionalRig
var rig_view: SubViewport
var rig_display: Sprite2D
var body: Node2D
var _rig_holder: Node2D

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
	if illustrated:
		_build_rig()
	set_process(illustrated)
	_sync_sprite_direction()


func _build_rig() -> void:
	sprite.visible = false
	sprite.stop()
	body = Node2D.new()
	body.name = "Body"
	combat_visual.add_child(body)
	foot_marker.reparent(body, false)
	foot_marker.position = Vector2(0, SOLE_OFFSET)
	foot_marker.scale = Vector2(1.0, 0.5)
	rig_view = SubViewport.new()
	rig_view.name = "RigView"
	rig_view.transparent_bg = true
	rig_view.snap_2d_transforms_to_pixel = false
	rig_view.snap_2d_vertices_to_pixel = false
	rig_view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	body.add_child(rig_view)
	_rig_holder = Node2D.new()
	rig_view.add_child(_rig_holder)
	rig = MIO_RIG.instantiate()
	rig.world_height = RIG_HEIGHT
	_rig_holder.add_child(rig)
	rig_display = Sprite2D.new()
	rig_display.name = "RigDisplay"
	rig_display.centered = false
	rig_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rig_display.texture = rig_view.get_texture()
	body.add_child(rig_display)
	weapon_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Its hand is a bone, drawn before the parts; like the sprite's, what she
	# holds is drawn over her. The rig's view is its own canvas, so this
	# z_index never reaches the world's y-sort.
	weapon_visual.z_index = 1
	_fit_rig_view()


func _process(_delta: float) -> void:
	_fit_rig_view()
	# Fallen, she lies still rather than breathing on the floor.
	if hp <= 0 and rig.process_mode != Node.PROCESS_MODE_DISABLED:
		rig.process_mode = Node.PROCESS_MODE_DISABLED


# Draws the rig at the screen's own scale (camera zoom and window stretch),
# so its picture lands on the screen one texel per pixel.
func _fit_rig_view() -> void:
	if not is_inside_tree():
		return
	var screen_scale := absf((get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale().y)
	if screen_scale <= 0.0:
		return
	var size := Vector2i((RIG_BOX.size * screen_scale).ceil())
	if rig_view.size != size:
		rig_view.size = size
	# The rig's origin is her soles; the box is measured from them.
	_rig_holder.position = -RIG_BOX.position * screen_scale
	_rig_holder.scale = Vector2.ONE * screen_scale
	rig_display.position = Vector2(0, SOLE_OFFSET) + RIG_BOX.position
	rig_display.scale = Vector2.ONE / screen_scale


# The rig plays the swing itself, so the battle presentation keeps only its
# lunge and pose; false hands the swing back to it (the pixel sprite).
func play_attack(_weapon: WeaponData) -> bool:
	if not illustrated:
		return false
	rig.attack()
	return true


func play_step(direction: Vector2i, tile_size: int) -> void:
	if hp <= 0:
		return
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	var visual_direction := Vector2(direction).normalized()
	if illustrated:
		_play_rig_step(visual_direction, tile_size)
		return
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
	if illustrated:
		body.position = Vector2.ZERO
		rig.idle()
		queue_redraw()
		return
	sprite.position = BASE_SPRITE_POSITION
	_play_animation(&"idle")
	if hp <= 0:
		sprite.stop()
	queue_redraw()


# The picture slides the last few pixels into the cell, as the sprite does,
# and the rig walks; it ends its own stride, so the tween only clears itself.
func _play_rig_step(direction: Vector2, tile_size: int) -> void:
	body.position = -direction * minf(MOVE_VISUAL_OFFSET, tile_size * 0.25)
	rig.step(direction)
	move_tween = create_tween()
	move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(body, "position", Vector2.ZERO, MOVE_ANIMATION_DURATION)
	move_tween.finished.connect(func(): move_tween = null)


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
	if illustrated:
		# The rig draws its own sword; any other weapon is its pixel picture.
		rig.set_part_shown(&"Sword", _held_kind() == WeaponData.Kind.SWORD)


func _held_kind() -> int:
	var held: ItemData = equipment.slots[Equipment.Slot.MAIN]
	return held.weapon.kind if held != null and held.weapon != null else -1


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
	if illustrated:
		if held.weapon.kind == WeaponData.Kind.SWORD:
			return
		# In the rig's hand, which a mirrored facing already flips.
		weapon_visual.draw_set_transform(Vector2.ZERO, RIG_HELD_TURN)
		weapon_visual.draw_texture(picture, -grip)
		return
	var mirrored: bool = HANDS[MioAnimation.direction_name(facing)].x < 0.0
	if mirrored:
		weapon_visual.draw_set_transform(Vector2(grip.x, -grip.y), 0.0, Vector2(-1, 1))
	else:
		weapon_visual.draw_set_transform(-grip)
	weapon_visual.draw_texture(picture, Vector2.ZERO)


# The weapon node's place at rest, for the battle presentation's swings.
func weapon_rest() -> Vector2:
	return _weapon_rest


# The rig turns to the facing (carrying its motion on), and the held pixel
# picture moves to the shown rig's hand at the world's size.
func _sync_rig_direction() -> void:
	rig.facing = facing
	var hand := rig.weapon_anchor()
	if hand != null and weapon_visual.get_parent() != hand:
		weapon_visual.reparent(hand, false)
	weapon_visual.position = Vector2.ZERO
	weapon_visual.rotation = 0.0
	weapon_visual.scale = Vector2.ONE / rig.rig.scale
	_weapon_rest = Vector2.ZERO
	queue_redraw()


func _sync_sprite_direction() -> void:
	if not is_node_ready():
		return
	weapon_visual.queue_redraw()
	if illustrated:
		_sync_rig_direction()
		return
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
