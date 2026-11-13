class_name HubStatus
extends Control

# The status page: her build, read from the left to the right.
#
# On the left slab, her four slots as rows (LoadoutSlot), each the slot as
# the fight's HUD shows it (its emblem, its key under it) beside its name,
# what it holds and a short figure: the attack, fixed to a weapon (left
# click / X); the two skills (Q / Y and E / B); the special move (R / LB),
# sealed until one is learned. Beside the rows, the list of what the chosen
# slot can hold (LoadoutChoice): the first row of a slot that can be emptied
# clears it, what the slot holds is marked "装備中", a skill set in the other
# skill slot carries that slot's key (choosing it changes the two places),
# and a thing not learned yet is its emblem's shadow. A bead on the hairline
# between the rows and the list stands level with the chosen slot. At the
# slab's foot, a quiet strip of her five main figures.
#
# On the right, the stage: the thing under the focus, large — its kind, its
# name, what it does and its emblem, its figures a row each, and at the foot
# what the one action would do ("「叩きつけ」と替える") beside the action
# itself as the crest button.
#
# Light follows the focus: while it is on the slots, the list rests dimmer;
# once it is in the list, the other slots dim and the chosen one keeps its
# gold bar, telling what it would hold afterwards ("→ 雷閃"; a swap tells
# both slots). Enter (A) or right on a slot goes into its list, Enter on a
# row there sets it (equip_requested; the hub saves, then calls
# present_equip, which runs a gold ring round every slot that changed), and
# back or left from the list returns to the slot. The pointer chooses by
# resting or clicking, and acts with the button or a double click.
#
# R (Y), or a click on the strip, turns the page to her figures in full
# (`details_open`): every figure a row with where it comes from, in two
# groups over the same two slabs; R, or back, returns to the build.

signal equip_requested(slot: int, id: StringName)
# The page turned between the build and her figures.
signal view_changed

const SLOT_WIDTH := 344.0
const SLOT_HEIGHT := 112.0
const CHOICE_HEIGHT := 62.0
const LINK_WIDTH := 28.0
const BEAD := 6.0
const STRIP_HEIGHT := 68.0
const STRIP_INSET := 14.0
const PICTURE_ROOM := 250.0
const PICTURE_SIZE := 200.0
# The emblem stands a little over the stage's middle.
const PICTURE_LEVEL := 0.42
# The account starts this far down the stage, its figures this far under it.
const ACCOUNT_INSET := 44.0
const FIGURES_GAP := 18.0
const PICTURE_RING := 122.0
const FOOT_HEIGHT := 84.0
const FIGURE_ROW_HEIGHT := 44.0
const SHEET_ROW_HEIGHT := 64.0
const ACTION_WIDTH := 320.0
# How bright the list rests while the focus is on the slots, and the other
# slots while it is in the list.
const LIST_REST := 0.72
const SLOT_REST := 0.45
# The stage's light breathes: this share of its strength, a breath lasting
# BREATH_TIME seconds.
const BREATH := 0.18
const BREATH_TIME := 3.2
# Distances are told in the floor's cells (AreaGround.CELL), to a tenth.
const CELL_SNAP := 0.1
const UNKNOWN_NAME := "？？？"
const UNKNOWN_NOTE := "強化ツリーのスキルの枝で習得できる"
const UNKNOWN_SPECIAL_NOTE := "強化ツリーの必殺技の枝で習得できる"
const UNKNOWN_WEAPON_NOTE := "強化ツリーの武器の枝で習得できる"
const CLEAR_ID := &"clear"
const CLEAR_NOTE := "このスロットを空ける"
const EMPTY_NOTE := "まだ何も付けていない。"
const UNOWNED := "未所持"
const HELD := "装備中"
const SPECIAL_NOTE := "強化ツリーの必殺技の枝で必殺技を覚えると付けられる"
const STRIP_NOTE := "すべての能力を見る"
# The slots: id, name, its keys (keyboard, gamepad), the emblem it shows.
const SLOTS := [
	[&"attack", "攻撃", "左クリック", "X", "weapon_sword"],
	[&"skill_1", "スキル1", "Q", "Y", ""],
	[&"skill_2", "スキル2", "E", "B", ""],
	[&"special", "必殺技", "R", "LB", "seal_special"],
]
const SKILL_SLOT_OFFSET := 1
const ATTACK_SLOT := 0
const SPECIAL_SLOT := 3
# Her figures' two groups on the full page.
const GROUPS := ["戦う力", "探索と成長"]

var meta: MetaProgress
var slot_buttons: Array[LoadoutSlot] = []
var choices: Array[LoadoutChoice] = []
# What each choice holds: a skill's, special move's or weapon's id, or CLEAR_ID.
var choice_ids: Array[StringName] = []
var slot := 1
var shown_id: StringName = &""
var details_open := false
# How many of her figures the page shows.
var shown_rows := 0
# The stage's figures as shown: [name, value] a row.
var shown_figures: Array = []
var picture: Control
var name_label: Label
var kind_label: Label
var description_label: Label
var outcome_label: Label
var count_label: Label
var action_button: CrestButton
var strip: Button
var _slab: VBoxContainer
var _deck: HBoxContainer
var _slot_column: VBoxContainer
var _link: Control
var _choice_column: VBoxContainer
var _scroll: ScrollContainer
var _choices: VBoxContainer
var _strip_row: HBoxContainer
var _stage_room: MarginContainer
var _stage: VBoxContainer
var _figures: VBoxContainer
var _sheets: Array[VBoxContainer] = []
var _emblem := ""
var _unknown := false
var _shown_slot := -1
var _pad := false
var _hover_target: Control
# The last press came from the pointer (it chooses, never acts).
var _by_pointer := false
# The slots an equip asked for would change, for the moment once it is saved.
var _changing: Array[int] = []
# The page is arranging itself: a row taking the focus makes no sound.
var _quiet := true
var _base: HeroTuning


func _ready() -> void:
	_base = load("res://data/hero/mio.tres")
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slab = HubUI.open_column(columns, 1.15, &"SlabSolid")
	_slab.theme_type_variation = &"StatusSlab"
	_build_deck()
	_build_strip()
	var right := HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	(right.get_parent() as Control).clip_contents = true
	_build_stage(right)
	# Her figures in full, a group on each slab, shown in place of the build.
	for parent: VBoxContainer in [_slab, right]:
		var sheet := VBoxContainer.new()
		sheet.theme_type_variation = &"StatusSheet"
		sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sheet.hide()
		parent.add_child(sheet)
		_sheets.append(sheet)
	visibility_changed.connect(_light)
	set_deferred(&"_quiet", false)


# Her slots, the bead's hairline, and the chosen slot's list.
func _build_deck() -> void:
	_deck = HBoxContainer.new()
	_deck.theme_type_variation = &"ShopColumns"
	_deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slab.add_child(_deck)
	_slot_column = VBoxContainer.new()
	_slot_column.theme_type_variation = &"CodexList"
	_slot_column.custom_minimum_size.x = SLOT_WIDTH
	_deck.add_child(_slot_column)
	for index in SLOTS.size():
		var row := LoadoutSlot.new()
		row.custom_minimum_size.y = SLOT_HEIGHT
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.last = index == SLOTS.size() - 1
		_slot_column.add_child(row)
		row.pressed.connect(_enter_choices.bind(index))
		row.focus_entered.connect(_choose_slot.bind(index))
		row.mouse_entered.connect(_rest_on.bind(row))
		slot_buttons.append(row)
	for index in slot_buttons.size():
		var row := slot_buttons[index]
		row.focus_neighbor_top = slot_buttons[maxi(0, index - 1)].get_path()
		row.focus_neighbor_bottom = slot_buttons[mini(slot_buttons.size() - 1, index + 1)].get_path()
		row.focus_neighbor_left = row.get_path()
	_link = Control.new()
	_link.custom_minimum_size.x = LINK_WIDTH
	_link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_link.draw.connect(_draw_link)
	_deck.add_child(_link)
	_slot_column.sort_children.connect(_link.queue_redraw)
	_choice_column = VBoxContainer.new()
	_choice_column.theme_type_variation = &"DetailStack"
	_choice_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck.add_child(_choice_column)
	count_label = HubUI.label(_choice_column, "", &"NoteLabel")
	# More choices than the column holds scroll within it, the row the focus
	# lands on drawn into view.
	_scroll = ScrollContainer.new()
	_scroll.name = "Choices"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_choice_column.add_child(_scroll)
	_choices = VBoxContainer.new()
	_choices.theme_type_variation = &"CodexList"
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_choices)


# Her five main figures at the slab's foot, the way to the rest.
func _build_strip() -> void:
	strip = Button.new()
	strip.name = "Figures"
	strip.theme_type_variation = &"StatusStrip"
	strip.custom_minimum_size.y = STRIP_HEIGHT
	strip.focus_mode = Control.FOCUS_NONE
	strip.pressed.connect(toggle_details)
	strip.draw.connect(func():
		strip.draw_line(Vector2(0.0, 0.5), Vector2(strip.size.x, 0.5), strip.get_theme_color(&"separator", &"LoadoutSlot"), -1.0))
	_slab.add_child(strip)
	_strip_row = HBoxContainer.new()
	_strip_row.theme_type_variation = &"StatusStripRow"
	_strip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(_strip_row)
	_strip_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip_row.offset_left = STRIP_INSET
	_strip_row.offset_right = -STRIP_INSET


# A fixed gap in a stack.
func _gap(parent: Node, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)


# The stage: the thing under the focus, and the one action.
func _build_stage(column: VBoxContainer) -> void:
	_stage_room = MarginContainer.new()
	_stage_room.theme_type_variation = &"StatusStageMargin"
	_stage_room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_stage_room)
	_stage = VBoxContainer.new()
	_stage.theme_type_variation = &"StatusStage"
	_stage_room.add_child(_stage)
	# The account at the left, its figures at its foot; the emblem beside it.
	var body := HBoxContainer.new()
	body.theme_type_variation = &"StatusHead"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.add_child(body)
	var words := VBoxContainer.new()
	words.theme_type_variation = &"DetailStack"
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(words)
	_gap(words, ACCOUNT_INSET)
	kind_label = HubUI.label(words, "", &"NoteLabel")
	name_label = HubUI.label(words, "", &"CodexName")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description_label = HubUI.label(words, "", &"DescriptionLabel")
	_gap(words, FIGURES_GAP)
	_figures = VBoxContainer.new()
	_figures.theme_type_variation = &"CodexStats"
	words.add_child(_figures)
	picture = Control.new()
	picture.name = "Emblem"
	picture.custom_minimum_size.x = PICTURE_ROOM
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.draw.connect(_draw_picture)
	body.add_child(picture)
	# The foot keeps its room while the action is out of sight.
	var foot := HBoxContainer.new()
	foot.theme_type_variation = &"StatusHead"
	foot.custom_minimum_size.y = FOOT_HEIGHT
	_stage.add_child(foot)
	outcome_label = HubUI.label(foot, "", &"BodyLabel")
	outcome_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outcome_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Setting a thing in a slot: the crest with the lobby's mark for the
	# status. The keys act on the rows; the pointer acts here.
	action_button = CrestButton.new()
	action_button.name = "Equip"
	action_button.kind = &"equip"
	action_button.custom_minimum_size.x = ACTION_WIDTH
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.pressed.connect(_act)
	foot.add_child(action_button)
	UIMotion.bind_buttons(_stage)


func refresh(current: MetaProgress) -> void:
	meta = current
	# The row under the focus is made again: the focus stays on its place.
	var focused := _focused_choice()
	_quiet = true
	_show_slots()
	_show_choices()
	_show_stats()
	if focused >= 0 and focused < choices.size() and is_visible_in_tree():
		choices[focused].grab_focus()
	else:
		_tell(shown_id if not shown_id.is_empty() and choice_ids.has(shown_id) else _slot_content(slot))
	_quiet = false


# --- The slots and their choices ---

# The place in the list of the choice under the focus, or -1.
func _focused_choice() -> int:
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return choices.find(owner as LoadoutChoice) if owner is LoadoutChoice else -1


func _slot_content(index: int) -> StringName:
	match SLOTS[index][0]:
		&"attack":
			return meta.weapon if meta != null else &"sword"
		&"special":
			if meta == null or not meta.owns_any_special():
				return &"special"
			return meta.special
	return meta.loadout[index - SKILL_SLOT_OFFSET] if meta != null else &""


func _slot_key(index: int) -> String:
	return tr(SLOTS[index][3] if _pad else SLOTS[index][2])


# A thing's name as the rows say it ("空き" for none).
func _name_of(id: StringName) -> String:
	var skill := MetaProgress.find_skill(id)
	if skill != null:
		return tr(skill.display_name)
	var move := MetaProgress.find_special(id)
	if move != null:
		return tr(move.display_name)
	var weapon := MetaProgress.find_weapon(id)
	return tr(weapon.display_name) if weapon != null else tr("空き")


func _show_slots() -> void:
	if meta == null:
		return
	for index in SLOTS.size():
		var entry: Array = SLOTS[index]
		var row := slot_buttons[index]
		var held := _slot_content(index)
		var skill := MetaProgress.find_skill(held)
		var move := MetaProgress.find_special(held)
		var weapon := MetaProgress.find_weapon(held)
		var emblem := ""
		row.note = ""
		if held == &"special":
			row.content = tr("封印")
			emblem = entry[4]
		elif weapon != null:
			emblem = weapon.emblem
			row.note = tr("%d連撃") % weapon.combo.size()
		elif skill != null:
			emblem = skill.emblem
			row.note = tr("再使用 %s秒") % _number(skill.cooldown)
		elif move != null:
			emblem = move.emblem
			row.note = tr("ゲージ%s") % _number(move.charge)
		if held != &"special":
			row.content = _name_of(held)
		row.title = tr(entry[1])
		row.emblem = EmblemIcons.texture(emblem)
		row.empty = emblem.is_empty()
		row.sealed = held == &"special"
		row.key = _slot_key(index)
		row.chosen = index == slot
		row.tooltip_text = tr("%s（%s）：%s") % [row.title, row.key, row.content]
		row.queue_redraw()
	_link.queue_redraw()


func _show_choices() -> void:
	if meta == null:
		return
	# The row pressed may still be sending its signal.
	for row in choices:
		_choices.remove_child(row)
		row.queue_free()
	choices.clear()
	choice_ids.clear()
	var kind: StringName = SLOTS[slot][0]
	var held := 0
	var total := 0
	match kind:
		&"attack":
			for weapon in MetaProgress.WEAPONS:
				total += 1
				held += 1 if meta.owns_weapon(weapon.id) else 0
				_add_choice(weapon.id, weapon.emblem, tr(weapon.display_name), tr("%d連撃") % weapon.combo.size(), not meta.owns_weapon(weapon.id), UNKNOWN_WEAPON_NOTE)
		&"special":
			for move in MetaProgress.SPECIALS:
				total += 1
				held += 1 if meta.owns_special(move.id) else 0
			# Sealed, its moves still stand in the list as shadows.
			if held > 0:
				_add_choice(CLEAR_ID, "", tr("外す"), "", false, "")
			for move in MetaProgress.SPECIALS:
				_add_choice(move.id, move.emblem, tr(move.display_name), tr("ゲージ%s") % _number(move.charge), not meta.owns_special(move.id), UNKNOWN_SPECIAL_NOTE)
		_:
			_add_choice(CLEAR_ID, "", tr("外す"), "", false, "")
			for skill in MetaProgress.SKILLS:
				total += 1
				held += 1 if meta.owns_skill(skill.id) else 0
				_add_choice(skill.id, skill.emblem, tr(skill.display_name), tr("再使用 %s秒") % _number(skill.cooldown), not meta.owns_skill(skill.id), UNKNOWN_NOTE)
	count_label.text = tr("習得  %d / %d") % [held, total]
	for index in choices.size():
		var row := choices[index]
		row.focus_neighbor_left = slot_buttons[slot].get_path()
		row.focus_neighbor_right = row.get_path()
		if index == 0:
			row.focus_neighbor_top = row.get_path()
		if index == choices.size() - 1:
			row.focus_neighbor_bottom = row.get_path()
	for index in slot_buttons.size():
		slot_buttons[index].focus_neighbor_right = slot_buttons[index].get_path()
	_mark_choices()
	_scroll.scroll_vertical = 0


# A choice: its emblem, its name over a short figure ("再使用 6秒"); one not
# learned yet, its emblem's shadow named "？？？".
func _add_choice(id: StringName, emblem: String, title: String, figure: String, unknown: bool, unknown_note: String) -> void:
	var row := LoadoutChoice.new()
	row.custom_minimum_size.y = CHOICE_HEIGHT
	_choices.add_child(row)
	row.emblem = EmblemIcons.texture(emblem) if not emblem.is_empty() else null
	row.clears = id == CLEAR_ID
	row.title = tr(UNKNOWN_NAME) if unknown else title
	row.note = "" if unknown else figure
	row.state = LoadoutChoice.State.UNKNOWN if unknown else LoadoutChoice.State.FREE
	row.tooltip_text = tr(unknown_note) if unknown else (tr(CLEAR_NOTE) if id == CLEAR_ID else title)
	var index := choices.size()
	row.focus_entered.connect(_choose_choice.bind(index))
	row.pressed.connect(_press_choice.bind(index))
	row.mouse_entered.connect(_rest_on.bind(row))
	# A double click acts as the stage's button does, without the way there.
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			_equip(id))
	choices.append(row)
	choice_ids.append(id)


# Where each choice stands: what the chosen slot holds is "装備中" under a
# gold diamond; a skill set in the other skill slot carries that slot's key;
# one not learned is "未所持"; a row that would change nothing is dimmed.
func _mark_choices() -> void:
	if meta == null:
		return
	var held := _slot_content(slot)
	for index in choices.size():
		var id := choice_ids[index]
		var row := choices[index]
		row.key = ""
		if row.state == LoadoutChoice.State.UNKNOWN:
			row.tag = tr(UNOWNED)
			row.idle = true
		elif id == CLEAR_ID:
			row.tag = ""
			row.idle = held.is_empty()
		elif id == held:
			row.state = LoadoutChoice.State.HELD
			row.tag = tr(HELD)
			row.idle = false
		else:
			row.state = LoadoutChoice.State.FREE
			row.tag = ""
			row.idle = false
			if SLOTS[slot][0] in [&"skill_1", &"skill_2"]:
				var at := meta.slot_of(id)
				if at >= 0 and at != slot - SKILL_SLOT_OFFSET:
					row.state = LoadoutChoice.State.ELSEWHERE
					row.key = _slot_key(at + SKILL_SLOT_OFFSET)
					row.tag = tr(HELD)
		row.queue_redraw()
	# Right from the slot leads to what it holds, else to the list's head.
	if not choices.is_empty():
		slot_buttons[slot].focus_neighbor_right = choices[maxi(0, choice_ids.find(held))].get_path()


func _choose_slot(index: int) -> void:
	var changed := index != slot
	if changed:
		slot = index
		for at in slot_buttons.size():
			slot_buttons[at].chosen = at == slot
		_show_choices()
		UIMotion.of(_choices).appear(0.0, UIMotion.WINDOW_TIME)
		_link.queue_redraw()
	_tick(changed)
	_preview(&"")
	_tell(_slot_content(index))
	_light()


func _choose_choice(index: int) -> void:
	if index >= choice_ids.size():
		return
	_tick(choice_ids[index] != shown_id)
	_tell(choice_ids[index])
	_preview(choice_ids[index])
	_light()


# The quiet tick of the focus moving to another thing.
func _tick(moved: bool) -> void:
	if moved and not _quiet and is_visible_in_tree():
		GameAudio.play(self, &"ui_move", -22.0)


# Enter (A) on a slot: into its list, at the row it holds. A click only
# chooses the slot.
func _enter_choices(index: int) -> void:
	_choose_slot(index)
	if _by_pointer:
		return
	if choices.is_empty():
		GameAudio.play(self, &"ui_deny", -18.0)
		return
	choices[maxi(0, choice_ids.find(_slot_content(index)))].grab_focus()


# Enter (A) on a choice sets it; a click only chooses it, and the stage's
# button acts.
func _press_choice(index: int) -> void:
	if index < choice_ids.size() and not _by_pointer:
		if not _equip(choice_ids[index]):
			GameAudio.play(self, &"ui_deny", -18.0)


# Asks for the choice to be set in the chosen slot; false when that would
# change nothing or cannot be.
func _equip(id: StringName) -> bool:
	if meta == null:
		return false
	_changing = [slot]
	if slot == ATTACK_SLOT:
		if not meta.owns_weapon(id) or meta.weapon == id:
			return false
		equip_requested.emit(MetaProgress.WEAPON_SLOT, id)
		return true
	if slot == SPECIAL_SLOT:
		var move := &"" if id == CLEAR_ID else id
		if (move.is_empty() and meta.special.is_empty()) or (not move.is_empty() and (not meta.owns_special(move) or meta.special == move)):
			return false
		equip_requested.emit(MetaProgress.SPECIAL_SLOT, move)
		return true
	if SLOTS[slot][0] not in [&"skill_1", &"skill_2"]:
		return false
	var target := &"" if id == CLEAR_ID else id
	var index := slot - SKILL_SLOT_OFFSET
	if target.is_empty() and meta.loadout[index].is_empty():
		return false
	if not target.is_empty() and (not meta.owns_skill(target) or meta.slot_of(target) == index):
		return false
	var other := meta.slot_of(target)
	if other >= 0:
		_changing.append(other + SKILL_SLOT_OFFSET)
	equip_requested.emit(index, target)
	return true


func _act() -> void:
	_equip(shown_id)


# After an equip was saved: the moment on every slot it changed, and the
# focus back on the slot.
func present_equip() -> void:
	_quiet = true
	_preview(&"")
	slot_buttons[slot].grab_focus()
	for index in _changing:
		slot_buttons[index].celebrate()
	_changing = []
	_quiet = false


# What the slots would hold once the choice is set: on the chosen slot, and
# on the other skill slot when the two change places.
func _preview(id: StringName) -> void:
	for row in slot_buttons:
		row.preview = ""
	if meta == null or id.is_empty() or not _account(id).can:
		return
	slot_buttons[slot].preview = tr("空き") if id == CLEAR_ID else _name_of(id)
	if SLOTS[slot][0] in [&"skill_1", &"skill_2"]:
		var other := meta.slot_of(id)
		if other >= 0:
			slot_buttons[other + SKILL_SLOT_OFFSET].preview = _name_of(meta.loadout[slot - SKILL_SLOT_OFFSET])


# Light follows the focus: on the slots, the list rests; in the list, the
# slots it does not touch dim.
func _light() -> void:
	if not is_visible_in_tree() or slot_buttons.is_empty():
		return
	var listing := _focused_choice() >= 0
	for index in slot_buttons.size():
		var row := slot_buttons[index]
		var bright := not listing or index == slot or not row.preview.is_empty()
		UIMotion.of(row).fade_to(1.0 if bright else SLOT_REST, UIMotion.SELECT_TIME)
	UIMotion.of(_choice_column).fade_to(1.0 if listing else LIST_REST, UIMotion.SELECT_TIME)


# Resting the pointer on a slot or a choice a moment chooses it.
func _rest_on(target: Control) -> void:
	_hover_target = target
	await get_tree().create_timer(HubLobby.HOVER_INTENT).timeout
	if _hover_target == target and is_instance_valid(target) and target.is_visible_in_tree() and not target.has_focus():
		target.grab_focus()


# The hairline between the slots and the list, and on it the bead level with
# the chosen slot, sliding there from the last one.
func _draw_link() -> void:
	if slot_buttons.is_empty() or slot >= slot_buttons.size():
		return
	var rail := _link.get_theme_color(&"rail", &"HubLobby")
	var x := _link.size.x * 0.5
	var h := _link.size.y
	_link.draw_polyline_colors(
		PackedVector2Array([Vector2(x, 0.0), Vector2(x, h * 0.1), Vector2(x, h * 0.9), Vector2(x, h)]),
		PackedColorArray([Color(rail, 0.0), Color(rail, 0.3), Color(rail, 0.3), Color(rail, 0.0)]), 1.0, true)
	var row := slot_buttons[slot]
	var level := _slot_column.position.y + row.position.y + row.size.y * 0.5 - _link.position.y
	var mark := UIMotion.of(_link).follow_mark(Rect2(x, level, 0.0, 0.0)).position
	HubUI.diamond(_link, mark, BEAD + 1.5, _link.get_theme_color(&"mark_edge", &"LoadoutSlot"))
	HubUI.diamond(_link, mark, BEAD, _link.get_theme_color(&"lit_ring", &"LoadoutSlot"))


# --- The stage ---

func _tell(id: StringName) -> void:
	if meta == null or name_label == null:
		return
	var moved := id != shown_id or slot != _shown_slot
	shown_id = id
	_shown_slot = slot
	var told := _account(id)
	_emblem = told.emblem
	_unknown = told.unknown
	kind_label.text = told.kind
	name_label.text = told.name
	description_label.text = told.description
	description_label.visible = not told.description.is_empty()
	for child in _figures.get_children():
		child.free()
	shown_figures = told.figures
	for row: Array in shown_figures:
		_figure_row(row[0], row[1])
	# The action belongs to choosing: on a slot, the stage only tells.
	var choosing := _focused_choice() >= 0
	action_button.visible = told.acts and choosing
	action_button.text = told.action
	action_button.disabled = not told.can
	outcome_label.text = told.outcome if choosing else ""
	picture.queue_redraw()
	if moved and not _quiet:
		UIMotion.of(_stage).slide_in()


# What the stage tells of a thing: its emblem, kind, name, account and
# figures, and the one action on it in the chosen slot (`acts`: there is one,
# `can`: it would change something) with what it would do.
func _account(id: StringName) -> Dictionary:
	var told := {emblem = "", unknown = false, kind = "", name = "", description = "", figures = [], action = "", acts = false, can = false, outcome = ""}
	var in_skill_slot: bool = SLOTS[slot][0] in [&"skill_1", &"skill_2"]
	var slot_index := slot - SKILL_SLOT_OFFSET
	var weapon := MetaProgress.find_weapon(id)
	var move := MetaProgress.find_special(id)
	var skill := MetaProgress.find_skill(id)
	if weapon != null:
		told.emblem = weapon.emblem
		told.kind = tr("武器")
		if not meta.owns_weapon(weapon.id):
			return _unknown_account(told, UNKNOWN_WEAPON_NOTE)
		var here := meta.weapon == weapon.id
		var strongest := 0.0
		for swing in weapon.combo:
			strongest = maxf(strongest, swing.damage_scale)
		told.name = tr(weapon.display_name)
		told.description = tr(weapon.description)
		told.figures = [
			[tr("連撃"), tr("%d段") % weapon.combo.size()],
			[tr("最も強い段"), _power(strongest)],
			[tr("溜め攻撃"), _power(weapon.charged.damage_scale)],
			_reach_row(weapon.charged, true)]
		told.acts = slot == ATTACK_SLOT
		told.can = told.acts and not here
		told.action = tr(HELD) if here else tr("持ち替える")
		if told.can:
			told.outcome = tr("「%s」と替える") % _name_of(meta.weapon)
	elif id == &"special":
		told.emblem = "seal_special"
		told.unknown = true
		told.kind = tr("未開放の枝")
		told.name = tr("必殺技")
		told.description = tr(SPECIAL_NOTE)
	elif id == CLEAR_ID or id.is_empty():
		var held := _slot_content(slot)
		told.kind = tr(SLOTS[slot][1])
		told.name = tr("空き") if id.is_empty() else tr("外す")
		told.description = tr(EMPTY_NOTE) if id.is_empty() else tr(CLEAR_NOTE)
		told.acts = id == CLEAR_ID
		told.can = told.acts and not held.is_empty() and slot != ATTACK_SLOT
		told.action = tr("外す")
		if told.can:
			told.outcome = tr("「%s」を外す") % _name_of(held)
	elif move != null:
		told.emblem = move.emblem
		told.kind = tr("必殺技")
		if not meta.owns_special(move.id):
			return _unknown_account(told, UNKNOWN_SPECIAL_NOTE)
		var here := meta.special == move.id
		told.name = tr(move.display_name)
		told.description = tr(move.description)
		told.figures = [
			[tr("ゲージ"), _number(move.charge)],
			[tr("威力"), _power(move.attack.damage_scale * (1.0 + meta.bonus(&"special_power")))],
			_reach_row(move.attack)]
		told.acts = slot == SPECIAL_SLOT
		told.can = told.acts and not here
		told.action = tr(HELD) if here else tr("装備する")
		if told.can:
			told.outcome = tr("%s に付ける") % _slot_key(slot) if meta.special.is_empty() else tr("「%s」と替える") % _name_of(meta.special)
	elif skill != null:
		told.emblem = skill.emblem
		told.kind = tr("スキル")
		if not meta.owns_skill(skill.id):
			return _unknown_account(told, UNKNOWN_NOTE)
		var at := meta.slot_of(skill.id)
		var here := in_skill_slot and at == slot_index
		told.name = tr(skill.display_name)
		told.description = tr(skill.description)
		told.figures = [
			[tr("再使用"), tr("%s秒") % _number(skill.cooldown)],
			[tr("威力"), _power(skill.attack.damage_scale)],
			_reach_row(skill.attack)]
		told.acts = in_skill_slot
		told.can = in_skill_slot and not here
		told.action = tr(HELD) if here else (tr("入れ替える") if at >= 0 else tr("装備する"))
		if told.can:
			var current := meta.loadout[slot_index]
			if at >= 0:
				told.outcome = tr("%s から移す") % _slot_key(at + SKILL_SLOT_OFFSET) if current.is_empty() else tr("「%s」と場所を入れ替える") % _name_of(current)
			else:
				told.outcome = tr("%s に付ける") % _slot_key(slot) if current.is_empty() else tr("「%s」と替える") % _name_of(current)
	return told


# A thing not learned yet: its shadow, no name, and where it is learned.
func _unknown_account(told: Dictionary, note: String) -> Dictionary:
	told.unknown = true
	told.name = tr(UNKNOWN_NAME)
	told.description = tr(note)
	return told


# A blow's power against her attack ("攻撃力の180%").
func _power(scale: float) -> String:
	return tr("攻撃力の%d%%") % roundi(scale * 100.0)


# How far an attack reaches, as its shape measures it: a wave's flight, a
# line's length, a circle's radius, an arc's reach.
func _reach_row(attack: AttackData, charged := false) -> Array:
	if attack.projectile != null:
		return [tr("溜め攻撃の射程") if charged else tr("射程"), _cells(attack.projectile.distance)]
	var title := tr("溜め攻撃の範囲") if charged else tr("範囲")
	match attack.shape:
		AttackData.Shape.LINE:
			return [title, tr("長さ%s") % _cells(attack.reach)]
		AttackData.Shape.CIRCLE:
			return [title, tr("半径%s") % _cells(attack.reach)]
	return [title, _cells(attack.reach)]


# A distance in pixels as the floor's cells ("2.9マス").
func _cells(pixels: float) -> String:
	return _number(pixels / AreaGround.CELL, CELL_SNAP) + tr("マス")


# One of the thing's figures: its name, its value at the right, a hairline
# under it.
func _figure_row(title: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"CodexLine"
	row.custom_minimum_size.y = FIGURE_ROW_HEIGHT
	row.draw.connect(func():
		row.draw_line(Vector2(0.0, row.size.y - 0.5), Vector2(row.size.x, row.size.y - 0.5), row.get_theme_color(&"separator", &"LoadoutSlot"), -1.0))
	_figures.add_child(row)
	var name := HubUI.label(row, title, &"BodyLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var figure := HubUI.label(row, value, &"ItemNameLabel")
	figure.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label: Label in [name, figure]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# The stage's emblem in a faint ring, on a soft warm light that breathes; a
# thing not learned is its shadow, an empty slot a dashed ring.
func _draw_picture() -> void:
	var centre := Vector2(picture.size.x * 0.5, picture.size.y * PICTURE_LEVEL)
	var breath := 1.0 + BREATH * sin(Time.get_ticks_msec() * 0.001 * TAU / BREATH_TIME)
	var light := picture.get_theme_color(&"glow", &"LoadoutSlot")
	var rail := picture.get_theme_color(&"rail", &"HubLobby")
	var reach := PICTURE_SIZE * 0.92
	var emblem := EmblemIcons.texture(_emblem)
	var half := PICTURE_SIZE * 0.5
	if emblem != null and not _unknown:
		# One disc at the light's full strength, drawn fainter as it breathes.
		var full := Color(light, light.a * (1.0 + BREATH))
		picture.draw_texture_rect(HubCodex.soft_disc(full), Rect2(centre - Vector2.ONE * reach, Vector2.ONE * reach * 2.0), false, Color(1.0, 1.0, 1.0, breath / (1.0 + BREATH)))
	picture.draw_arc(centre, PICTURE_RING, 0.0, TAU, 96, Color(rail, 0.16), 1.0, true)
	if emblem != null:
		picture.draw_texture_rect(emblem, Rect2(centre - Vector2.ONE * half, Vector2.ONE * PICTURE_SIZE), false, picture.get_theme_color(&"unknown_tint", &"LoadoutSlot") if _unknown else Color.WHITE)
		return
	var dash := picture.get_theme_color(&"empty_ring", &"LoadoutSlot")
	var step := TAU / 40.0
	for index in 40:
		picture.draw_arc(centre, half - 8.0, index * step, index * step + step * 0.5, 6, Color(dash, dash.a * 0.7), 1.5, true)
	if shown_id == CLEAR_ID:
		picture.draw_line(centre + Vector2(-half, half) * 0.36, centre + Vector2(half, -half) * 0.36, Color(dash, dash.a * 0.7), 2.0, true)


func _process(_delta: float) -> void:
	if picture != null and picture.is_visible_in_tree():
		picture.queue_redraw()


# --- Her figures ---

# [name, value, what the upgrades add, the breakdown, shown on the strip, its
# group on the full page].
func stat_rows() -> Array:
	var tuned := meta.tuning(_base)
	var rules := meta.lasting()
	var rows := []
	rows.append([tr("最大HP"), str(tuned.max_hp), _added(tuned.max_hp - _base.max_hp, ""), _breakdown(&"max_hp", str(_base.max_hp), ""), true, 0])
	# What a blow loses to her guard, as an amount: "0" under "damage taken"
	# read as taking none.
	rows.append([tr("ダメージの軽減"), str(tuned.defense), "", _breakdown(&"defense", "0", ""), true, 0])
	rows.append([tr("攻撃力"), _number(tuned.power), "", tr("基礎 %s") % _number(_base.power), true, 0])
	# Her pace against the pace she starts with: pixels a second are not
	# words of the world.
	var pace := roundi(tuned.max_speed / _base.max_speed * 100.0)
	rows.append([tr("移動速度"), "%d%%" % pace, _added(pace - 100, "%"), _breakdown(&"move_speed", "100%", "%", 100.0), true, 0])
	rows.append([tr("ダッシュ"), tr("%d回 / %s秒") % [tuned.dash_charges, _number(tuned.dash_cooldown)], "", tr("基礎 %d回 / %s秒%s%s") % [_base.dash_charges, _number(_base.dash_cooldown), _parts(&"dash_charges", tr("回"), 1.0), _parts(&"dash_cooldown", tr("秒"), 1.0)], true, 0])
	rows.append([tr("被弾後の無敵"), tr("%s秒") % _number(tuned.hurt_mercy), "", _breakdown(&"hurt_mercy", tr("%s秒") % _number(_base.hurt_mercy), tr("秒")), false, 0])
	rows.append([tr("宝石を吸い寄せる範囲"), _cells(GemField.PULL_RADIUS + rules[&"gem_pull"]), "", _breakdown(&"gem_pull", _cells(GemField.PULL_RADIUS), tr("マス"), 1.0 / AreaGround.CELL, CELL_SNAP), false, 1])
	rows.append([tr("回復の報酬"), tr("最大HPの%d%%") % roundi((RunDirector.HEAL_SHARE + rules[&"heal_share"]) * 100.0), "", _breakdown(&"heal_share", "%d%%" % roundi(RunDirector.HEAL_SHARE * 100.0), "%", 100.0), false, 1])
	rows.append([tr("報酬の残響"), "+%d%%" % roundi(rules[&"echo_rate"] * 100.0), "", _breakdown(&"echo_rate", "+0%", "%", 100.0), false, 1])
	rows.append([tr("得る経験値"), "+%d%%" % roundi(rules[&"exp_rate"] * 100.0), "", _breakdown(&"exp_rate", "+0%", "%", 100.0), false, 1])
	rows.append([tr("レベルアップのカード"), tr("%d枚") % (BuildState.OFFER_COUNT + roundi(rules[&"offer_count"])), "", _breakdown(&"offer_count", tr("%d枚") % BuildState.OFFER_COUNT, tr("枚")), false, 1])
	rows.append([tr("引き直し"), tr("探索ごとに%d回") % roundi(rules[&"reroll"]), "", _breakdown(&"reroll", tr("0回"), tr("回")), false, 1])
	rows.append([tr("不屈"), tr("あり") if rules[&"last_stand"] > 0.0 else tr("なし"), "", _breakdown(&"last_stand", tr("なし"), ""), false, 0])
	var rising: Array[String] = []
	if rules[&"level_heal"] > 0.0:
		rising.append(tr("回復%d%%") % roundi(rules[&"level_heal"] * 100.0))
	if rules[&"level_burst"] > 0.0:
		rising.append(tr("衝撃"))
	if rules[&"level_ward"] > 0.0:
		rising.append(tr("無敵%s秒") % _number(rules[&"level_ward"]))
	if rules[&"level_haste"] > 0.0:
		rising.append(tr("振り+%d%%") % roundi(rules[&"level_haste"] * 100.0))
	rows.append([tr("レベルアップの瞬間"), tr("、").join(rising) if not rising.is_empty() else tr("なし"), "", tr("光の癒やし・光の衝撃・光の加護・高揚で増える"), false, 1])
	return rows


# The strip's five figures while the build is shown; turned to her figures,
# every one a row with its breakdown, a group on each slab.
func _show_stats() -> void:
	if meta == null:
		return
	for child in _strip_row.get_children():
		child.free()
	for sheet in _sheets:
		for child in sheet.get_children():
			child.free()
	var rows := stat_rows()
	if not details_open:
		var shown := rows.filter(func(row: Array): return row[4])
		shown_rows = shown.size()
		for row: Array in shown:
			_strip_fact(row)
			HubUI.space(_strip_row).size_flags_vertical = Control.SIZE_FILL
		var more := HubUI.label(_strip_row, tr("詳しく"), &"NoteLabel")
		more.autowrap_mode = TextServer.AUTOWRAP_OFF
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		strip.tooltip_text = tr(STRIP_NOTE)
		return
	shown_rows = rows.size()
	for group in _sheets.size():
		HubUI.label(_sheets[group], tr(GROUPS[group]), &"HeadingLabel")
		for row: Array in rows:
			if row[5] == group:
				_sheet_row(_sheets[group], row)


# One figure on the strip: its name small over its value.
func _strip_fact(row: Array) -> void:
	var cell := VBoxContainer.new()
	cell.theme_type_variation = &"CompactStack"
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip_row.add_child(cell)
	var caption := HubUI.label(cell, row[0], &"NoteLabel")
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	var value := HubUI.label(cell, row[1], &"ItemNameLabel")
	value.autowrap_mode = TextServer.AUTOWRAP_OFF


# One figure on the full page: its name, its value and what the upgrades
# add at the right, where it comes from under them, a hairline under it.
func _sheet_row(sheet: VBoxContainer, row: Array) -> void:
	var box := VBoxContainer.new()
	box.theme_type_variation = &"CompactStack"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size.y = SHEET_ROW_HEIGHT
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.draw.connect(func():
		box.draw_line(Vector2(0.0, box.size.y - 0.5), Vector2(box.size.x, box.size.y - 0.5), box.get_theme_color(&"separator", &"LoadoutSlot"), -1.0))
	sheet.add_child(box)
	var line := HBoxContainer.new()
	line.theme_type_variation = &"CodexLine"
	box.add_child(line)
	var name := HubUI.label(line, row[0], &"BodyLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var added := HubUI.label(line, row[2], &"MutedLabel")
	var value := HubUI.label(line, row[1], &"ItemNameLabel")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label: Label in [name, added, value]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	added.visible = not added.text.is_empty()
	HubUI.label(box, row[3], &"NoteLabel")


# Turns the page between the build and her figures in full.
func toggle_details() -> void:
	details_open = not details_open
	_show_view()
	view_changed.emit()


func _show_view() -> void:
	_deck.visible = not details_open
	strip.visible = not details_open
	_stage_room.visible = not details_open
	for sheet in _sheets:
		sheet.visible = details_open
	_show_stats()
	if not is_visible_in_tree():
		return
	if details_open:
		for index in _sheets.size():
			UIMotion.of(_sheets[index]).appear(UIMotion.STAGGER_TIME * index, UIMotion.WINDOW_TIME)
	else:
		_quiet = true
		slot_buttons[slot].grab_focus()
		_quiet = false
		play_entrance()


func _added(amount: int, unit: String) -> String:
	return "(+%d%s)" % [amount, unit] if amount > 0 else ""


# "基礎 100 ＋ 鍛えた体 +45": the base and each upgrade held that adds to it.
func _breakdown(effect: StringName, base: String, unit: String, scale: float = 1.0, snap: float = 0.01) -> String:
	return tr("基礎 %s%s") % [base, _parts(effect, unit, scale, snap)]


func _parts(effect: StringName, unit: String, scale: float, snap: float = 0.01) -> String:
	var text := ""
	for upgrade in MetaProgress.UPGRADES:
		var rank := meta.rank(upgrade.id)
		if upgrade.effect == effect and rank > 0:
			var amount := upgrade.per_rank * rank * scale
			text += tr("　＋ %s %s%s%s") % [tr(upgrade.display_name), "+" if amount >= 0.0 else "", _number(amount, snap), unit]
	return text


func _number(value: float, snap: float = 0.01) -> String:
	var snapped := snappedf(value, snap)
	return str(roundi(snapped)) if is_equal_approx(snapped, roundf(snapped)) else str(snapped)


# --- Keys ---

# Opening the page: the build, the focus on the chosen slot.
func focus_first() -> void:
	_quiet = true
	if details_open:
		details_open = false
		_show_view()
	slot_buttons[slot].grab_focus()
	_quiet = false


func play_entrance() -> void:
	UIMotion.of(_slot_column).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(_choices).appear(UIMotion.STAGGER_TIME)
	UIMotion.of(_stage).appear(UIMotion.STAGGER_TIME * 2.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_by_pointer = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_by_pointer = false
	var now_pad := _pad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		now_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		now_pad = false
	if now_pad != _pad:
		_pad = now_pad
		_show_slots()
		_mark_choices()
		if not shown_id.is_empty():
			outcome_label.text = _account(shown_id).outcome


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y
	if key or pad:
		toggle_details()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	# Back from her figures returns to the build, and from the list to its
	# slot, before it leaves the page.
	if details_open:
		GameAudio.play(self, &"ui_back", -18.0)
		toggle_details()
		get_viewport().set_input_as_handled()
	elif _focused_choice() >= 0:
		GameAudio.play(self, &"ui_back", -18.0)
		slot_buttons[slot].grab_focus()
		get_viewport().set_input_as_handled()
