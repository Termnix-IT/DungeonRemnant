class_name ProtoBuild
extends RefCounted

# The status page's data for the three redesign prototypes: her four slots,
# what each can hold, what a thing is and does, and her figures. It reads the
# game's own rules (MetaProgress) and words (HubStatus's account and figures,
# borrowed from a page that is never shown), so the prototypes tell exactly
# what the shipped page tells. It works on a MetaProgress of its own that is
# never saved: nothing here reaches the save file or the hub.

signal changed(slots: Array)

enum State { FREE, HERE, ELSEWHERE, UNKNOWN }

const ATTACK := 0
const SKILL_1 := 1
const SKILL_2 := 2
const SPECIAL := 3
const SLOT_NAMES := ["攻撃", "スキル1", "スキル2", "必殺技"]
const SLOT_KEYS := ["左クリック", "Q", "E", "R"]
const KIND_NAMES := ["武器", "スキル", "スキル", "必殺技"]
const CLEAR := &"clear"

var meta: MetaProgress
var _teller: HubStatus


func _init() -> void:
	meta = MetaProgress.new()
	for id: String in ["echo_lantern", "sturdy_body", "double_dash", "learn_thunder_flash", "learn_swallow_cut", "learn_spear"]:
		meta.ranks[id] = 1
	# One special learned, so the special slot can be shown both ways.
	for upgrade in MetaProgress.UPGRADES:
		if upgrade.effect == &"special_unlock" and upgrade.grants == &"echo_burst":
			meta.ranks[String(upgrade.id)] = 1
	meta.loadout = [&"slam", &"thunder_flash"] as Array[StringName]
	_teller = HubStatus.new()
	_teller.meta = meta
	_teller._base = load("res://data/hero/mio.tres")


func free_teller() -> void:
	if is_instance_valid(_teller):
		_teller.free()


# What a slot holds now ("" for none).
func content(slot: int) -> StringName:
	match slot:
		ATTACK:
			return meta.equipped_weapon().id
		SPECIAL:
			return meta.special if meta.owns_special(meta.special) else &""
	return meta.loadout[slot - 1]


static func emblem_of(id: StringName) -> String:
	var weapon := MetaProgress.find_weapon(id)
	if weapon != null:
		return weapon.emblem
	var move := MetaProgress.find_special(id)
	if move != null:
		return move.emblem
	var skill := MetaProgress.find_skill(id)
	return skill.emblem if skill != null else ""


func name_of(id: StringName) -> String:
	return _teller._name_of(id)


func owns(id: StringName) -> bool:
	return meta.owns_weapon(id) or meta.owns_skill(id) or meta.owns_special(id)


# The slot kind a thing belongs to: ATTACK, SKILL_1 (either skill slot) or SPECIAL.
static func home_of(id: StringName) -> int:
	if MetaProgress.find_weapon(id) != null:
		return ATTACK
	if MetaProgress.find_special(id) != null:
		return SPECIAL
	return SKILL_1


# The slot that holds a thing now, or -1.
func slot_holding(id: StringName) -> int:
	for slot in 4:
		if content(slot) == id and not id.is_empty():
			return slot
	return -1


# Everything a slot can hold, in the game's order: {id, emblem, name, note,
# state, other} a thing; `other` is the other slot holding it (ELSEWHERE).
func choices(slot: int) -> Array:
	var rows := []
	var things: Array = []
	match slot:
		ATTACK:
			for weapon in MetaProgress.WEAPONS:
				things.append([weapon.id, weapon.emblem, "%d連撃" % weapon.combo.size()])
		SPECIAL:
			for move in MetaProgress.SPECIALS:
				things.append([move.id, move.emblem, "ゲージ%s" % _teller._number(move.charge)])
		_:
			for skill in MetaProgress.SKILLS:
				things.append([skill.id, skill.emblem, "再使用 %s秒" % _teller._number(skill.cooldown)])
	for thing: Array in things:
		var id: StringName = thing[0]
		var state := State.FREE
		var other := slot_holding(id)
		if not owns(id):
			state = State.UNKNOWN
		elif other == slot:
			state = State.HERE
		elif other >= 0:
			state = State.ELSEWHERE
		rows.append({id = id, emblem = thing[1], name = name_of(id) if state != State.UNKNOWN else "？？？", note = thing[2] if state != State.UNKNOWN else "未習得", state = state, other = other})
	return rows


# What a thing is and does, told for a slot: HubStatus's account
# ({emblem, unknown, kind, name, description, figures, action, can, outcome}).
func account(slot: int, id: StringName) -> Dictionary:
	_teller.slot = slot
	return _teller._account(id if not id.is_empty() else &"")


# Whether a slot can be emptied now.
func can_clear(slot: int) -> bool:
	return slot != ATTACK and not content(slot).is_empty()


# Sets a thing in a slot (CLEAR empties it), by the game's own rule. Returns
# the slots whose content changed.
func equip(slot: int, id: StringName) -> Array:
	var before := [content(0), content(1), content(2), content(3)]
	var target := MetaProgress.WEAPON_SLOT if slot == ATTACK else (MetaProgress.SPECIAL_SLOT if slot == SPECIAL else slot - 1)
	if not meta.equip(target, &"" if id == CLEAR else id):
		return []
	var moved := []
	for index in 4:
		if content(index) != before[index]:
			moved.append(index)
	if not moved.is_empty():
		changed.emit(moved)
	return moved


# Her figures: [name, value, added by upgrades, breakdown, one of the main
# five, group (0 戦う力, 1 探索と成長)] a row.
func stats() -> Array:
	return _teller.stat_rows()


func main_stats() -> Array:
	return stats().filter(func(row: Array) -> bool: return row[4])
