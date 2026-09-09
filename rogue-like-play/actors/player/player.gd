extends Node2D

signal action_requested(kind: String, direction: Vector2i)
signal aim_changed

@export var stats: ActorStats
@export_range(1, 20) var vision_range: int = 8
var hp: int
var cell := Vector2i.ZERO
var facing := Vector2i.RIGHT
var input_enabled := true
var inventory := Inventory.new()
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
	result.damage_bonus += int(equipment_effects.damage)
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
	stats.max_hp += int(next.hp) - int(equipment_effects.hp)
	stats.defense += int(next.defense) - int(equipment_effects.defense)
	vision_range += int(next.vision) - int(equipment_effects.vision)
	equipment_effects = next
	# Equipping extra maximum HP never provides free healing on repeated swaps.
	hp = mini(hp, stats.max_hp)


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
	draw_circle(Vector2.ZERO, 11, Color("62d6cf") if hp > 0 else Color("59636b"))
	draw_line(Vector2.ZERO, Vector2(facing) * 16, Color.WHITE, 3)
