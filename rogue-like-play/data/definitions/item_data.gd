class_name ItemData
extends Resource

enum Kind { WEAPON, ARMOR, ACCESSORY, CONSUMABLE }
@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.CONSUMABLE
@export var weapon: WeaponData
@export var max_hp_bonus: int = 0
@export var defense_bonus: int = 0
@export var vision_bonus: int = 0
@export var damage_bonus: int = 0
@export var heal_amount: int = 0


func stackable() -> bool:
	return kind == Kind.CONSUMABLE


static func from_weapon(value: WeaponData) -> ItemData:
	var item := ItemData.new()
	item.id = StringName("weapon_%d" % value.kind)
	item.display_name = value.display_name
	item.kind = Kind.WEAPON
	item.weapon = value
	return item


func description() -> String:
	if kind == Kind.WEAPON:
		return "武器：%s / 基本射程 %d" % [display_name, weapon.reach]
	if kind == Kind.CONSUMABLE:
		return "HPを%d回復（最大HPまで）" % heal_amount
	var effects: Array[String] = []
	if max_hp_bonus != 0:
		effects.append("最大HP +%d" % max_hp_bonus)
	if defense_bonus != 0:
		effects.append("防御 +%d" % defense_bonus)
	if vision_bonus != 0:
		effects.append("視界 +%d" % vision_bonus)
	if damage_bonus != 0:
		effects.append("武器ダメージ +%d" % damage_bonus)
	return " / ".join(effects)
