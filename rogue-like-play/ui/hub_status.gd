class_name HubStatus
extends Control

# The status page, laid out as the fight shows her actions: on the slab from
# the left, a stone bar with her four slots as the HUD's round sockets
# (EquipSocket), each with its key under it (the attack, fixed to the weapon
# (the sword, or one learned on the weapon branch); the two skills on Q / Y
# and E / B; the special move on R / LB, sealed until one is learned). From
# the chosen slot a line runs down to the shelf of what it can hold, smaller
# sockets (a thing not held yet is its emblem's shadow; the first clears the
# slot; what the slot holds carries a gold diamond, a skill set in the other
# slot that slot's key). At the slab's foot, her figures as the lasting
# upgrades make them, each with what the upgrades add; R (Y) opens the rest.
# In the column on the right, the chosen thing's emblem, name, kind and
# figures, what it does and the one action (equip or clear) as the crest
# button. Choosing a slot shows its tiles; Enter (A) on a slot goes into
# them, Enter on a tile equips it (equip_requested; the hub saves, then calls
# present_equip), and back from the tiles returns to the slot. The pointer
# chooses by resting or clicking, and equips with the button.

signal equip_requested(slot: int, id: StringName)

const SLOT_DIAMETER := 96.0
const TILE_DIAMETER := 72.0
const TILE_COLUMNS := 8
const PICTURE_SIZE := 150.0
const REACH_HEIGHT := 34.0
const UNKNOWN_NAME := "？？？"
const UNKNOWN_NOTE := "強化ツリーのスキルの枝で習得できる"
const UNKNOWN_SPECIAL_NOTE := "強化ツリーの必殺技の枝で習得できる"
const CLEAR_ID := &"clear"
# The slots: id, name, its keys (keyboard, gamepad), the emblem it shows.
const SLOTS := [
	[&"attack", "攻撃", "左クリック", "X", "weapon_sword"],
	[&"skill_1", "スキル1", "Q", "Y", ""],
	[&"skill_2", "スキル2", "E", "B", ""],
	[&"special", "必殺技", "R", "LB", "seal_special"],
]
const SKILL_SLOT_OFFSET := 1
const UNKNOWN_WEAPON_NOTE := "強化ツリーの武器の枝で習得できる"
const ATTACK_SLOT := 0
const SPECIAL_NOTE := "強化ツリーの必殺技の枝で必殺技を覚えると付けられる"
const SPECIAL_SLOT := 3

var meta: MetaProgress
var slot_buttons: Array[EquipSocket] = []
var tiles: Array[EquipSocket] = []
# What each tile holds: a skill's, special move's or weapon's id, or CLEAR_ID.
var tile_ids: Array[StringName] = []
var slot := 1
var shown_id: StringName = &""
var details_open := false
# How many of her figures the table shows.
var shown_rows := 0
var picture: Control
var name_label: Label
var kind_label: Label
var figure_label: Label
var description_label: Label
var action_button: CrestButton
var stats: HBoxContainer
var _slab: VBoxContainer
var _info: VBoxContainer
var _reach: Control
var _tiles: GridContainer
var _tile_note: Label
var _stat_columns: Array[GridContainer] = []
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
	# The bar: her four slots as the fight's HUD shows them.
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"EquipBar"
	_slab.add_child(bar)
	var row := HBoxContainer.new()
	row.theme_type_variation = &"EquipRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)
	for index in SLOTS.size():
		var button := EquipSocket.new(SLOT_DIAMETER)
		row.add_child(button)
		button.pressed.connect(_enter_tiles.bind(index))
		button.focus_entered.connect(_choose_slot.bind(index))
		button.mouse_entered.connect(_rest_on.bind(button))
		slot_buttons.append(button)
	for index in slot_buttons.size():
		slot_buttons[index].focus_neighbor_left = slot_buttons[maxi(0, index - 1)].get_path()
		slot_buttons[index].focus_neighbor_right = slot_buttons[mini(slot_buttons.size() - 1, index + 1)].get_path()
		slot_buttons[index].focus_neighbor_top = slot_buttons[index].get_path()
	# The line from the chosen slot down to its shelf.
	_reach = Control.new()
	_reach.custom_minimum_size.y = REACH_HEIGHT
	_reach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reach.draw.connect(_draw_reach)
	_slab.add_child(_reach)
	var shelf := CenterContainer.new()
	_slab.add_child(shelf)
	_tiles = GridContainer.new()
	_tiles.theme_type_variation = &"EquipShelf"
	_tiles.columns = TILE_COLUMNS
	_tiles.item_rect_changed.connect(_reach.queue_redraw)
	shelf.add_child(_tiles)
	_tile_note = _centered(HubUI.label(_slab, "", &"MutedLabel"))
	HubUI.space(_slab)
	HubUI.rule(_slab)
	# Her figures, in two columns at the slab's foot.
	stats = HBoxContainer.new()
	stats.theme_type_variation = &"StatusStats"
	_slab.add_child(stats)
	for side in 2:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(grid)
		_stat_columns.append(grid)
	_info = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	# The account stands inside the ornate frame laid over the column, as on
	# the upgrade tree's column.
	var info_panel := _info.get_parent() as Control
	info_panel.clip_contents = true
	var info_margin := MarginContainer.new()
	info_margin.theme_type_variation = &"StatusInfoMargin"
	info_panel.remove_child(_info)
	info_panel.add_child(info_margin)
	info_margin.add_child(_info)
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
	HubUI.rule(_info)
	figure_label = _centered(HubUI.label(_info, "", &"ValueLabel"))
	description_label = HubUI.label(_info, "", &"DescriptionLabel")
	HubUI.space(_info)
	# Setting a thing in a slot: the crest with the lobby's mark for the status.
	action_button = CrestButton.new()
	action_button.name = "Equip"
	action_button.kind = "装備"
	action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_button.pressed.connect(_act)
	_info.add_child(action_button)
	HubUI.ornate_frame(info_panel)
	UIMotion.bind_buttons(_info)


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


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
			return meta.weapon if meta != null else &"sword"
		&"special":
			if meta == null or not meta.owns_any_special():
				return &"special"
			return meta.special
	return meta.loadout[index - SKILL_SLOT_OFFSET] if meta != null else &""


func _slot_key(index: int) -> String:
	return SLOTS[index][3] if _pad else SLOTS[index][2]


func _show_slots() -> void:
	if meta == null:
		return
	for index in SLOTS.size():
		var entry: Array = SLOTS[index]
		var button := slot_buttons[index]
		var held := _slot_content(index)
		var skill := MetaProgress.find_skill(held)
		var move := MetaProgress.find_special(held)
		var weapon := MetaProgress.find_weapon(held)
		var content := "空き"
		var emblem := ""
		if held == &"special":
			content = "封印"
			emblem = entry[4]
		elif weapon != null:
			content = weapon.display_name
			emblem = weapon.emblem
		elif skill != null:
			content = skill.display_name
			emblem = skill.emblem
		elif move != null:
			content = move.display_name
			emblem = move.emblem
		button.emblem = EmblemIcons.texture(emblem)
		button.empty = emblem.is_empty()
		button.sealed = held == &"special"
		button.key = _slot_key(index)
		button.lit = index == slot
		button.tooltip_text = "%s（%s）：%s" % [entry[1], _slot_key(index), content]
		button.queue_redraw()


func _show_tiles() -> void:
	if meta == null:
		return
	# The tile pressed may still be sending its signal.
	for tile in tiles:
		_tiles.remove_child(tile)
		tile.queue_free()
	tiles.clear()
	tile_ids.clear()
	var kind: StringName = SLOTS[slot][0]
	_tile_note.text = ""
	match kind:
		&"attack":
			for weapon in MetaProgress.WEAPONS:
				_add_tile(weapon.id, weapon.emblem, weapon.display_name, not meta.owns_weapon(weapon.id), UNKNOWN_WEAPON_NOTE)
		&"special":
			if not meta.owns_any_special():
				_tile_note.text = SPECIAL_NOTE
			else:
				_add_tile(CLEAR_ID, "", "このスロットを空ける", false, "")
				for move in MetaProgress.SPECIALS:
					_add_tile(move.id, move.emblem, move.display_name, not meta.owns_special(move.id), UNKNOWN_SPECIAL_NOTE)
		_:
			_add_tile(CLEAR_ID, "", "このスロットを空ける", false, "")
			for skill in MetaProgress.SKILLS:
				_add_tile(skill.id, skill.emblem, skill.display_name, not meta.owns_skill(skill.id), UNKNOWN_NOTE)
	_mark_tiles()
	for index in tiles.size():
		var tile := tiles[index]
		tile.focus_neighbor_top = slot_buttons[slot].get_path()
		if index == 0:
			tile.focus_neighbor_left = tile.get_path()
		if index == tiles.size() - 1:
			tile.focus_neighbor_right = tile.get_path()
	slot_buttons[slot].focus_neighbor_bottom = tiles[0].get_path() if not tiles.is_empty() else slot_buttons[slot].get_path()
	_reach.queue_redraw()


func _add_tile(id: StringName, emblem: String, tooltip: String, unknown: bool, unknown_note: String) -> void:
	var tile := EquipSocket.new(TILE_DIAMETER)
	_tiles.add_child(tile)
	tile.emblem = EmblemIcons.texture(emblem) if not emblem.is_empty() else null
	tile.clears = id == CLEAR_ID
	tile.unknown = unknown
	tile.tooltip_text = unknown_note if unknown else tooltip
	var index := tiles.size()
	tile.focus_entered.connect(_choose_tile.bind(index))
	tile.pressed.connect(_press_tile.bind(index))
	tile.mouse_entered.connect(_rest_on.bind(tile))
	tiles.append(tile)
	tile_ids.append(id)


# What the chosen slot holds carries the gold diamond; a skill set in the
# other skill slot carries that slot's key.
func _mark_tiles() -> void:
	if meta == null:
		return
	var held := _slot_content(slot)
	for index in tiles.size():
		var id := tile_ids[index]
		var tile := tiles[index]
		tile.held = id == held and id != CLEAR_ID and not tile.unknown
		var key := ""
		if SLOTS[slot][0] in [&"skill_1", &"skill_2"] and meta.owns_skill(id):
			var at := meta.slot_of(id)
			if at >= 0 and at != slot - SKILL_SLOT_OFFSET:
				key = _slot_key(at + SKILL_SLOT_OFFSET)
		tile.key = key
		tile.queue_redraw()


func _choose_slot(index: int) -> void:
	if index != slot:
		slot = index
		for at in slot_buttons.size():
			slot_buttons[at].lit = at == slot
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
	if meta == null:
		return
	if slot == ATTACK_SLOT:
		if meta.owns_weapon(id) and meta.weapon != id:
			equip_requested.emit(MetaProgress.WEAPON_SLOT, id)
		return
	if slot == SPECIAL_SLOT:
		var move := &"" if id == CLEAR_ID else id
		if (move.is_empty() and meta.special.is_empty()) or (not move.is_empty() and (not meta.owns_special(move) or meta.special == move)):
			return
		equip_requested.emit(MetaProgress.SPECIAL_SLOT, move)
		return
	if SLOTS[slot][0] not in [&"skill_1", &"skill_2"]:
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
	UIMotion.of(slot_buttons[slot]).pulse(1.06, UIMotion.GOLD_TIME)
	slot_buttons[slot].grab_focus()


# Resting the pointer on a slot or tile a moment chooses it.
func _rest_on(target: Control) -> void:
	_hover_target = target
	await get_tree().create_timer(HubLobby.HOVER_INTENT).timeout
	if _hover_target == target and is_instance_valid(target) and target.is_visible_in_tree() and not target.has_focus():
		target.grab_focus()


# From the chosen slot's foot down, then along the shelf beneath it, in the
# rail's gilt.
func _draw_reach() -> void:
	if slot_buttons.is_empty() or slot >= slot_buttons.size():
		return
	var rail := _reach.get_theme_color(&"rail", &"HubLobby")
	var origin := _reach.get_global_transform().affine_inverse()
	var socket := slot_buttons[slot]
	var top := origin * (socket.get_global_rect().get_center())
	var from := Vector2(top.x, 0.0)
	var middle := _reach.size.y * 0.55
	_reach.draw_line(from, Vector2(from.x, middle), Color(rail, 0.7), 1.0, true)
	if tiles.is_empty():
		return
	var shelf := Rect2(origin * _tiles.global_position, _tiles.size)
	var left := minf(from.x, shelf.position.x + TILE_DIAMETER * 0.5)
	var right := maxf(from.x, shelf.end.x - TILE_DIAMETER * 0.5)
	_reach.draw_line(Vector2(left, middle), Vector2(right, middle), Color(rail, 0.45), 1.0, true)
	HubUI.diamond(_reach, Vector2(from.x, middle), 3.0, Color(rail, 0.85))


# --- The column ---

func _tell(id: StringName) -> void:
	if meta == null or name_label == null:
		return
	shown_id = id
	_unknown = false
	figure_label.show()
	description_label.show()
	action_button.show()
	var skill := MetaProgress.find_skill(id)
	var move := MetaProgress.find_special(id)
	var weapon := MetaProgress.find_weapon(id)
	var in_skill_slot: bool = SLOTS[slot][0] in [&"skill_1", &"skill_2"]
	var slot_index := slot - SKILL_SLOT_OFFSET
	if weapon != null:
		_tell_weapon(weapon)
		picture.queue_redraw()
		return
	match id:
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
			description_label.hide()
			action_button.text = "外す"
			action_button.disabled = meta.loadout[slot_index].is_empty() if in_skill_slot else (meta.special.is_empty() if slot == SPECIAL_SLOT else true)
			action_button.visible = id == CLEAR_ID
		_:
			if move != null:
				_tell_special(move)
				picture.queue_redraw()
				return
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
				kind_label.text = "スキル　再使用 %s秒" % _number(skill.cooldown)
				figure_label.text = "威力 攻撃力の%d%%\n%s" % [roundi(skill.attack.damage_scale * 100.0), _reach_text(skill.attack)]
				description_label.text = skill.description
				var here := in_skill_slot and at == slot_index
				action_button.text = "装備中" if here else ("入れ替える" if at >= 0 else "装備する")
				action_button.disabled = here or not in_skill_slot
				action_button.visible = in_skill_slot
	picture.queue_redraw()


# The column for a weapon: unknown until learned, else its combo, its
# charged attack's power and reach, and holding it.
func _tell_weapon(weapon: Moveset) -> void:
	_emblem = weapon.emblem
	if not meta.owns_weapon(weapon.id):
		_unknown = true
		name_label.text = UNKNOWN_NAME
		kind_label.text = "武器"
		figure_label.hide()
		description_label.text = UNKNOWN_WEAPON_NOTE
		action_button.hide()
		return
	var held := meta.weapon == weapon.id
	name_label.text = weapon.display_name
	kind_label.text = "武器"
	var strongest := 0.0
	for swing in weapon.combo:
		strongest = maxf(strongest, swing.damage_scale)
	figure_label.text = "連撃 %d段（攻撃力の%d%%まで）\n溜め 攻撃力の%d%%　%s" % [weapon.combo.size(), roundi(strongest * 100.0), roundi(weapon.charged.damage_scale * 100.0), _reach_text(weapon.charged)]
	description_label.text = weapon.description
	action_button.text = "装備中" if held else "持ち替える"
	action_button.disabled = held or slot != ATTACK_SLOT
	action_button.visible = slot == ATTACK_SLOT


# The column for a special move: unknown until learned, else its gauge,
# power (with the lasting upgrades) and reach, and setting it in the slot.
func _tell_special(move: SpecialData) -> void:
	_emblem = move.emblem
	if not meta.owns_special(move.id):
		_unknown = true
		name_label.text = UNKNOWN_NAME
		kind_label.text = "必殺技"
		figure_label.hide()
		description_label.text = UNKNOWN_SPECIAL_NOTE
		action_button.hide()
		return
	name_label.text = move.display_name
	kind_label.text = "必殺技　ゲージ %s" % _number(move.charge)
	var power := 1.0 + meta.bonus(&"special_power")
	figure_label.text = "威力 攻撃力の%d%%\n%s" % [roundi(move.attack.damage_scale * power * 100.0), _reach_text(move.attack)]
	description_label.text = move.description
	var here := meta.special == move.id
	action_button.text = "装備中" if here else "装備する"
	action_button.disabled = here or slot != SPECIAL_SLOT
	action_button.visible = slot == SPECIAL_SLOT


# How far a skill reaches, as its shape measures it: a wave's flight, a
# line's length, a circle's radius, an arc's reach.
func _reach_text(attack: AttackData) -> String:
	if attack.projectile != null:
		return "射程 %dpx" % roundi(attack.projectile.distance)
	match attack.shape:
		AttackData.Shape.LINE:
			return "範囲 長さ%dpx" % roundi(attack.reach)
		AttackData.Shape.CIRCLE:
			return "範囲 半径%dpx" % roundi(attack.reach)
	return "範囲 %dpx" % roundi(attack.reach)


func _draw_picture() -> void:
	var emblem := EmblemIcons.texture(_emblem)
	if emblem != null:
		picture.draw_texture_rect(emblem, Rect2(Vector2.ZERO, picture.size), false, get_theme_color(&"unknown_tint", &"EquipSocket") if _unknown else Color.WHITE)


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


# The rows shown, the first half in the left column and the rest in the right.
func _show_stats() -> void:
	if meta == null:
		return
	for grid in _stat_columns:
		for child in grid.get_children():
			child.free()
	var shown := stat_rows().filter(func(row: Array): return row[4] or details_open)
	shown_rows = shown.size()
	var half := ceili(shown.size() * 0.5)
	for index in shown.size():
		var row: Array = shown[index]
		var grid := _stat_columns[0 if index < half else 1]
		var name := HubUI.label(grid, row[0], &"BodyLabel")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := HubUI.label(grid, row[1], &"BodyLabel")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var added := HubUI.label(grid, row[2], &"MutedLabel")
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
		_mark_tiles()


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
