extends CanvasLayer

signal selected(id: StringName)

const GameAudio := preload("res://audio/game_audio.gd")

var offers: Array[AbilityData] = []
var cards: Array[AbilityCard] = []
# Plays the chosen moment after the dialog has already closed, so the turn
# resumes immediately. It never receives input and replaces itself.
var afterglow: CanvasLayer
@onready var panel: PanelContainer = $Panel
@onready var shade: ColorRect = $Shade
@onready var buttons: Array[Button] = [$Panel/Margin/Stack/Choices/First, $Panel/Margin/Stack/Choices/Second, $Panel/Margin/Stack/Choices/Third]


func _ready() -> void:
	hide()
	for index in buttons.size():
		var card := AbilityCard.new()
		buttons[index].add_child(card)
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cards.append(card)
		buttons[index].pressed.connect(_select.bind(index))
		buttons[index].mouse_entered.connect(_hover.bind(index, true))
		buttons[index].mouse_exited.connect(_hover.bind(index, false))


func present(candidates: Array[AbilityData], abilities: AbilitySystem, level: int, pending: int) -> void:
	clear_afterglow()
	offers = candidates.duplicate()
	$Panel/Margin/Stack/Title.text = "Lv %d  能力を1つ選択" % (level - pending + 1)
	$Panel/Margin/Stack/Hint.text = "クリック または 1・2・3キーで選択（残り%d回）" % pending
	for index in buttons.size():
		buttons[index].visible = index < offers.size()
		if index < offers.size():
			cards[index].setup(offers[index], abilities.level_of(offers[index]), index + 1)
	show()
	UIMotion.of(panel).reveal(UIMotion.WINDOW_TIME)
	for index in offers.size():
		UIMotion.of(cards[index]).enter(index * UIMotion.STAGGER_TIME)


func dismiss() -> void:
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
	var id := offers[index].id
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
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
	if index >= 0:
		get_viewport().set_input_as_handled()
		_select(index)
