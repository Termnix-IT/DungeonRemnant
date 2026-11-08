class_name HubSortie
extends Control

# Where to set out, laid out as stage selects that set their places side by
# side as doors lay it out (Halls of Torment, Slay the Spire): the chapters
# as doors standing shoulder to shoulder in the hall (ChapterDoor), each its
# painting, its number and name, and how far it has been taken (未踏,
# 第2層まで, 踏破 2回, or 封印中 with the door dark and sealed). The chosen door
# steps forward in a glowing gold frame; the others stay darker.
#
# Beneath, one band on the panel's two columns. On the left, the chosen
# chapter's line; its way, record and boss (the boss unnamed until met, as
# in the encyclopedia); the foes that come in it, pictured when met and dark
# shapes when not; and what she carries. On the right, once the ending has
# opened the difficulty steps, the step to set out at (as Slay the Spire
# offers its ascension: the step, what it adds, and the echo it brings
# back; Q / E or LB / RB change it); and the one action, setting out. A
# sealed chapter can be chosen to read what opens it, not set out for.
#
# Left and right (the d-pad, the left stick) choose by moving the focus
# along the doors, and Enter (A) on a door sets out at once, as Enter on an
# upgrade's node buys it. The pointer chooses by resting or clicking, and
# sets out with the button.

signal departure_requested(chapter: ChapterData)
# The chosen chapter, when it is open: the lobby shows it next.
signal chapter_chosen(chapter: ChapterData)
# The difficulty step chosen to set out at.
signal step_chosen(step: int)

const DOOR_SIZE := Vector2(330, 408)
# Where across each chapter's painting its door looks: on the way in, the
# lit stair or gate each painting is drawn round.
const DOOR_FOCUS := {
	&"ash_corridor": 0.8,
	&"gale_woods": 0.84,
	&"amethyst_mausoleum": 0.73,
	&"abyss_of_echoes": 0.74,
}
const FOE_SIZE := 52.0
const EMBLEM_SIZE := 40.0
# Room between the facts, and between the foes and what she carries.
const FACT_GAP := 40.0
const STEP_VALUE_WIDTH := 44.0
const STRIP_HEIGHT := 60.0
# The column on the band's right, where the step and the button stand.
const DECIDE_WIDTH := 460.0
const UNKNOWN_NAME := "？？？"

var meta: MetaProgress
var cards: Array[ChapterDoor] = []
var selected := 0
var description_label: Label
var route_value: Label
var record_value: Label
var boss_value: Label
var foe_row: HBoxContainer
var gear_row: HBoxContainer
# The difficulty step (its rows hidden until the ending opens the steps),
# the step chosen, and its parts.
var step_row: VBoxContainer
var step := 0
var step_value: Label
var step_note: Label
var step_down: Button
var step_up: Button
var action_button: Button
var _doors: HBoxContainer
var _band: PanelContainer
var _band_art: TextureRect
var _info: VBoxContainer
var _decide: VBoxContainer
var _hover_target: Control
# The last press came from the pointer (it chooses, never sets out).
var _by_pointer := false
# The chapter the band tells now: choosing it again (a click lands as a
# focus and a press) neither redraws nor slides the band.
var _shown: ChapterData


func _ready() -> void:
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"DetailStack"
	add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hall := CenterContainer.new()
	hall.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(hall)
	_doors = HBoxContainer.new()
	_doors.theme_type_variation = &"DoorRow"
	hall.add_child(_doors)
	for index in Chapters.ALL.size():
		cards.append(_door(index))
	_build_band(stack)
	_info.theme_type_variation = &"DetailStack"
	description_label = HubUI.label(_info, "", &"DescriptionLabel")
	var facts := HubUI.fact_strip(_info, STRIP_HEIGHT)
	route_value = HubUI.strip_fact(facts, "道のり", &"SortieFactValue", &"SortieFactCaption")
	HubUI.strip_divider(facts)
	record_value = HubUI.strip_fact(facts, "記録", &"SortieFactValue", &"SortieFactCaption")
	HubUI.strip_divider(facts)
	boss_value = HubUI.strip_fact(facts, "ボス", &"SortieFactValue", &"SortieFactCaption")
	var pictures := HBoxContainer.new()
	pictures.theme_type_variation = &"CompactRow"
	_info.add_child(pictures)
	foe_row = _row(pictures, "現れる敵")
	gear_row = _row(pictures, "装備")
	_decide.theme_type_variation = &"DetailStack"
	_build_step_row()
	HubUI.space(_decide)
	# Setting out is drawn as the game's crests are, not as the other screens'
	# plates: the crest kindles as the button is chosen (CrestButton).
	action_button = CrestButton.new()
	action_button.name = "SetOut"
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decide.add_child(action_button)
	action_button.pressed.connect(set_out)
	HubUI.ornate_frame(_band)
	for index in cards.size():
		var door := cards[index]
		door.focus_neighbor_left = cards[maxi(0, index - 1)].get_path()
		door.focus_neighbor_right = cards[mini(cards.size() - 1, index + 1)].get_path()
		door.focus_neighbor_top = door.get_path()
		door.focus_neighbor_bottom = action_button.get_path()
	UIMotion.bind_buttons(_doors)
	UIMotion.bind_buttons(_band)


# The band beneath the doors, dressed as the lobby's panel is: its dark
# ground, the chosen chapter's painting faint on the right and fading out
# toward the words, and the ornate frame over it all. Inside, the account
# on the left and, past an upright hairline, the step and the button.
func _build_band(stack: VBoxContainer) -> void:
	_band = PanelContainer.new()
	_band.name = "Band"
	_band.theme_type_variation = &"SortieBand"
	stack.add_child(_band)
	_band_art = TextureRect.new()
	_band_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_band_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(_band_art)
	var fade := Gradient.new()
	var ground := get_theme_stylebox(&"panel", &"SortieBand").get(&"bg_color") as Color
	fade.set_color(0, Color(ground, 1.0))
	fade.set_color(1, Color(ground, 0.15))
	fade.add_point(0.45, Color(ground, 0.9))
	var veil_texture := GradientTexture2D.new()
	veil_texture.gradient = fade
	veil_texture.fill_from = Vector2(0, 0.5)
	veil_texture.fill_to = Vector2(1, 0.5)
	var veil := TextureRect.new()
	veil.texture = veil_texture
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(veil)
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"SortieBandMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(margin)
	var row := HBoxContainer.new()
	row.theme_type_variation = &"ShopColumns"
	margin.add_child(row)
	# The account slides in from the right, kept inside its own room.
	var room := MarginContainer.new()
	room.clip_contents = true
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(room)
	_info = VBoxContainer.new()
	room.add_child(_info)
	HubUI.column_rule(row, 48)
	_decide = VBoxContainer.new()
	_decide.custom_minimum_size.x = DECIDE_WIDTH
	row.add_child(_decide)

# A chapter's door, its painting looking where the chapter's way leads.
func _door(index: int) -> ChapterDoor:
	var chapter := Chapters.ALL[index]
	var door := ChapterDoor.new()
	door.name = "Chapter%d" % (index + 1)
	door.custom_minimum_size = DOOR_SIZE
	door.painting = chapter.illustration
	door.focus_x = DOOR_FOCUS.get(chapter.id, 0.5)
	door.number_label.text = Chapters.short_name(chapter)
	door.name_label.text = Chapters.title(chapter)
	_doors.add_child(door)
	door.pressed.connect(_press.bind(index))
	door.focus_entered.connect(_choose.bind(index))
	door.mouse_entered.connect(_rest_on.bind(door))
	door.mouse_exited.connect(func():
		if _hover_target == door:
			_hover_target = null)
	return door


# The step to set out at, above the button: the arrows round the step, and
# beneath, what it adds and the echo it brings back; the whole list of what
# is in play shows on pointing at that line.
func _build_step_row() -> void:
	step_row = VBoxContainer.new()
	step_row.name = "StepRow"
	step_row.theme_type_variation = &"CompactStack"
	_decide.add_child(step_row)
	var line := HBoxContainer.new()
	line.theme_type_variation = &"CompactRow"
	step_row.add_child(line)
	var kicker := HubUI.label(line, "段階", &"MutedLabel")
	kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	kicker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	step_down = HubUI.button(line, "◀", func(): choose_step(step - 1))
	step_down.focus_mode = Control.FOCUS_NONE
	step_value = HubUI.label(line, "", &"ValueLabel")
	step_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	step_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_value.custom_minimum_size.x = STEP_VALUE_WIDTH
	step_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	step_up = HubUI.button(line, "▶", func(): choose_step(step + 1))
	step_up.focus_mode = Control.FOCUS_NONE
	step_note = HubUI.label(step_row, "", &"BodyLabel")
	step_note.autowrap_mode = TextServer.AUTOWRAP_OFF
	step_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	step_note.mouse_filter = Control.MOUSE_FILTER_PASS
	step_row.hide()


func _gap(row: HBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.x = FACT_GAP
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)


# A captioned run of pictures (the foes, what she carries) on the line;
# returns where the pictures go.
func _row(line: HBoxContainer, caption: String) -> HBoxContainer:
	if line.get_child_count() > 0:
		_gap(line)
	var kicker := HubUI.label(line, caption, &"MutedLabel")
	kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	kicker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pictures := HBoxContainer.new()
	pictures.theme_type_variation = &"CompactRow"
	line.add_child(pictures)
	return pictures


func _picture(row: HBoxContainer, texture: Texture2D, extent: float, tip: String) -> void:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.custom_minimum_size = Vector2.ONE * extent
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.tooltip_text = tip
	picture.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(picture)


func refresh(current: MetaProgress, chapter: ChapterData, at_step: int = 0) -> void:
	meta = current
	step = clampi(at_step, 0, meta.steps_open())
	for index in cards.size():
		var each := Chapters.ALL[index]
		var open := meta.chapter_open(each)
		var record := Chapters.record(meta, each)
		cards[index].state_label.text = "封印中" if not open else ("未踏" if record == "なし" else record)
		cards[index].sealed = not open
	selected = maxi(0, Chapters.ALL.find(chapter))
	_shown = null
	_show_selection()
	_tell()


func chosen() -> ChapterData:
	return Chapters.ALL[selected]


func _choose(index: int) -> void:
	if index < 0 or index >= cards.size():
		return
	selected = index
	_show_selection()
	if chosen() == _shown:
		return
	_tell()
	UIMotion.of(_info).slide_in()
	if meta != null and meta.chapter_open(chosen()):
		chapter_chosen.emit(chosen())


# Enter (A) on a door sets out for its chapter; a click only chooses it.
func _press(index: int) -> void:
	_choose(index)
	if not _by_pointer:
		set_out()


func set_out() -> void:
	if meta == null or not meta.chapter_open(chosen()):
		GameAudio.play(self, &"ui_deny", -18.0)
		return
	departure_requested.emit(chosen())


# The chosen door stands forward and keeps its gold edge while the focus is
# on the button; the others stand back.
func _show_selection() -> void:
	for index in cards.size():
		cards[index].set_pressed_no_signal(index == selected)
		UIMotion.of(cards[index]).stand(index == selected)
	action_button.focus_neighbor_top = cards[selected].get_path()
	action_button.focus_neighbor_left = cards[selected].get_path()


# The band: what the chosen chapter is, how far it has been taken, what
# waits in it, and the button to set out (or why it cannot be).
func _tell() -> void:
	if meta == null:
		return
	var chapter := chosen()
	_shown = chapter
	var open := meta.chapter_open(chapter)
	_band_art.texture = chapter.illustration
	_band_art.modulate = get_theme_color(&"art_tint" if open else &"art_locked", &"HubLobby")
	var key := Chapters.find(chapter.unlocked_by)
	var opener := "%sを踏破すると開く" % (Chapters.short_name(key) if key != null else "前の章")
	TextWrap.set_text(description_label, chapter.description if open else "封印されている。%s。" % opener)
	route_value.text = "%d層とボス" % chapter.layers
	record_value.text = Chapters.record(meta, chapter)
	var boss := chapter.boss.boss if chapter.boss != null else null
	boss_value.text = boss.display_name if boss != null and meta.has_met(boss.id) else UNKNOWN_NAME
	for child in foe_row.get_children():
		child.free()
	for foe in Chapters.foes(chapter):
		var met := meta.has_met(foe.id)
		_picture(foe_row, HubCodex.tile_picture(foe.visual_id, met, foe.tint), FOE_SIZE, foe.display_name if met else UNKNOWN_NAME)
	for child in gear_row.get_children():
		child.free()
	var weapon := MetaProgress.find_weapon(meta.weapon)
	if weapon != null:
		_picture(gear_row, EmblemIcons.texture(weapon.emblem), EMBLEM_SIZE, weapon.display_name)
	for id in meta.loadout:
		var skill := MetaProgress.find_skill(id)
		if skill != null:
			_picture(gear_row, EmblemIcons.texture(skill.emblem), EMBLEM_SIZE, skill.display_name)
	var move := MetaProgress.find_special(meta.special)
	if move != null:
		_picture(gear_row, EmblemIcons.texture(move.emblem), EMBLEM_SIZE, move.display_name)
	action_button.disabled = not open
	action_button.text = "%sへ出撃する" % Chapters.short_name(chapter) if open else "%sは封印中" % Chapters.short_name(chapter)
	if open and step > 0:
		action_button.text += "（段階%d）" % step
	action_button.tooltip_text = "" if open else opener
	_show_step()


# The step rows: shown once the steps are open, with what the chosen step
# adds and brings back, and why the next one is not open yet.
func _show_step() -> void:
	var open := meta.steps_open() if meta != null else 0
	step_row.visible = open > 0
	if open == 0:
		return
	step_value.text = str(step)
	step_note.text = "制約なし" if step == 0 else "%s　%s" % [DifficultySteps.ALL[step - 1].summary, DifficultySteps.echo_text(step)]
	step_note.tooltip_text = "" if step == 0 else DifficultySteps.constraints(step)
	step_down.disabled = step <= 0
	step_up.disabled = step >= open
	var final := Chapters.short_name(Chapters.ALL.back())
	if step < open:
		step_up.tooltip_text = "段階を上げる（E・RB）"
	elif open < DifficultySteps.MAX:
		step_up.tooltip_text = "段階%dで%sを踏破すると開く" % [open, final]
	else:
		step_up.tooltip_text = "最後の段階"
	step_down.tooltip_text = "段階を下げる（Q・LB）"


# A difficulty step chosen (Q / E, LB / RB or the arrows), kept within those open.
func choose_step(level: int) -> void:
	if meta == null:
		return
	var chosen_step := clampi(level, 0, meta.steps_open())
	if chosen_step == step:
		return
	step = chosen_step
	GameAudio.play(self, &"ui_move", -18.0)
	step_chosen.emit(step)
	_tell()
	UIMotion.of(step_row).reveal(UIMotion.SELECT_TIME)


func focus_selected() -> void:
	cards[selected].grab_focus()


# Opening the page: the doors one after another, then the band.
func play_entrance() -> void:
	for index in cards.size():
		UIMotion.of(cards[index]).appear(UIMotion.STAGGER_TIME * index)
	UIMotion.of(_band).appear(UIMotion.STAGGER_TIME * cards.size(), UIMotion.WINDOW_TIME)


# Resting the pointer on a door a moment chooses it.
func _rest_on(target: Control) -> void:
	_hover_target = target
	await get_tree().create_timer(HubLobby.HOVER_INTENT).timeout
	if _hover_target == target and is_instance_valid(target) and target.is_visible_in_tree() and not target.has_focus():
		target.grab_focus()


# Q / E (LB / RB): the step below or above, once the steps are open.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or meta == null or meta.steps_open() == 0:
		return
	var pad: bool = event is InputEventJoypadButton and event.pressed
	var down: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q) or (pad and event.button_index == JOY_BUTTON_LEFT_SHOULDER)
	var up: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E) or (pad and event.button_index == JOY_BUTTON_RIGHT_SHOULDER)
	if down or up:
		choose_step(step + (1 if up else -1))
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_by_pointer = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_by_pointer = false
	# Enter held on the lobby opened this page: its repeats must not set out.
	if is_visible_in_tree() and event.is_echo() and event.is_action(&"ui_accept"):
		get_viewport().set_input_as_handled()
