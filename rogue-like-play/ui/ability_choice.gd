extends CanvasLayer

signal selected(id: StringName)

const GameAudio := preload("res://audio/game_audio.gd")
# Focus (and so Enter / gamepad A) arrives a beat after opening, so a
# confirm pressed for the attack that levelled up cannot pick a card.
# Mouse and the 1-3 keys work immediately. On a gamepad the D-pad or the
# left stick moves between the cards (round from the last to the first) and
# A takes the focused one; with no card focused, a direction focuses one.
const FOCUS_DELAY := 0.3

# AbilityData (the turn-based run) or BoonData (the real-time run).
var offers: Array = []
var _levels: Array[int] = []
var cards: Array[AbilityCard] = []
# Plays the chosen moment after the dialog has already closed, so the turn
# resumes immediately. It never receives input and replaces itself.
var afterglow: CanvasLayer
var key_guide: KeyGuide
var pick_hint: Button
@onready var panel: PanelContainer = $Panel
@onready var shade: ColorRect = $Shade
@onready var buttons: Array[Button] = [$Panel/Margin/Stack/Choices/First, $Panel/Margin/Stack/Choices/Second, $Panel/Margin/Stack/Choices/Third]


func _ready() -> void:
	hide()
	# Key caps under the cards rather than an instruction sentence.
	key_guide = KeyGuide.new()
	key_guide.alignment = BoxContainer.ALIGNMENT_CENTER
	key_guide.custom_minimum_size.y = 40
	$Panel/Margin/Stack.add_child(key_guide)
	key_guide.add_hint("← / →", "◀ / ▶", "カード")
	pick_hint = key_guide.add_hint("1・2・3", "A", "選ぶ")
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


func present(candidates: Array[AbilityData], abilities: AbilitySystem, level: int, pending: int) -> void:
	var levels: Array[int] = []
	for ability in candidates:
		levels.append(abilities.level_of(ability))
	_open(candidates, levels, level, pending)


# The real-time run's level-up: boons, at the ranks the build holds.
# `title` replaces the level-up title (an area's reward).
func present_boons(candidates: Array[BoonData], build: BuildState, level: int, pending: int, title: String = "") -> void:
	var levels: Array[int] = []
	for boon in candidates:
		levels.append(build.rank(boon.id))
	_open(candidates, levels, level, pending)
	if not title.is_empty():
		$Panel/Margin/Stack/Title.text = title


func _open(candidates: Array, levels: Array[int], level: int, pending: int) -> void:
	clear_afterglow()
	offers = candidates.duplicate()
	_levels = levels
	$Panel/Margin/Stack/Title.text = "Lv %d  能力を1つ選択" % (level - pending + 1)
	var keys: Array[String] = []
	for index in offers.size():
		keys.append(str(index + 1))
	$Panel/Margin/Stack/Hint.text = "あと%d回選べます" % pending
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
	# A method callable is dropped automatically if this dialog is freed.
	get_tree().create_timer(FOCUS_DELAY).timeout.connect(_focus_first.bind(offers.duplicate()))


# Only the same offer, still open and unanswered, takes focus.
func _focus_first(opened: Array) -> void:
	if visible and offers == opened and not buttons.is_empty():
		buttons[0].grab_focus()


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
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	frame.position = panel.global_position
	frame.size = panel.size
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
	UIMotion.of(frame).fade_out(0.0, UIMotion.EXIT_TIME)
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
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
		if index >= 0:
			get_viewport().set_input_as_handled()
			_select(index)
			return
	# A focused card already moved with the direction; this is the case with
	# none focused (the pointer took it away, or the opening beat has passed
	# without one): the direction picks up from the nearest end.
	for action: StringName in [&"ui_left", &"ui_right"]:
		if event.is_action_pressed(action) and not offers.is_empty() and get_viewport().gui_get_focus_owner() == null:
			get_viewport().set_input_as_handled()
			buttons[0 if action == &"ui_right" else offers.size() - 1].grab_focus()
			return
