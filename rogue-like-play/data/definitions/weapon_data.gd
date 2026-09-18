class_name WeaponData
extends Resource

enum Kind { SWORD, SPEAR, HAMMER, AXE, STAFF }
@export var kind: Kind = Kind.SWORD
@export var display_name: String = "剣"
@export_range(1, 12) var reach: int = 1
@export var damage_bonus: int = 0
@export var sweeps_sides: bool = false
@export_range(0, 4) var knockback_distance: int = 0
@export var pierces: bool = false
@export_range(0, 1000000) var sell_price: int = 0
@export_range(0, 1000000) var buy_price: int = 0

@export_range(0, 100) var mana_cost: int = 0
@export_range(0, 100) var spell_heal: int = 0
