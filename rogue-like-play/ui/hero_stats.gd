class_name HeroStats
extends Control

# The right of the hub's screens that weigh goods (the shop, the equipment, the
# departure check): the open hall, with no figure laid over it, so what the
# background shows of the place (the merchant's counter, the weapon rack)
# stays in sight. The next run's stats are built here and handed to the
# page's middle column (move_stats_to), beside the action they weigh. show_stats
# gives them before and after a change, the changed ones in green or red with
# an arrow.

const STATS := [["hp", "最大HP"], ["attack", "攻撃力"], ["defense", "防御力"], ["reach", "射程"]]

var specs: StatBars
var swap_label: Label
# Lent to a page's middle column (move_stats_to): only a change shows there.
var lent := false
var _stack: VBoxContainer
var _unchanged: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	var stack := VBoxContainer.new()
	_stack = stack
	stack.theme_type_variation = &"CompactStack"
	add_child(stack)
	HubUI.label(stack, "次の冒険の能力", &"NoteLabel")
	swap_label = HubUI.label(stack, "", &"NoteLabel")
	_unchanged = HubUI.label(stack, "能力は変わらない", &"BodyLabel")
	_unchanged.visible = false
	specs = StatBars.new()
	# No bars: gear has no fixed ceiling, so a bar's length could only be
	# measured against her own value and would say nothing about its size.
	specs.bars = false
	stack.add_child(specs)


# What goods would change belongs beside the action that buys or wears them,
# not in the screen's far corner: the stats go to parent at index, show
# only the rows that change, and hide while nothing is compared. With always
# (the departure check) all four rows stay.
func move_stats_to(parent: Control, index: int, always := false) -> void:
	_stack.reparent(parent, false)
	parent.move_child(_stack, index)
	# A page whose decision is the stats themselves (the departure check)
	# keeps all four rows in view instead of only what changes.
	if always:
		return
	lent = true
	specs.changed_only = true
	_stack.visible = false


# Her stats as they are, or before and after a change; swap names the slot
# and what she wears there now, or is empty.
func show_stats(before: Dictionary, after: Dictionary = {}, swap: String = "") -> void:
	swap_label.text = swap
	swap_label.visible = not swap.is_empty()
	var shown := []
	for stat: Array in STATS:
		var next: int = after.get(stat[0], before[stat[0]])
		shown.append([stat[1], before[stat[0]], next, 0])
	specs.show_rows(shown)
	if lent:
		_stack.visible = not swap.is_empty()
		_unchanged.visible = _stack.visible and not specs.visible


# The swap line for wearing goods in a slot.
static func swap_text(slot: int, current: ItemData) -> String:
	return "%sと入れ替え（今：%s）" % [Equipment.SLOT_NAMES[slot], current.label() if current != null else "なし"]
