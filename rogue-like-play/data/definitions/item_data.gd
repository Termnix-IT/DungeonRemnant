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
@export var effect_id: StringName
@export var effect_amount: int = 0
## Zero lasts until the next floor; positive values count action turns.
@export_range(0, 1000) var effect_turns: int = 0
@export_range(0, 1000000) var sell_price: int = 0
@export_range(0, 1000000) var buy_price: int = 0


func stackable() -> bool:
	return kind == Kind.CONSUMABLE


static func from_weapon(value: WeaponData) -> ItemData:
	var item := ItemData.new()
	item.id = StringName("weapon_%d" % value.kind)
	item.display_name = value.display_name
	item.kind = Kind.WEAPON
	item.weapon = value
	item.sell_price = value.sell_price
	item.buy_price = value.buy_price
	return item


func description() -> String:
	if kind == Kind.WEAPON:
		var traits: Array[String] = ["基本射程 %d" % weapon.reach, "ダメージ補正 %+d" % weapon.damage_bonus]
		if weapon.sweeps_sides:
			traits.append("前方3方向")
		if weapon.knockback_distance > 0:
			traits.append("ノックバック %dマス" % weapon.knockback_distance)
		if weapon.pierces:
			traits.append("貫通")
		return "武器：%s / %s" % [display_name, " / ".join(traits)]
	if not effect_id.is_empty():
		var labels := {&"damage": "攻撃ダメージ +%d", &"defense": "防御 +%d", &"vision": "視界 +%d", &"regen": "毎ターンHP +%d", &"kill_heal": "撃破時HP +%d", &"gold": "獲得Gold +%d%%", &"exp": "獲得EXP +%d%%"}
		return "消費型アクセサリー：%s / %s / 同効果は重複不可" % [String(labels.get(effect_id, "%d")) % effect_amount, ("%dターン継続" % effect_turns) if effect_turns > 0 else "次の階まで継続"]
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
