class_name HubSortie
extends Control

# Where to set out, laid out as quest boards and stage selects commonly lay
# it out: on the slab from the left, how many chapters have been cleared and
# the chapters as cards, each its painting, its number and name, and how far
# it has been taken (未踏, 第2層まで, 踏破 2回, or 封印中 with the painting
# dark and a lock on it). In the column on the right, the chosen chapter's
# painting, name and line; its way, record and boss (the boss unnamed until
# met, as in the encyclopedia); the foes that come in it, pictured when met
# and dark shapes when not; what she carries; once the ending has opened the
# difficulty steps, the step to set out at (as Slay the Spire offers its
# ascension: the step, what it adds, and the echo it brings back; Q / E or
# LB / RB change it); and the one action, setting out. A sealed chapter can
# be chosen to read what opens it, not set out for.
#
# Keys and the gamepad choose by moving the focus, and Enter (A) on a
# chapter sets out at once, as Enter on an upgrade's node buys it. The
# pointer chooses by resting or clicking, and sets out with the button.

signal departure_requested(chapter: ChapterData)
# The chosen chapter, when it is open: the lobby shows it next.
signal chapter_chosen(chapter: ChapterData)
# The difficulty step chosen to set out at.
signal step_chosen(step: int)

const CARD_HEIGHT := 132.0
const THUMB_SIZE := Vector2(192, 108)
const CARD_LOCK_SIZE := 40.0
const BANNER_HEIGHT := 250.0
const BANNER_LOCK_SIZE := 64.0
const FOE_SIZE := 64.0
const EMBLEM_SIZE := 48.0
const CAPTION_WIDTH := 112.0
# The facts stand on the column's left edge, like the lines above and below.
const FACT_WIDTH := 240.0
const STEP_VALUE_WIDTH := 44.0
const UNKNOWN_NAME := "？？？"

var meta: MetaProgress
var cards: Array[Button] = []
var selected := 0
var count_label: Label
var banner_art: TextureRect
var banner_lock: TextureRect
var name_label: Label
var description_label: Label
var route_value: Label
var record_value: Label
var boss_value: Label
var foe_row: HBoxContainer
var gear_row: HBoxContainer
# The difficulty step row (hidden until the ending opens the steps), the
# step chosen, and its parts.
var step_row: HBoxContainer
var step := 0
var step_value: Label
var step_note: Label
var step_down: Button
var step_up: Button
var action_button: Button
var _list_column: VBoxContainer
var _info: VBoxContainer
var _thumbs: Array[TextureRect] = []
var _locks: Array[TextureRect] = []
var _names: Array[Label] = []
var _states: Array[Label] = []
var _hover_target: Control
# The last press came from the pointer (it chooses, never sets out).
var _by_pointer := false
# The chapter the column tells now: choosing it again (a click lands as a
# focus and a press) neither redraws nor slides the column.
var _shown: ChapterData


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list_column = HubUI.open_column(columns, 0.6, &"SlabSolid")
	count_label = HubUI.label(_list_column, "", &"NoteLabel")
	for index in Chapters.ALL.size():
		cards.append(_card(index))
	for index in cards.size():
		cards[index].focus_neighbor_top = cards[maxi(0, index - 1)].get_path()
		cards[index].focus_neighbor_bottom = cards[mini(cards.size() - 1, index + 1)].get_path()
	_info = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	# The account slides in from the right edge, kept inside its column.
	(_info.get_parent() as Control).clip_contents = true
	_info.theme_type_variation = &"DetailStack"
	_build_banner()
	name_label = HubUI.label(_info, "", &"HeadingLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	description_label = HubUI.label(_info, "", &"DescriptionLabel")
	HubUI.rule(_info)
	var facts := HBoxContainer.new()
	facts.theme_type_variation = &"ListRow"
	_info.add_child(facts)
	route_value = _fact(facts, "道のり")
	record_value = _fact(facts, "記録")
	boss_value = _fact(facts, "ボス")
	foe_row = _row("現れる敵")
	gear_row = _row("装備")
	HubUI.space(_info)
	_build_step_row()
	action_button = HubUI.primary_action(_info, "", set_out)
	action_button.name = "SetOut"
	for card in cards:
		card.focus_neighbor_right = action_button.get_path()
	UIMotion.bind_buttons(_list_column)
	UIMotion.bind_buttons(_info)


# A chapter's card: its painting on the left (dark and locked while sealed),
# and beside it the number, the name and how far it has been taken. The
# chosen card keeps the gold frame while the focus is on the button.
func _card(index: int) -> Button:
	var card := Button.new()
	card.name = "Chapter%d" % (index + 1)
	card.theme_type_variation = &"CardButton"
	card.toggle_mode = true
	card.custom_minimum_size.y = CARD_HEIGHT
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_column.add_child(card)
	var row := HBoxContainer.new()
	row.theme_type_variation = &"ListRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_top = 12
	row.offset_right = -16
	row.offset_bottom = -12
	var thumb := _painting(Chapters.ALL[index].illustration)
	thumb.custom_minimum_size = THUMB_SIZE
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(thumb)
	_thumbs.append(thumb)
	_locks.append(_lock(thumb, CARD_LOCK_SIZE))
	var words := VBoxContainer.new()
	words.theme_type_variation = &"CompactStack"
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var number := HubUI.label(words, Chapters.short_name(Chapters.ALL[index]), &"NoteLabel")
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	var title := HubUI.label(words, Chapters.title(Chapters.ALL[index]), &"ItemNameLabel")
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_names.append(title)
	var state := HubUI.label(words, "", &"MutedLabel")
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	_states.append(state)
	card.pressed.connect(_press.bind(index))
	card.focus_entered.connect(_choose.bind(index))
	card.mouse_entered.connect(_rest_on.bind(card))
	card.mouse_exited.connect(func():
		if _hover_target == card:
			_hover_target = null)
	return card


func _painting(texture: Texture2D) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


# The chapter seal laid over the middle of a painting.
func _lock(over: Control, extent: float) -> TextureRect:
	var lock := TextureRect.new()
	lock.texture = EmblemIcons.texture("seal_chapter")
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(lock)
	lock.set_anchors_preset(Control.PRESET_CENTER)
	lock.offset_left = -extent * 0.5
	lock.offset_top = -extent * 0.5
	lock.offset_right = extent * 0.5
	lock.offset_bottom = extent * 0.5
	lock.hide()
	return lock


# The chosen chapter's painting across the column, its foot melting into the
# panel so the name below sits on the panel, not on the picture.
func _build_banner() -> void:
	var banner := Control.new()
	banner.custom_minimum_size.y = BANNER_HEIGHT
	banner.clip_contents = true
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(banner)
	banner_art = _painting(null)
	banner.add_child(banner_art)
	banner_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var surface := get_theme_stylebox(&"panel", &"SlabSolidEnd") as QuietWindowStyle
	var ground := surface.fill if surface != null else Color.BLACK
	var fade := Gradient.new()
	fade.set_color(0, Color(ground, 0.0))
	fade.set_color(1, Color(ground, 1.0))
	fade.add_point(0.55, Color(ground, 0.0))
	var veil_texture := GradientTexture2D.new()
	veil_texture.gradient = fade
	veil_texture.fill_from = Vector2(0.5, 0)
	veil_texture.fill_to = Vector2(0.5, 1)
	var veil := TextureRect.new()
	veil.texture = veil_texture
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner_lock = _lock(banner, BANNER_LOCK_SIZE)


# The step to set out at, just above the button: the arrows round the step,
# then what it adds and the echo it brings back; the whole list of what is
# in play shows on pointing at that line.
func _build_step_row() -> void:
	step_row = HBoxContainer.new()
	step_row.name = "StepRow"
	step_row.theme_type_variation = &"CompactRow"
	_info.add_child(step_row)
	var kicker := HubUI.label(step_row, "段階", &"MutedLabel")
	kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	kicker.custom_minimum_size.x = CAPTION_WIDTH
	kicker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	step_down = HubUI.button(step_row, "◀", func(): choose_step(step - 1))
	step_down.focus_mode = Control.FOCUS_NONE
	step_value = HubUI.label(step_row, "", &"ValueLabel")
	step_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	step_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_value.custom_minimum_size.x = STEP_VALUE_WIDTH
	step_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	step_up = HubUI.button(step_row, "▶", func(): choose_step(step + 1))
	step_up.focus_mode = Control.FOCUS_NONE
	step_note = HubUI.label(step_row, "", &"BodyLabel")
	step_note.autowrap_mode = TextServer.AUTOWRAP_OFF
	step_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	step_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	step_note.mouse_filter = Control.MOUSE_FILTER_PASS
	step_row.hide()


# A fact reads as a small caption above its value.
func _fact(row: HBoxContainer, caption: String) -> Label:
	var cell := VBoxContainer.new()
	cell.theme_type_variation = &"CompactStack"
	cell.custom_minimum_size.x = FACT_WIDTH
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cell)
	var kicker := HubUI.label(cell, caption, &"MutedLabel")
	kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	var value := HubUI.label(cell, "", &"ValueLabel")
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	return value


# A captioned line of pictures (the foes, what she carries); returns where
# the pictures go.
func _row(caption: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.theme_type_variation = &"CompactRow"
	_info.add_child(line)
	var kicker := HubUI.label(line, caption, &"MutedLabel")
	kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	kicker.custom_minimum_size.x = CAPTION_WIDTH
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
	var cleared := 0
	for index in cards.size():
		var each := Chapters.ALL[index]
		var open := meta.chapter_open(each)
		if meta.clears_of(each.id) > 0:
			cleared += 1
		var record := Chapters.record(meta, each)
		_states[index].text = "封印中" if not open else ("未踏" if record == "なし" else record)
		_thumbs[index].modulate = get_theme_color(&"art_tint" if open else &"art_locked", &"HubLobby")
		_locks[index].visible = not open
	count_label.text = "踏破した章  %d / %d" % [cleared, Chapters.ALL.size()]
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


# Enter (A) on a chapter sets out for it; a click only chooses it.
func _press(index: int) -> void:
	_choose(index)
	if not _by_pointer:
		set_out()


func set_out() -> void:
	if meta == null or not meta.chapter_open(chosen()):
		GameAudio.play(self, &"ui_deny", -18.0)
		return
	departure_requested.emit(chosen())


func _show_selection() -> void:
	for index in cards.size():
		cards[index].set_pressed_no_signal(index == selected)
	action_button.focus_neighbor_left = cards[selected].get_path()


# The column: what the chosen chapter is, how far it has been taken, what
# waits in it, and the button to set out (or why it cannot be).
func _tell() -> void:
	if meta == null:
		return
	var chapter := chosen()
	_shown = chapter
	var open := meta.chapter_open(chapter)
	banner_art.texture = chapter.illustration
	banner_art.modulate = get_theme_color(&"art_tint" if open else &"art_locked", &"HubLobby")
	banner_lock.visible = not open
	name_label.text = chapter.display_name
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


# The step row: shown once the steps are open, with what the chosen step
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


# Opening the page: the cards one after another, then the column.
func play_entrance() -> void:
	UIMotion.of(_list_column).appear(0.0, UIMotion.WINDOW_TIME)
	for index in cards.size():
		UIMotion.of(cards[index]).appear(UIMotion.STAGGER_TIME * index)
	UIMotion.of(_info).appear(UIMotion.STAGGER_TIME * cards.size())


# Resting the pointer on a card a moment chooses it.
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
