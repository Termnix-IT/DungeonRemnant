extends Node2D

signal action_requested(kind: String, direction: Vector2i)
signal aim_changed

const MOVE_VISUAL_OFFSET := 8.0
const MOVE_ANIMATION_DURATION := 0.12
# She is drawn as the illustration rig (art/characters/mio_rig/mio_rig.tscn)
# held by a RigView. Her soles are SOLE_OFFSET below the cell's centre, on her
# shadow.
const MIO_RIG := preload("res://art/characters/mio_rig/mio_rig.tscn")
const SOLE_OFFSET := 25.0
const RIG_HEIGHT := 64.0
# The rig holds its own sword. Any other weapon is its kind's painted icon
# (ItemIcons.painted_weapon), so every spear (wooden or iron alike) shows the
# same one, HELD_SIZE world px square, standing upright in her hand, head up
# beside her as a spear or staff is carried; the icons lie with their tip at
# the top right, and GRIP is where her hand closes on one, as a share of its
# size: a fifth of the way up the shaft from the pommel.
const HELD_TURN := -PI * 0.25
const HELD_SIZE := 30.0
const GRIP := Vector2(0.21, 0.68)
const HELD_KINDS := [WeaponData.Kind.SPEAR, WeaponData.Kind.HAMMER, WeaponData.Kind.AXE, WeaponData.Kind.STAFF]

@export var stats: ActorStats
@export_range(1, 20) var vision_range: int = 8
var hp: int
var mp: int
var cell := Vector2i.ZERO
var facing := Vector2i.RIGHT:
	set(value):
		facing = value
		_sync_rig_direction()
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
# The body: the rig, the view that shows it, and the node a step slides (the
# picture and the shadow).
var rig: DirectionalRig
var rig_view: RigView
var body: Node2D
# Under the shown rig's hand bone, it places weapon_visual on the hand.
var hand_follower: RemoteTransform2D

@onready var weapon_visual: Node2D = $Weapon
@onready var foot_marker: Node2D = $FootMarker


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
	combat_visual = Node2D.new()
	add_child(combat_visual)
	weapon_visual.draw.connect(_draw_held_weapon)
	foot_marker.draw.connect(_draw_foot_marker)
	_build_rig()
	_sync_rig_direction()


func _build_rig() -> void:
	body = Node2D.new()
	body.name = "Body"
	combat_visual.add_child(body)
	foot_marker.reparent(body, false)
	foot_marker.position = Vector2(0, SOLE_OFFSET)
	foot_marker.scale = Vector2(1.0, 0.5)
	rig_view = RigView.new()
	rig_view.name = "RigView"
	rig_view.position = Vector2(0, SOLE_OFFSET)
	body.add_child(rig_view)
	rig = MIO_RIG.instantiate()
	rig.world_height = RIG_HEIGHT
	rig_view.setup(rig)
	weapon_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Loaded now, outside any draw call (see ItemIcons.painted_weapon).
	for kind in HELD_KINDS:
		ItemIcons.painted_weapon(kind)
	# Her hand is a bone, drawn before the parts, so what she holds is a later
	# sibling of the rig, drawn over her, that hand_follower keeps on the hand
	# (a z_index would lift it over the other actors' y-sort too).
	weapon_visual.reparent(rig_view, false)
	hand_follower = RemoteTransform2D.new()
	hand_follower.name = "HandFollower"


func _process(_delta: float) -> void:
	# Fallen, she lies still rather than breathing on the floor.
	if hp <= 0 and rig.process_mode != Node.PROCESS_MODE_DISABLED:
		rig.process_mode = Node.PROCESS_MODE_DISABLED


# The rig plays the swing itself, so the battle presentation keeps only its
# lunge and pose.
func play_attack(_weapon: WeaponData) -> bool:
	rig.attack()
	return true


func play_step(direction: Vector2i, tile_size: int) -> void:
	if hp <= 0:
		return
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	# The picture slides the last few pixels into the cell and the rig walks;
	# it ends its own stride, so the tween only clears itself.
	var visual_direction := Vector2(direction).normalized()
	body.position = -visual_direction * minf(MOVE_VISUAL_OFFSET, tile_size * 0.25)
	rig.step(visual_direction)
	move_tween = create_tween()
	move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.tween_property(body, "position", Vector2.ZERO, MOVE_ANIMATION_DURATION)
	move_tween.finished.connect(func(): move_tween = null)


func reset_step() -> void:
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	move_tween = null
	body.position = Vector2.ZERO
	rig.idle()
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
	# The rig draws its own sword; any other weapon is its painted icon.
	rig.set_part_shown(&"Sword", _held_kind() == WeaponData.Kind.SWORD)


func _held_kind() -> int:
	var held: ItemData = equipment.slots[Equipment.Slot.MAIN]
	return held.weapon.kind if held != null and held.weapon != null else -1


func _draw_foot_marker() -> void:
	var marker_color := Color("62d6cf") if hp > 0 else Color("59636b")
	foot_marker.draw_circle(Vector2.ZERO, 8, Color(0.0, 0.0, 0.0, 0.28))
	foot_marker.draw_arc(Vector2.ZERO, 8, 0, TAU, 24, Color(marker_color, 0.3), 1.0)


# The held icon with its grip on the weapon node's origin, her hand (which a
# mirrored facing already flips).
func _draw_held_weapon() -> void:
	var kind := _held_kind()
	if kind < 0 or kind == WeaponData.Kind.SWORD:
		return
	var picture := ItemIcons.painted_weapon(kind)
	if picture == null:
		return
	var area := Vector2.ONE * HELD_SIZE
	# The node takes the hand's whole transform, the rig's small scale with
	# it; HELD_SIZE is in world px.
	weapon_visual.draw_set_transform(Vector2.ZERO, HELD_TURN, Vector2.ONE / rig.rig.scale)
	weapon_visual.draw_texture_rect(picture, Rect2(-area * GRIP, area), false)


# The weapon node's place at rest in her hand, for the battle presentation.
func weapon_rest() -> Vector2:
	return Vector2.ZERO


# The rig turns to the facing (carrying its motion on), and the held icon
# follows the shown rig's hand.
func _sync_rig_direction() -> void:
	if not is_node_ready():
		return
	rig.facing = facing
	var hand := rig.weapon_anchor()
	if hand != null and hand_follower.get_parent() != hand:
		if hand_follower.get_parent() == null:
			hand.add_child(hand_follower)
		else:
			hand_follower.reparent(hand, false)
		hand_follower.remote_path = hand_follower.get_path_to(weapon_visual)
		hand_follower.force_update_cache()
	queue_redraw()
