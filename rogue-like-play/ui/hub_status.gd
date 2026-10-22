class_name HubStatus
extends Control

# The status page, laid out as action games commonly lay out equipment: on
# the slab from the left, her four slots in a row (the attack, fixed to the
# sword; the two skills on Q / Y and E / B; the special move, sealed for
# now) and under them, as tiles, what the chosen slot can hold (a skill not
# held yet is a dark "？？？"; the first tile clears the slot). In the column
# on the right, the chosen thing's emblem, name, kind and figures, what it
# does and the one action (equip or clear), and under it her figures as the
# lasting upgrades make them, each with what the upgrades add; R (Y) opens
# the rest. Choosing a slot shows its tiles; Enter (A) on a slot goes into
# them, Enter on a tile equips it (equip_requested; the hub saves, then
# calls present_equip), and back from the tiles returns to the slot. The
# pointer chooses by resting or clicking, and equips with the button.

signal equip_requested(slot: int, id: StringName)

const SLOT_SIZE := Vector2(150, 150)
const TILE_SIZE := Vector2(128, 140)
const TILE_COLUMNS := 5
const PICTURE_SIZE := 120.0
const UNKNOWN_NAME := "？？？"
const UNKNOWN_NOTE := "強化ツリーのスキルの枝で習得できる"
const CLEAR_ID := &"clear"
# The slots: id, name, its keys (keyboard, gamepad), the emblem it shows.
const SLOTS := [
	[&"attack", "攻撃", "左クリック", "X", "sword_damage"],
	[&"skill_1", "スキル1", "Q", "Y", ""],
	[&"skill_2", "スキル2", "E", "B", ""],
	[&"special", "必殺技", "", "", "seal_special"],
]
const SKILL_SLOT_OFFSET := 1
const ATTACK_NOTE := "3段の連撃と、長押しで溜め攻撃。武器はまだ剣だけ。"
const SPECIAL_NOTE := "強化ツリーの必殺技の枝を開くと付けられる"

var meta: MetaProgress
var slot_buttons: Array[Button] = []
var tiles: Array[Button] = []
# What each tile holds: a SkillData, CLEAR_ID, or the sword's moveset id.
var tile_ids: Array[StringName] = []
var slot := 1
var shown_id: StringName = &""
var details_open := false
var picture: Control
var name_label: Label
var kind_label: Label
var figure_label: Label
var description_label: Label
var action_button: Button
var tiles_label: Label
var stats: GridContainer
var _slab: VBoxContainer
var _info: VBoxContainer
var _tiles: GridContainer
var _tile_note: Label
var _emblem := ""
var _unknown := false
var _pad := false
var _hover_target: Control
# The last press came from the pointer (it chooses, never acts).
var _by_pointer := false
var _base: HeroTuning


func _ready() -> void:
	_base = load("res://data/hero/mio.tres")
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slab = HubUI.open_column(columns, 2.1, &"SlabSolid")
	HubUI.label(_slab, "装備", &"NoteLabel")
	var row := HBoxContainer.new()
	row.theme_type_variation = &"ListRow"
	_slab.add_child(row)
	for index in SLOTS.size():
		var button := _card(row, SLOT_SIZE)
		button.pressed.connect(_enter_tiles.bind(index))
		button.focus_entered.connect(_choose_slot.bind(index))
		button.mouse_entered.connect(_rest_on.bind(button))
		slot_buttons.append(button)
	for index in slot_buttons.size():
		slot_buttons[index].focus_neighbor_left = slot_buttons[maxi(0, index - 1)].get_path()
		slot_buttons[index].focus_neighbor_right = slot_buttons[mini(slot_buttons.size() - 1, index + 1)].get_path()
		slot_buttons[index].focus_neighbor_top = slot_buttons[index].get_path()
	HubUI.rule(_slab)
	tiles_label = HubUI.label(_slab, "", &"NoteLabel")
	_tiles = GridContainer.new()
	_tiles.columns = TILE_COLUMNS
	_slab.add_child(_tiles)
	_tile_note = HubUI.label(_slab, "", &"MutedLabel")
	_info = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	(_info.get_parent() as Control).clip_contents = true
	_info.theme_type_variation = &"DetailStack"
	picture = Control.new()
	picture.custom_minimum_size = Vector2.ONE * PICTURE_SIZE
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.draw.connect(_draw_picture)
	_info.add_child(picture)
	name_label = _centered(HubUI.label(_info, "", &"HeadingLabel"))
	kind_label = _centered(HubUI.label(_info, "", &"MutedLabel"))
	figure_label = _centered(HubUI.label(_info, "", &"ValueLabel"))
	description_label = HubUI.label(_info, "", &"DescriptionLabel")
	action_button = HubUI.primary_action(_info, "", _act)
	HubUI.rule(_info)
	HubUI.label(_info, "ステータス", &"NoteLabel")
	stats = GridContainer.new()
	stats.columns = 3
	_info.add_child(stats)
	UIMotion.bind_buttons(_slab)
	UIMotion.bind_buttons(_info)


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _card(parent: Node, extent: Vector2) -> Button:
	var card := Button.new()
	card.theme_type_variation = &"CardButton"
	card.custom_minimum_size = extent
	card.expand_icon = true
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(card)
	return card


func refresh(current: MetaProgress) -> void:
	meta = current
	_show_slots()
	_show_tiles()
	_show_stats()
	_tell(shown_id if not shown_id.is_empty() else _slot_content(slot))


# --- The slots and their tiles ---

func _slot_content(index: int) -> StringName:
	match SLOTS[index][0]:
		&"attack":
			return &"sword"
		&"special":
			return &"special"
	return meta.loadout[index - SKILL_SLOT_OFFSET] if meta != null else &""


func _show_slots() -> void:
	if meta == null:
		return
	for index in SLOTS.size():
		var entry: Array = SLOTS[index]
		var button := slot_buttons[index]
		var held := _slot_content(index)
		var skill := MetaProgress.find_skill(held)
		var keys: String = entry[3] if _pad else entry[2]
		var content := "封印" if held == &"special" else ("剣" if held == &"sword" else (skill.display_name if skill != null else "空き"))
		button.text = "%s%s\n%s" % [entry[1], "（%s）" % keys if not keys.is_empty() else "", content]
		button.icon = EmblemIcons.texture(skill.emblem if skill != null else entry[4])


func _show_tiles() -> void:
	if meta == null:
		return
	for tile in tiles:
		tile.free()
	tiles.clear()
	tile_ids.clear()
	var kind: StringName = SLOTS[slot][0]
	tiles_label.text = "%sに付けるもの" % SLOTS[slot][1]
	_tile_note.text = ""
	match kind:
		&"attack":
			_add_tile(&"sword", "剣\n装備中", EmblemIcons.texture("sword_damage"), "")
		&"special":
			_tile_note.text = SPECIAL_NOTE
		_:
			_add_tile(CLEAR_ID, "外す", null, "このスロットを空ける")
			for skill in MetaProgress.SKILLS:
				if not meta.owns_skill(skill.id):
					_add_tile(skill.id, UNKNOWN_NAME, null, UNKNOWN_NOTE)
					continue
				var at := meta.slot_of(skill.id)
				var mark := "" if at < 0 else ("\n装備中" if at == slot - SKILL_SLOT_OFFSET else "\n%s" % SLOTS[at + SKILL_SLOT_OFFSET][1])
				_add_tile(skill.id, skill.display_name + mark, EmblemIcons.texture(skill.emblem), skill.display_name)
	for index in tiles.size():
		var tile := tiles[index]
		tile.focus_neighbor_top = slot_buttons[slot].get_path()
		if index == 0:
			tile.focus_neighbor_left = tile.get_path()
		if index == tiles.size() - 1:
			tile.focus_neighbor_right = tile.get_path()
	slot_buttons[slot].focus_neighbor_bottom = tiles[0].get_path() if not tiles.is_empty() else slot_buttons[slot].get_path()
	UIMotion.bind_buttons(_tiles)


func _add_tile(id: StringName, text: String, icon: Texture2D, tooltip: String) -> void:
	var tile := _card(_tiles, TILE_SIZE)
	tile.text = text
	tile.icon = icon
	tile.tooltip_text = tooltip
	var index := tiles.size()
	tile.focus_entered.connect(_choose_tile.bind(index))
	tile.pressed.connect(_press_tile.bind(index))
	tile.mouse_entered.connect(_rest_on.bind(tile))
	tiles.append(tile)
	tile_ids.append(id)


func _choose_slot(index: int) -> void:
	if index != slot:
		slot = index
		_show_tiles()
	_tell(_slot_content(index))


func _choose_tile(index: int) -> void:
	if index < tile_ids.size():
		_tell(tile_ids[index])


# Enter (A) on a slot: into its tiles, at the one it holds. A click only
# chooses the slot.
func _enter_tiles(index: int) -> void:
	_choose_slot(index)
	if _by_pointer or tiles.is_empty():
		return
	var at := tile_ids.find(_slot_content(index))
	tiles[maxi(0, at)].grab_focus()


# Enter (A) on a tile equips it; a click only chooses it, and the column's
# button equips.
func _press_tile(index: int) -> void:
	if index < tile_ids.size() and not _by_pointer:
		_equip(tile_ids[index])


func _equip(id: StringName) -> void:
	if meta == null or SLOTS[slot][0] not in [&"skill_1", &"skill_2"]:
		return
	var target := &"" if id == CLEAR_ID else id
	if target.is_empty() and meta.loadout[slot - SKILL_SLOT_OFFSET].is_empty():
		return
	if not target.is_empty() and (not meta.owns_skill(target) or meta.slot_of(target) == slot - SKILL_SLOT_OFFSET):
		return
	equip_requested.emit(slot - SKILL_SLOT_OFFSET, target)


func _act() -> void:
	_equip(shown_id)


# After an equip was saved: the slot's moment, and the focus back on it.
func present_equip() -> void:
	UIMotion.of(slot_buttons[slot]).pulse(1.04, UIMotion.GOLD_TIME)
	slot_buttons[slot].grab_focus()


# Resting the pointer on a slot or tile a moment chooses it.
func _rest_on(target: Control) -> void:
	_hover_target = target
	await get_tree().create_timer(HubLobby.HOVER_INTENT).timeout
	if _hover_target == target and is_instance_valid(target) and target.is_visible_in_tree() and not target.has_focus():
		target.grab_focus()


# --- The column ---

func _tell(id: StringName) -> void:
	if meta == null or name_label == null:
		return
	shown_id = id
	_unknown = false
	figure_label.show()
	action_button.show()
	var skill := MetaProgress.find_skill(id)
	var in_skill_slot: bool = SLOTS[slot][0] in [&"skill_1", &"skill_2"]
	var slot_index := slot - SKILL_SLOT_OFFSET
	match id:
		&"sword":
			_emblem = "sword_damage"
			name_label.text = "剣"
			kind_label.text = "攻撃　左クリック・X"
			figure_label.text = "攻撃力 %s" % _number(_base.power)
			description_label.text = ATTACK_NOTE
			action_button.hide()
		&"special":
			_emblem = "seal_special"
			name_label.text = "必殺技"
			kind_label.text = "未開放の枝"
			figure_label.hide()
			description_label.text = SPECIAL_NOTE
			action_button.hide()
		CLEAR_ID, &"":
			_emblem = ""
			name_label.text = "空き" if id.is_empty() else "外す"
			kind_label.text = SLOTS[slot][1]
			figure_label.hide()
			description_label.text = "このスロットには何も付いていない。" if id.is_empty() else "このスロットを空ける。"
			action_button.text = "外す"
			action_button.disabled = meta.loadout[slot_index].is_empty() if in_skill_slot else true
			action_button.visible = id == CLEAR_ID
		_:
			if skill == null:
				return
			if not meta.owns_skill(skill.id):
				_unknown = true
				_emblem = skill.emblem
				name_label.text = UNKNOWN_NAME
				kind_label.text = "スキル"
				figure_label.hide()
				description_label.text = UNKNOWN_NOTE
				action_button.hide()
			else:
				_emblem = skill.emblem
				name_label.text = skill.display_name
				var at := meta.slot_of(skill.id)
				kind_label.text = "スキル　再使用 %s秒%s" % [_number(skill.cooldown), "　%s" % SLOTS[at + SKILL_SLOT_OFFSET][1] if at >= 0 else ""]
				figure_label.text = "威力 攻撃力の%d%%\n範囲 半径%dpx" % [roundi(skill.attack.damage_scale * 100.0), roundi(skill.attack.reach)]
				description_label.text = skill.description
				var here := in_skill_slot and at == slot_index
				action_button.text = "装備中" if here else ("入れ替える" if at >= 0 else "装備する")
				action_button.disabled = here or not in_skill_slot
				action_button.visible = in_skill_slot
	picture.queue_redraw()


func _draw_picture() -> void:
	var emblem := EmblemIcons.texture(_emblem)
	if emblem != null:
		picture.draw_texture_rect(emblem, Rect2(Vector2.ZERO, picture.size), false, Color(0.12, 0.12, 0.12, 1.0) if _unknown else Color.WHITE)


# --- Her figures ---

# [name, value, what the upgrades add, the breakdown, shown without details].
func stat_rows() -> Array:
	var tuned := meta.tuning(_base)
	var rules := meta.lasting()
	var rows := []
	rows.append(["最大HP", str(tuned.max_hp), _added(tuned.max_hp - _base.max_hp, ""), _breakdown(&"max_hp", str(_base.max_hp), ""), true])
	rows.append(["受けるダメージ", "-%d" % tuned.defense if tuned.defense > 0 else "0", "", _breakdown(&"defense", "0", ""), true])
	rows.append(["攻撃力", _number(tuned.power), "", "基礎 %s" % _number(_base.power), true])
	rows.append(["移動速度", str(roundi(tuned.max_speed)), _added(roundi(tuned.max_speed - _base.max_speed), ""), _breakdown(&"move_speed", str(roundi(_base.max_speed)), "%", 100.0), true])
	rows.append(["ダッシュ", "%d回 / %s秒" % [tuned.dash_charges, _number(tuned.dash_cooldown)], "", "基礎 %d回 / %s秒%s%s" % [_base.dash_charges, _number(_base.dash_cooldown), _parts(&"dash_charges", "回", 1.0), _parts(&"dash_cooldown", "秒", 1.0)], true])
	rows.append(["被弾後の無敵", "%s秒" % _number(tuned.hurt_mercy), "", _breakdown(&"hurt_mercy", "%s秒" % _number(_base.hurt_mercy), "秒"), false])
	rows.append(["宝石を吸い寄せる範囲", "%dpx" % roundi(GemField.PULL_RADIUS + rules[&"gem_pull"]), "", _breakdown(&"gem_pull", "%dpx" % roundi(GemField.PULL_RADIUS), "px"), false])
	rows.append(["回復の報酬", "最大HPの%d%%" % roundi((RunDirector.HEAL_SHARE + rules[&"heal_share"]) * 100.0), "", _breakdown(&"heal_share", "%d%%" % roundi(RunDirector.HEAL_SHARE * 100.0), "%", 100.0), false])
	rows.append(["報酬の残響", "+%d%%" % roundi(rules[&"echo_rate"] * 100.0), "", _breakdown(&"echo_rate", "+0%", "%", 100.0), false])
	rows.append(["得る経験値", "+%d%%" % roundi(rules[&"exp_rate"] * 100.0), "", _breakdown(&"exp_rate", "+0%", "%", 100.0), false])
	rows.append(["レベルアップのカード", "%d枚" % (BuildState.OFFER_COUNT + roundi(rules[&"offer_count"])), "", _breakdown(&"offer_count", "%d枚" % BuildState.OFFER_COUNT, "枚"), false])
	rows.append(["引き直し", "1ランに%d回" % roundi(rules[&"reroll"]), "", _breakdown(&"reroll", "0回", "回"), false])
	rows.append(["不屈", "あり" if rules[&"last_stand"] > 0.0 else "なし", "", _breakdown(&"last_stand", "なし", ""), false])
	var rising: Array[String] = []
	if rules[&"level_heal"] > 0.0:
		rising.append("回復%d%%" % roundi(rules[&"level_heal"] * 100.0))
	if rules[&"level_burst"] > 0.0:
		rising.append("衝撃")
	if rules[&"level_ward"] > 0.0:
		rising.append("無敵%s秒" % _number(rules[&"level_ward"]))
	if rules[&"level_haste"] > 0.0:
		rising.append("振り+%d%%" % roundi(rules[&"level_haste"] * 100.0))
	rows.append(["レベルアップの瞬間", "、".join(rising) if not rising.is_empty() else "なし", "", "光の癒やし・光の衝撃・光の加護・高揚で増える", false])
	return rows


func _show_stats() -> void:
	if meta == null:
		return
	for child in stats.get_children():
		child.free()
	for row: Array in stat_rows():
		if not row[4] and not details_open:
			continue
		var name := HubUI.label(stats, row[0], &"BodyLabel")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := HubUI.label(stats, row[1], &"BodyLabel")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var added := HubUI.label(stats, row[2], &"MutedLabel")
		added.custom_minimum_size.x = 56
		for label: Label in [name, value, added]:
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.tooltip_text = row[3]
			label.mouse_filter = Control.MOUSE_FILTER_PASS


func toggle_details() -> void:
	details_open = not details_open
	_show_stats()


func _added(amount: int, unit: String) -> String:
	return "(+%d%s)" % [amount, unit] if amount > 0 else ""


# "基礎 100 ＋ 鍛えた体 +45": the base and each upgrade held that adds to it.
func _breakdown(effect: StringName, base: String, unit: String, scale: float = 1.0) -> String:
	return "基礎 %s%s" % [base, _parts(effect, unit, scale)]


func _parts(effect: StringName, unit: String, scale: float) -> String:
	var text := ""
	for upgrade in MetaProgress.UPGRADES:
		var rank := meta.rank(upgrade.id)
		if upgrade.effect == effect and rank > 0:
			var amount := upgrade.per_rank * rank * scale
			text += "　＋ %s %s%s%s" % [upgrade.display_name, "+" if amount >= 0.0 else "", _number(amount), unit]
	return text


func _number(value: float) -> String:
	var snapped := snappedf(value, 0.01)
	return str(roundi(snapped)) if is_equal_approx(snapped, roundf(snapped)) else str(snapped)


# --- Keys ---

func focus_first() -> void:
	slot_buttons[slot].grab_focus()


func play_entrance() -> void:
	UIMotion.of(_slab).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(_info).appear(UIMotion.STAGGER_TIME)


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


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y
	if key or pad:
		toggle_details()
		get_viewport().set_input_as_handled()
		return
	# Back from the tiles returns to their slot before it leaves the page.
	if event.is_action_pressed(&"ui_cancel") and tiles.has(get_viewport().gui_get_focus_owner()):
		slot_buttons[slot].grab_focus()
		get_viewport().set_input_as_handled()
