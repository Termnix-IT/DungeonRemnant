extends CanvasLayer

signal selected(id: StringName)

var offers: Array[AbilityData] = []
@onready var buttons: Array[Button] = [$Panel/Choices/First, $Panel/Choices/Second, $Panel/Choices/Third]


func _ready() -> void:
	hide()
	for index in buttons.size():
		buttons[index].pressed.connect(_select.bind(index))


func present(candidates: Array[AbilityData], abilities: AbilitySystem, level: int, pending: int) -> void:
	offers = candidates.duplicate()
	$Panel/Title.text = "Lv %d  能力を1つ選択" % (level - pending + 1)
	$Panel/Hint.text = "クリック または 1・2・3キーで選択（残り%d回）" % pending
	for index in buttons.size():
		buttons[index].visible = index < offers.size()
		if index < offers.size():
			var ability := offers[index]
			buttons[index].text = "%d  %s  Lv%d → %d / %d\n%s" % [index + 1, ability.display_name, abilities.level_of(ability), abilities.level_of(ability) + 1, ability.max_level, ability.effect_description()]
	show()


func dismiss() -> void:
	hide()
	offers.clear()


func _select(index: int) -> void:
	if not visible or index < 0 or index >= offers.size():
		return
	var id := offers[index].id
	dismiss()
	selected.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
	if index >= 0:
		get_viewport().set_input_as_handled()
		_select(index)
