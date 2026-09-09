class_name WeaponData
extends Resource

enum Kind { SWORD, SPEAR, HAMMER }
@export var kind: Kind = Kind.SWORD
@export var display_name: String = "剣"
@export_range(1, 12) var reach: int = 1
@export var damage_bonus: int = 0
@export var knockback: bool = false
@export var pierces: bool = false
