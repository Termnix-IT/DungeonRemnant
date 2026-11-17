class_name ProtoStatus
extends RefCounted

# The status for the three redesign prototypes. It asks the shipped page
# (HubStatus) itself for everything it tells, on a MetaProgress of its own
# that is never saved: which things each slot can hold and in what state,
# the account of the one under the cursor, what setting it would do, and her
# figures. An equip goes through the page's own rules and MetaProgress.equip,
# as Main applies it. So the three differ only in how they show it.

const SLOT_COUNT := 4
const RANKS := {
	"echo_lantern": 1, "sturdy_body": 2, "firm_guard": 1, "double_dash": 1, "learn_thunder_flash": 1,
	"learn_swallow_cut": 1, "learn_spear": 1, "quick_study": 1, "learn_echo_burst": 1,
}

# The shipped page, kept out of sight: the prototypes read its state.
var source: HubStatus
var meta: MetaProgress
# Her figures are open in full.
var figures_open := false
# The slots the last equip changed.
var changed: Array[int] = []
var _lists := {}


func _init(page: HubStatus) -> void:
	source = page
	source.equip_requested.connect(_apply)
	reset()


# A game part of the way through: three skills learned (two set), a second
# weapon, one special move.
func reset() -> void:
	meta = MetaProgress.new()
	meta.echo = 240
	meta.ranks = RANKS.duplicate()
	meta.loadout = [&"slam", &"thunder_flash"]
	meta.special = &"echo_burst"
	figures_open = false
	changed = []
	_lists.clear()
	source.slot = 1
	source.details_open = false
	source.refresh(meta)
	source.row = source._held_row()
	source._tell()


var slot: int:
	get:
		return source.slot

var row: int:
	get:
		return source.row


# What Main does with an equip the page asks for, without the saving.
func _apply(to: int, id: StringName) -> void:
	if meta.equip(to, id):
		changed = source._changing.duplicate()
		_lists.clear()
		source.refresh(meta)
		source.present_equip()


func slot_name(index: int) -> String:
	return tr(HubStatus.SLOTS[index][1])


# The key that uses the slot in a fight.
func slot_key(index: int) -> String:
	return tr(HubStatus.SLOTS[index][2])


# What a slot holds now: [emblem key, name], an empty key for none.
func slot_holds(index: int) -> Array:
	var id := source._slot_content(index)
	if id.is_empty() or id == &"special":
		return ["", tr("空き")]
	return [source._emblem_of(id), source._name_of(id)]


# A slot's index: {id, emblem, name, note, state, other} an entry.
func entries(index: int) -> Array:
	if not _lists.has(index):
		var open := source.slot
		source.slot = index
		source._list()
		_lists[index] = source.entries.duplicate(true)
		source.slot = open
		source._list()
	return _lists[index]


func row_of(id: StringName) -> int:
	return maxi(0, source.entry_ids().find(id))


# The account of the entry under the cursor (HubStatus._account).
func told() -> Dictionary:
	return source.told


# Whether the entry under the cursor is what the open slot holds.
func here() -> bool:
	var listed := entries(slot)
	return not listed.is_empty() and listed[clampi(row, 0, listed.size() - 1)].state == HubStatus.State.HERE


# The figures of what the open slot holds now, by their names.
func held_figures() -> Dictionary:
	var found := {}
	var id := source._slot_content(slot)
	if id.is_empty() or id == &"special":
		return found
	for figure: Array in source._account(id).figures:
		found[figure[0]] = figure[1]
	return found


# Her figures (HubStatus.stat_rows).
func stats() -> Array:
	return source.stat_rows()


func turn_to(index: int) -> bool:
	if index == slot and not figures_open:
		return false
	figures_open = false
	source.turn_to(index)
	return true


func move_to(index: int) -> bool:
	var before := row
	source.move_cursor(index)
	return row != before


# Sets the entry under the cursor in the open slot; false when refused.
func seal() -> bool:
	if figures_open:
		return false
	changed = []
	return source._equip(source.shown_id)


# Empties the open slot; false when refused.
func clear() -> bool:
	if figures_open:
		return false
	changed = []
	return source._equip(HubStatus.CLEAR_ID)
