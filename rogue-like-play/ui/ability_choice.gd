extends CanvasLayer

signal selected(id: StringName)
# The cards on offer are to be drawn again (the owner spends a reroll and
# presents the new ones).
signal reroll_requested
# The cards were looked at and left untaken (only a hand shown as one that
# may be declined: an event's, seen before its price is paid).
signal declined

const GameAudio := preload("res://audio/game_audio.gd")
# The cards are dealt before they can be taken, as card games deal a hand:
# the shade falls, then each card rises into its place in turn, dimmed, and
# only once the last has landed are they armed (they brighten, the key
# guide comes up and the first card takes the focus). Until then no click,
# number key or confirm picks one, so the swings mashed when the level came
# cannot take a card unseen; a mouse button still held when they arm must
# be let go first. The fight's own keys and buttons (attack, dash, skills,
# special move) double as the confirm (Space, A) and the reroll (R, Y), so
# they pick nothing and reroll nothing until all of them have rested for
# REST: a dash still being mashed when the cards arm takes no card. The
# number keys, Enter and the directions are free at once. On a gamepad the D-pad or the left stick moves between
# the cards (round from the last to the first) and A takes the focused one;
# with no card focused, a direction focuses one. Three cards, or four with
# the lasting upgrade; with rerolls left, R (Y) asks for the cards to be
# drawn again (a new hand, dealt and armed the same way).
# Under the keys stands what the choice is made by: her health, and the
# boons the build already holds with their ranks. The shade over the fight
# dims the HUD's own.
# No window holds the hand: as card games lay a hand on the table, the title,
# the cards and their keys float over the darkened field, so the deal and the
# cards themselves are what the eye meets. The cards are as tall as their
# words need.
const SHADE_TIME := 0.16
const DEAL_TIME := 0.24
const DEAL_STAGGER := 0.09
const DEAL_RISE := 90.0
# How dim a card waits before the hand is armed.
const UNARMED_TINT := Color(0.62, 0.62, 0.62, 1.0)
const PICK_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
# The fight's actions, and how long (seconds, real time) they must all have
# been let be before one of them counts as a pick or a reroll.
const FIGHT_ACTIONS: Array[StringName] = [&"strike", &"dash", &"skill_1", &"skill_2", &"special"]
const REST := 0.3

var offers: Array[BoonData] = []
var _levels: Array[int] = []
var cards: Array[AbilityCard] = []
# Plays the chosen moment after the dialog has already closed, so the turn
# resumes immediately. It never receives input and replaces itself.
var afterglow: CanvasLayer
var key_guide: KeyGuide
var pick_hint: Button
var reroll_hint: Button
var rerolls := 0
# Whether this hand may be left untaken (Esc, B), and the hint that says so.
var declinable := false
var decline_hint: Button
# Her health and the boons held, under the keys (show_vitals, _show_held).
const HELD_SIZE := 36.0
const HELD_PER_ROW := 16
var status_row: HBoxContainer
var hp_caption: Label
var hp_label: Label
var held_row: HFlowContainer
# Whether the hand on offer can be taken yet, and whether the mouse waits for
# a button held through the deal to be let go.
var armed := false
var _mouse_held := false
# Above zero: the fight's actions have not rested yet (resting()).
var _rest_left := 0.0
var _rest_clock := 0
@onready var panel: PanelContainer = $Panel
@onready var shade: ColorRect = $Shade
@onready var buttons: Array[Button] = [$Panel/Margin/Stack/Choices/First, $Panel/Margin/Stack/Choices/Second, $Panel/Margin/Stack/Choices/Third, $Panel/Margin/Stack/Choices/Fourth]


func _ready() -> void:
	hide()
	# Key caps under the cards rather than an instruction sentence.
	key_guide = KeyGuide.new()
	key_guide.alignment = BoxContainer.ALIGNMENT_CENTER
	key_guide.custom_minimum_size.y = 40
	$Panel/Margin/Stack.add_child(key_guide)
	key_guide.add_hint("← / →", "◀ / ▶", "カード")
	pick_hint = key_guide.add_hint("1・2・3", "A", "選ぶ")
	reroll_hint = key_guide.add_hint("R", "Y", "", _reroll)
	reroll_hint.hide()
	decline_hint = key_guide.add_hint("Esc", "B", "やめる", _decline)
	decline_hint.hide()
	status_row = HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel/Margin/Stack.add_child(status_row)
	hp_caption = HubUI.label(status_row, "HP", &"HpCaption")
	hp_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	hp_label = HubUI.label(status_row, "", &"HudValue")
	hp_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	held_row = HFlowContainer.new()
	held_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_row.add_child(held_row)
	show_vitals(-1, 0)
	for index in buttons.size():
		var card := AbilityCard.new()
		buttons[index].add_child(card)
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cards.append(card)
		buttons[index].pressed.connect(_select.bind(index))
		buttons[index].mouse_entered.connect(_hover.bind(index, true))
		buttons[index].mouse_exited.connect(_hover.bind(index, false))
		buttons[index].focus_mode = Control.FOCUS_ALL
		buttons[index].focus_entered.connect(_hover.bind(index, true))
		buttons[index].focus_exited.connect(_hover.bind(index, false))


# A level-up's boons, at the ranks the build holds. `title` replaces the
# level-up title (an area's reward); `rerolls_left` above 0 offers a reroll.
# Her health, told under the cards from the next hand on (below zero: not told).
func show_vitals(hp: int, max_hp: int) -> void:
	hp_caption.visible = hp >= 0
	hp_label.visible = hp >= 0
	hp_label.text = "%d / %d" % [hp, max_hp]


# The boons the build holds, as their emblems with their ranks.
func _show_held(build: BuildState) -> void:
	for child in held_row.get_children():
		child.free()
	var owned := build.owned()
	held_row.custom_minimum_size.x = mini(owned.size(), HELD_PER_ROW) * (HELD_SIZE + held_row.get_theme_constant(&"h_separation"))
	for boon in owned:
		var icon := TextureRect.new()
		icon.texture = EmblemIcons.texture(boon.emblem)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2.ONE * HELD_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		held_row.add_child(icon)
		if boon.max_level > 1:
			var rank := HubUI.label(icon, str(build.rank(boon.id)), &"HudCaption")
			rank.autowrap_mode = TextServer.AUTOWRAP_OFF
			rank.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			rank.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			rank.grow_vertical = Control.GROW_DIRECTION_BEGIN
	status_row.visible = hp_label.visible or not owned.is_empty()


func present_boons(candidates: Array[BoonData], build: BuildState, level: int, pending: int, title: String = "", rerolls_left: int = 0, may_decline: bool = false) -> void:
	_show_held(build)
	declinable = may_decline
	decline_hint.visible = may_decline
	var levels: Array[int] = []
	for boon in candidates:
		levels.append(build.rank(boon.id))
	rerolls = rerolls_left
	reroll_hint.text = "引き直す（残り%d）" % rerolls
	reroll_hint.visible = rerolls > 0
	_open(candidates, levels, level, pending)
	if not title.is_empty():
		$Panel/Margin/Stack/Title.text = title


func _open(candidates: Array[BoonData], levels: Array[int], level: int, pending: int) -> void:
	clear_afterglow()
	offers = candidates.duplicate()
	_levels = levels
	$Panel/Margin/Stack/Title.text = "Lv %d　強化を1つ選ぶ" % (level - pending + 1)
	var keys: Array[String] = []
	for index in offers.size():
		keys.append(str(index + 1))
	$Panel/Margin/Stack/Hint.text = "このあと、もう%d回選べます" % (pending - 1)
	$Panel/Margin/Stack/Hint.visible = pending > 1
	pick_hint.set_meta(&"keys", "・".join(keys))
	key_guide.refresh()
	for index in buttons.size():
		buttons[index].visible = index < offers.size()
		if index < offers.size():
			cards[index].setup(offers[index], _levels[index], index + 1)
	# Left from the first card goes round to the last, and back.
	for index in offers.size():
		buttons[index].focus_neighbor_left = buttons[posmod(index - 1, offers.size())].get_path()
		buttons[index].focus_neighbor_right = buttons[posmod(index + 1, offers.size())].get_path()
		buttons[index].focus_neighbor_top = buttons[index].get_path()
		buttons[index].focus_neighbor_bottom = buttons[index].get_path()
	# A container grows to fit but never shrinks on its own, so fit the
	# dialog to the cards on offer and keep it centred.
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	show()
	UIMotion.of(panel).reveal(UIMotion.WINDOW_TIME)
	for index in offers.size():
		UIMotion.of(cards[index]).enter(index * UIMotion.STAGGER_TIME)
	_deal()


# How long a hand of `count` takes to be dealt, from opening to armed.
static func arm_time(count: int) -> float:
	return SHADE_TIME + DEAL_STAGGER * maxi(0, count - 1) + DEAL_TIME


func _deal() -> void:
	armed = false
	_mouse_held = false
	_rest_left = REST
	_rest_clock = Time.get_ticks_msec()
	for button in buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.release_focus()
	shade.modulate.a = 0.0
	var fall := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fall.tween_property(shade, "modulate:a", 1.0, SHADE_TIME)
	key_guide.modulate.a = 0.0
	for index in offers.size():
		cards[index].self_modulate = UNARMED_TINT
		UIMotion.of(cards[index]).enter(SHADE_TIME + index * DEAL_STAGGER, Vector2(0, DEAL_RISE), DEAL_TIME)
	# On the cards' own clock, so a slow frame that holds the deal back holds
	# the arming back with it: no card is ever armed before it is in sight.
	var arming := create_tween()
	arming.tween_interval(arm_time(offers.size()))
	arming.tween_callback(_arm.bind(offers.duplicate()))


# Only the same hand, still open and unanswered, is armed.
func _arm(dealt: Array[BoonData]) -> void:
	if not visible or offers != dealt:
		return
	armed = true
	for index in offers.size():
		cards[index].self_modulate = Color.WHITE
		UIMotion.of(cards[index]).flash(1.3, UIMotion.SELECT_TIME)
	create_tween().tween_property(key_guide, "modulate:a", 1.0, UIMotion.SELECT_TIME)
	_mouse_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not _mouse_held:
		_open_to_mouse()
	if not buttons.is_empty():
		buttons[0].grab_focus()


func _open_to_mouse() -> void:
	for index in buttons.size():
		buttons[index].mouse_filter = Control.MOUSE_FILTER_STOP if index < offers.size() else Control.MOUSE_FILTER_IGNORE


# Whether the fight's actions are still being pressed, or were a moment ago.
func resting() -> bool:
	return _rest_left > 0.0


# The rest runs down in real time while none of the fight's actions is held,
# from the deal on, so a hand left alone while it is dealt is free the
# moment it arms.
func _process(_delta: float) -> void:
	if not visible or _rest_left <= 0.0:
		return
	var now := Time.get_ticks_msec()
	var passed := (now - _rest_clock) / 1000.0
	_rest_clock = now
	if FIGHT_ACTIONS.any(func(action: StringName) -> bool: return Input.is_action_pressed(action)):
		_rest_left = REST
	else:
		_rest_left -= passed


func _input(event: InputEvent) -> void:
	# A press of the fight's while they rest is spent: it starts the rest
	# over and reaches no card.
	if visible and _rest_left > 0.0 and event.is_pressed() and not event.is_echo() and FIGHT_ACTIONS.any(func(action: StringName) -> bool: return event.is_action(action)):
		_rest_left = REST
		_rest_clock = Time.get_ticks_msec()
		get_viewport().set_input_as_handled()
		return
	if _mouse_held and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_mouse_held = false
		if visible and armed:
			_open_to_mouse()


func dismiss() -> void:
	for button in buttons:
		button.release_focus()
	UIMotion.of(panel).reset()
	for card in cards:
		UIMotion.of(card).reset()
		card.hovered = false
	hide()
	offers.clear()


func _hover(index: int, value: bool) -> void:
	if not visible or index >= offers.size():
		return
	cards[index].hovered = value
	UIMotion.of(cards[index]).lift(value)


func _decline() -> void:
	if visible and armed and declinable:
		dismiss()
		declined.emit()


func _reroll() -> void:
	if visible and armed and rerolls > 0:
		reroll_requested.emit()


func _select(index: int) -> void:
	if not visible or index < 0 or index >= offers.size():
		return
	var id: StringName = offers[index].id
	_play_afterglow(index)
	dismiss()
	selected.emit(id)


func clear_afterglow() -> void:
	if is_instance_valid(afterglow):
		afterglow.queue_free()
	afterglow = null


func _play_afterglow(chosen: int) -> void:
	clear_afterglow()
	if not is_inside_tree():
		return
	afterglow = CanvasLayer.new()
	afterglow.layer = layer
	add_sibling(afterglow)
	var root := Control.new()
	root.theme = panel.theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	afterglow.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = shade.color
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in offers.size():
		var source := cards[index]
		var copy := AbilityCard.new()
		root.add_child(copy)
		copy.position = source.global_position
		copy.size = source.size
		copy.modulate = source.modulate
		copy.setup(source.ability, source.level, index + 1)
		copy.hovered = source.hovered
		if index == chosen:
			UIMotion.of(copy).emphasize()
		else:
			UIMotion.of(copy).recede()
	UIMotion.of(dim).fade_out(0.0, UIMotion.MOMENT_TIME)
	var ending := UIMotion.of(root).fade_out(UIMotion.MOMENT_RISE_TIME + UIMotion.MOMENT_HOLD_TIME, UIMotion.EXIT_TIME)
	var layer_node := afterglow
	ending.finished.connect(func():
		if is_instance_valid(layer_node):
			layer_node.queue_free())
	GameAudio.play(self, &"confirm", -18.0)


func _exit_tree() -> void:
	clear_afterglow()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Nothing is taken while the hand is dealt; the keys pressed meanwhile are spent.
	if not armed:
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if declinable and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_decline()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = PICK_KEYS.find(event.physical_keycode)
		if index >= 0:
			get_viewport().set_input_as_handled()
			_select(index)
			return
		if event.physical_keycode == KEY_R and rerolls > 0:
			get_viewport().set_input_as_handled()
			_reroll()
			return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y and rerolls > 0:
		get_viewport().set_input_as_handled()
		_reroll()
		return
	# A focused card already moved with the direction; this is the case with
	# none focused (the pointer took it away, or the opening beat has passed
	# without one): the direction picks up from the nearest end.
	for action: StringName in [&"ui_left", &"ui_right"]:
		if event.is_action_pressed(action) and not offers.is_empty() and get_viewport().gui_get_focus_owner() == null:
			get_viewport().set_input_as_handled()
			buttons[0 if action == &"ui_right" else offers.size() - 1].grab_focus()
			return
