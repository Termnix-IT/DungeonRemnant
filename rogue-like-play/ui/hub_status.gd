class_name HubStatus
extends Control

# The status page, under the upgrades' night sky: four pillars of light, one
# for each of her slots (the attack, the two skills, the special move), so
# that every slot and everything it can hold is in sight at once, as the
# upgrades' chart shows its whole tree. At the head of a pillar is the star
# of what the slot holds now; down it hang the things it can hold, stars on
# a line, each with its name: gold for what is held, a blue rim for what
# could be set, a note for one another slot holds, a dark shape for one not
# learned (a slot that can be emptied lists "外す" first). The pillar the
# cursor is in is lit. The card at the right is the entry under the cursor
# in full: its picture, what it is, its figures set beside those of what
# the slot holds now where they differ, what setting it would do, and the
# one action. Under the card a plate with her main figures opens all of
# them, written in full over the pillars with each one's breakdown.
#
# Left and right (or Q / E, LB / RB) go from pillar to pillar and past the
# last to her figures, up and down along a pillar; Enter (A) sets the entry
# under the cursor: the page asks for the equip (equip_requested) and, once
# Main has saved it, the stars of the slots it changed flare
# (present_equip). X empties the slot. R (Y) opens her figures and comes
# back. The pointer chooses a pillar by its head and an entry by its row; a
# second click on the chosen row sets it.
#
# The page is one focusable control that draws itself in a design space of
# 1520x686 scaled to its rect, in the colours and faces of the theme's
# StarChart type, which it shares with the upgrades. The sky is the
# upgrades' own shader (ui/star_chart/star_sky.gdshader) on a rect that
# covers the whole screen. The pointer acts through zones named while
# drawing.

signal equip_requested(slot: int, id: StringName)
# Her figures opened or closed: the page's keys have changed.
signal view_changed

enum State { FREE, HERE, ELSEWHERE, UNKNOWN }

const SKY := preload("res://ui/star_chart/star_sky.gdshader")
const DESIGN := Vector2(1520.0, 686.0)
# The pillars: where the first begins, how wide each is and the room between
# them, the star at a pillar's head, and the stars hung down it.
const LEFT := 24.0
const WIDE := 244.0
const GAP := 12.0
const TOP := 14.0
const HEAD := Vector2(0.0, 116.0)
const HEAD_STAR := 40.0
const FIRST := 250.0
const STEP := 62.0
const SMALL := 20.0
const CARD := Rect2(1064.0, 4.0, 440.0, 620.0)
# The plate under the card that opens her figures, and where they are written.
const FIGURES_PLATE := Rect2(1064.0, 634.0, 440.0, 48.0)
const FIGURES_ROOM := Rect2(24.0, 4.0, 1024.0, 678.0)
const BREATH := 3.0
# The sky runs this far past the screen's edges, to cover it as the page
# slides in.
const SKY_MARGIN := 240.0
const TURN_TIME := UIMotion.ENTER_TIME
const SEAL_TIME := UIMotion.MOMENT_TIME + UIMotion.GOLD_TIME
const REFUSE_TIME := 0.3
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
# [kind, name, key, pad button, emblem of an empty slot].
const SLOTS := [
	[&"attack", "攻撃", "左クリック", "X", "weapon_sword"],
	[&"skill_1", "スキル1", "Q", "Y", ""],
	[&"skill_2", "スキル2", "E", "B", ""],
	[&"special", "必殺技", "R", "LB", "seal_special"],
]
const SKILL_SLOT_OFFSET := 1
const ATTACK_SLOT := 0
const SPECIAL_SLOT := 3
# The view after the slots': her figures.
const FIGURES := 4
const FIGURES_NAME := "能力"
# Her figures' two groups, a page each.
const GROUPS := ["戦う力", "探索と成長"]

var meta: MetaProgress
# The slot the cursor is in, and whether her figures are open over the pillars.
var slot := 1
var details_open := false
# The cursor's row in the open slot's index, and the index itself:
# {id, emblem, name, note, state, other} an entry (`other`: the slot that
# holds it now, or -1).
var row := 0
var entries: Array = []
# What the card tells: the account of the entry under the cursor.
var told := {}
var shown_id: StringName = &""
# How many of her figures the open pages show.
var shown_rows := 0
var _base: HeroTuning
var _pad := false
# The slots an equip asked for would change, for the moment once it is saved.
var _changing: Array[int] = []
var _sealed: Array[int] = []
var _sky: ColorRect
# Slot -> its index, for the pillars the cursor is not in.
var _others := {}
var _clock := 0.0
var _kicks := {}
var _way := 1.0
var _zones: Array = []
var _hover: Variant = null
var _origin := Vector2.ZERO
var _zoom := 1.0
var _fade := 1.0
# The page is arranging itself: moving the cursor makes no sound.
var _quiet := true


func _ready() -> void:
	_base = load("res://data/hero/mio.tres")
	theme_type_variation = &"StarChart"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sky = ColorRect.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.show_behind_parent = true
	var night := ShaderMaterial.new()
	night.shader = SKY
	_sky.material = night
	add_child(_sky)
	resized.connect(_fit)
	theme_changed.connect(_fit)
	visibility_changed.connect(_fit)
	get_viewport().size_changed.connect(_fit.call_deferred)
	_fit()


# Places the design space in the rect, and the sky over the whole screen.
func _fit() -> void:
	if _sky == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_zoom = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = ((size - DESIGN * _zoom) * 0.5).round()
	var screen := Rect2(Vector2.ZERO, size)
	if is_inside_tree():
		screen = get_global_transform().affine_inverse() * get_viewport_rect()
	_sky.position = screen.position - Vector2.ONE * SKY_MARGIN
	_sky.size = screen.size + Vector2.ONE * SKY_MARGIN * 2.0
	var night := _sky.material as ShaderMaterial
	night.set_shader_parameter(&"extent", _sky.size)
	night.set_shader_parameter(&"origin", _origin - _sky.position)
	night.set_shader_parameter(&"zoom", _zoom)
	# The sky's warm light stands over the pillars' heads.
	night.set_shader_parameter(&"pole", Vector2(LEFT + (WIDE * 4.0 + GAP * 3.0) * 0.5, TOP + HEAD.y))
	night.set_shader_parameter(&"centre", (screen.get_center() - _origin) / _zoom)
	night.set_shader_parameter(&"reach", screen.size * 0.5 / _zoom)
	for item: StringName in [&"sky_deep", &"sky_light", &"sky_haze", &"lamp", &"speck"]:
		night.set_shader_parameter(item, get_theme_color(item))
	queue_redraw()


func refresh(current: MetaProgress) -> void:
	meta = current
	_others.clear()
	_quiet = true
	_list()
	row = clampi(row, 0, maxi(0, entries.size() - 1))
	_tell()
	_quiet = false
	queue_redraw()


# --- The page's state ---

func chapter() -> int:
	return FIGURES if details_open else slot


# The open slot's index: everything it can hold, in the game's order.
func _list() -> void:
	entries = []
	if meta == null:
		return
	var things: Array = []
	match SLOTS[slot][0]:
		&"attack":
			for weapon in MetaProgress.WEAPONS:
				things.append([weapon.id, weapon.emblem, tr(weapon.display_name), tr("%d連撃") % weapon.combo.size(), meta.owns_weapon(weapon.id), ATTACK_SLOT if meta.equipped_weapon().id == weapon.id else -1])
		&"special":
			for move in MetaProgress.SPECIALS:
				things.append([move.id, move.emblem, tr(move.display_name), tr("ゲージ%s") % _number(move.charge), meta.owns_special(move.id), SPECIAL_SLOT if meta.special == move.id else -1])
			# Sealed, its moves still stand in the index as shadows.
			if meta.owns_any_special():
				entries.append({id = CLEAR_ID, emblem = "", name = tr("外す"), note = tr(CLEAR_NOTE), state = State.FREE, other = -1})
		_:
			entries.append({id = CLEAR_ID, emblem = "", name = tr("外す"), note = tr(CLEAR_NOTE), state = State.FREE, other = -1})
			for skill in MetaProgress.SKILLS:
				var at := meta.slot_of(skill.id)
				things.append([skill.id, skill.emblem, tr(skill.display_name), tr("再使用 %s秒") % _number(skill.cooldown), meta.owns_skill(skill.id), at + SKILL_SLOT_OFFSET if at >= 0 else -1])
	for thing: Array in things:
		var state := State.FREE
		var holder: int = thing[5]
		if not thing[4]:
			state = State.UNKNOWN
			holder = -1
		elif holder == slot:
			state = State.HERE
		elif holder >= 0:
			state = State.ELSEWHERE
		entries.append({id = thing[0], emblem = thing[1], name = thing[2] if thing[4] else tr(UNKNOWN_NAME), note = thing[3] if thing[4] else tr(UNOWNED), state = state, other = holder})


func entry_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: Dictionary in entries:
		ids.append(entry.id)
	return ids


# Another slot's index, for its pillar: worked out as the open one's is.
func entries_of(index: int) -> Array:
	if index == slot:
		return entries
	if not _others.has(index):
		var open := slot
		var kept := entries
		slot = index
		_list()
		_others[index] = entries
		slot = open
		entries = kept
	return _others[index]


# The row of what the slot holds, or the first thing it could hold.
func _held_row() -> int:
	var first := -1
	for index in entries.size():
		if entries[index].state == State.HERE:
			return index
		if first < 0 and entries[index].id != CLEAR_ID:
			first = index
	return maxi(0, first)


func _tell() -> void:
	if meta == null or entries.is_empty():
		told = {}
		return
	var entry: Dictionary = entries[clampi(row, 0, entries.size() - 1)]
	shown_id = entry.id
	told = _account(entry.id)
	shown_rows = stat_rows().size() if details_open else 0


# Turns to a slot's pillar (FIGURES for her figures), the cursor on what it holds.
func turn_to(to: int) -> void:
	to = clampi(to, 0, FIGURES)
	if to == chapter():
		return
	_way = 1.0 if to > chapter() else -1.0
	var was_open := details_open
	details_open = to == FIGURES
	if not details_open:
		slot = to
		_list()
		row = _held_row()
	_tell()
	_kick(&"turn")
	_sound(&"ui_open")
	if was_open != details_open:
		view_changed.emit()
	queue_redraw()


# R (Y): to her figures, and back to the pillar left.
func toggle_details() -> void:
	turn_to(slot if details_open else FIGURES)


func move_cursor(to: int) -> void:
	to = clampi(to, 0, maxi(0, entries.size() - 1))
	if to == row:
		return
	row = to
	_tell()
	_kick(&"move")
	_sound(&"ui_move")
	queue_redraw()


# Enter (A) on the entry under the cursor: asks for it to be set.
func seal() -> void:
	if details_open or entries.is_empty():
		return
	if not _equip(shown_id):
		_refuse()


# X: asks for the open slot to be emptied.
func clear_slot() -> void:
	if details_open or not _equip(CLEAR_ID):
		_refuse()


func _refuse() -> void:
	_kick(&"refuse")
	_sound(&"ui_deny")


# Called once an equip has been saved: the stars of the slots it changed
# flare, and the cursor rests on what the open slot now holds.
func present_equip() -> void:
	_sealed = _changing
	_changing = []
	_quiet = true
	row = _held_row() if not _slot_content(slot).is_empty() or slot == ATTACK_SLOT else 0
	_tell()
	_quiet = false
	_kick(&"seal")
	queue_redraw()


func focus_first() -> void:
	_quiet = true
	if details_open:
		details_open = false
		view_changed.emit()
	_list()
	row = _held_row()
	_tell()
	grab_focus()
	_quiet = false
	queue_redraw()


func play_entrance() -> void:
	_way = 0.0
	_kick(&"turn")


func _sound(cue: StringName) -> void:
	if not _quiet and is_visible_in_tree():
		GameAudio.play(self, cue, -22.0)


# --- What things are and do ---

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


# Her figures: [name, value, what the upgrades add, the breakdown, one of
# the main five, its group (0 戦う力, 1 探索と成長)] a row.
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


# --- Clock ---

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_clock += delta
		queue_redraw()


func _kick(what: StringName) -> void:
	_kicks[what] = _clock


func _since(what: StringName) -> float:
	return _clock - float(_kicks.get(what, -1000.0))


func _eased(what: StringName, time: float) -> float:
	var share := clampf(_since(what) / time, 0.0, 1.0)
	return 1.0 - pow(1.0 - share, 3.0)


# --- Input ---

func _input(event: InputEvent) -> void:
	var now_pad := _pad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		now_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		now_pad = false
	if now_pad != _pad:
		_pad = now_pad
		_tell()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _zone_at(event.position)
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				grab_focus()
				var id: Variant = _zone_at(event.position)
				if id != null:
					_press(id)
				accept_event()
			MOUSE_BUTTON_WHEEL_UP:
				if not details_open:
					move_cursor(row - 1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if not details_open:
					move_cursor(row + 1)
				accept_event()
		return
	var handled := true
	if event.is_action_pressed(&"ui_up", true):
		if not details_open:
			move_cursor(row - 1)
	elif event.is_action_pressed(&"ui_down", true):
		if not details_open:
			move_cursor(row + 1)
	elif event.is_action_pressed(&"ui_left", true) or _pressed(event, KEY_Q, JOY_BUTTON_LEFT_SHOULDER):
		turn_to(chapter() - 1)
	elif event.is_action_pressed(&"ui_right", true) or _pressed(event, KEY_E, JOY_BUTTON_RIGHT_SHOULDER):
		turn_to(chapter() + 1)
	elif event.is_action_pressed(&"ui_accept"):
		seal()
	elif _pressed(event, KEY_R, JOY_BUTTON_Y):
		toggle_details()
	elif _pressed(event, KEY_X, JOY_BUTTON_X) or _pressed(event, KEY_DELETE, -1):
		clear_slot()
	elif event.is_action_pressed(&"ui_cancel") and details_open:
		# Back from her figures returns to the pillars; from the pillars the
		# hub takes the back.
		toggle_details()
	else:
		handled = false
	if handled:
		accept_event()


func _pressed(event: InputEvent, key: Key, button: int) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == key
	return event is InputEventJoypadButton and event.pressed and event.button_index == button


func _press(id: Variant) -> void:
	var what: Array = id
	match what[0]:
		&"tab":
			turn_to(what[1])
		&"row":
			if row == what[1]:
				seal()
			else:
				move_cursor(what[1])
		&"other":
			turn_to(what[1])
			move_cursor(what[2])
		&"seal":
			seal()
		&"clear":
			clear_slot()


func _zone(rect: Rect2, id: Variant) -> void:
	_zones.append([rect, id])


func _zone_at(point: Vector2) -> Variant:
	var at := (point - _origin) / _zoom
	for index in range(_zones.size() - 1, -1, -1):
		if (_zones[index][0] as Rect2).has_point(at):
			return _zones[index][1]
	return null


func _hovered(kind: StringName, index: int) -> bool:
	if not _hover is Array:
		return false
	var what: Array = _hover
	return what[0] == kind and what.size() > 1 and what[1] == index


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = null


# --- Drawing ---

func _colour(item: StringName, share := 1.0) -> Color:
	var colour := get_theme_color(item)
	return Color(colour, colour.a * share * _fade)


func _face(item: StringName) -> Font:
	return get_theme_font(item)


func _size(item: StringName) -> int:
	return get_theme_font_size(item)


func _words(at: Vector2, words: String, face: StringName, size: StringName, colour: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_face(face), at, words, align, width, _size(size), colour)


func _width(words: String, face: StringName, size: StringName) -> float:
	return _face(face).get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, _size(size)).x


# Japanese breaks between any two letters; a script with spaces, at them.
func _breaks() -> int:
	return TextServer.BREAK_MANDATORY | (TextServer.BREAK_GRAPHEME_BOUND if TranslationServer.get_locale().begins_with("ja") else TextServer.BREAK_WORD_BOUND)


func _ring(centre: Vector2, radius: float, colour: Color, width := 1.5) -> void:
	draw_arc(centre, radius, 0.0, TAU, maxi(24, int(radius * 0.9)), colour, width, true)


# A soft round light.
func _glow(centre: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array([centre])
	var colours := PackedColorArray([colour])
	for index in 33:
		points.append(centre + Vector2.from_angle(TAU * index / 32.0) * radius)
		colours.append(Color(colour, 0.0))
	for index in 32:
		draw_polygon(PackedVector2Array([points[0], points[index + 1], points[index + 2]]), PackedColorArray([colours[0], colours[index + 1], colours[index + 2]]))


# A rect whose colour runs from `first` to `last`, down it or across it.
func _fall(rect: Rect2, first: Color, last: Color, across := false) -> void:
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(corners, PackedColorArray([first, last, last, first] if across else [first, first, last, last]))


func _breath() -> float:
	return 0.5 + 0.5 * sin(_clock * BREATH)


# A thing's medallion: whole, or darkened to a shadow when not learned; a
# ring alone for an empty slot.
func _medal(centre: Vector2, radius: float, key: String, known := true, share := 1.0) -> void:
	var art := EmblemIcons.texture(key) if not key.is_empty() else null
	if art == null:
		draw_circle(centre, radius * 0.86, _colour(&"void", share))
		_ring(centre, radius * 0.86, _colour(&"dark", share), 1.5)
		return
	var tint := Color(1.0, 1.0, 1.0, share * _fade) if known else _colour(&"veil", share)
	draw_texture_rect(art, Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, tint)


# The four rays of a star held, breathing.
func _rays(centre: Vector2, radius: float, colour: Color) -> void:
	for index in 4:
		var way := Vector2.from_angle(TAU * index / 4.0 + PI * 0.25)
		draw_line(centre + way * (radius + 3.0), centre + way * (radius + 11.0 + 3.0 * _breath()), colour, 1.5, true)


# The cursor: a ring with four ticks that turn.
func _cursor(centre: Vector2, radius: float) -> void:
	var colour := _colour(&"pale") if has_focus() else _colour(&"dim")
	_ring(centre, radius, colour, 2.0)
	for index in 4:
		var way := Vector2.from_angle(TAU * index / 4.0 + _clock * 0.4)
		draw_line(centre + way * radius, centre + way * (radius + 8.0), colour, 2.0, true)


# How far through its moment a slot an equip just changed is (1 to 0), or 0.
func _flare(index: int) -> float:
	return 1.0 - clampf(_since(&"seal") / SEAL_TIME, 0.0, 1.0) if _sealed.has(index) else 0.0


func _draw() -> void:
	_zones.clear()
	if meta == null:
		return
	draw_set_transform(_origin, 0.0, Vector2.ONE * _zoom)
	# Opening the page, and turning to her figures or back, fades it in.
	_fade = 1.0 if _since(&"turn") > TURN_TIME or _way != 0.0 else 0.4 + 0.6 * _eased(&"turn", TURN_TIME)
	if details_open:
		_draw_figures()
	else:
		for index in SLOTS.size():
			_draw_pillar(index, LEFT + index * (WIDE + GAP))
		_draw_card()
	_draw_figures_plate()
	draw_set_transform(Vector2.ZERO)


# A slot's pillar: its name and key, the star of what it holds, and the
# things it can hold down a line.
func _draw_pillar(index: int, x: float) -> void:
	var open := index == slot
	var forward := _eased(&"turn", UIMotion.SELECT_TIME) if open else 0.0
	var mid := x + WIDE * 0.5
	var listed := entries_of(index)
	var foot := FIRST + STEP * (maxi(1, listed.size()) - 0.5) + 10.0
	# The pillar: a fall of light, brighter where the cursor is.
	_fall(Rect2(x, TOP, WIDE, DESIGN.y - TOP - 6.0), _colour(&"blue" if open else &"dim", 0.10 * forward + 0.03), _colour(&"blue", 0.0))
	HubUI.hairline(self, Vector2(x, TOP), Vector2(x + WIDE, TOP), _colour(&"gold" if open else &"brass", 1.0 if open else 0.55), 1.6 if open else 1.0)
	HubUI.mark(self, Vector2(mid, TOP), 6.0, _colour(&"gold") if open else _colour(&"brass"))
	_words(Vector2(x, TOP + 36.0), tr(SLOTS[index][1]), &"title_font", &"figure_size", _colour(&"gold") if open else _colour(&"dim"), HORIZONTAL_ALIGNMENT_CENTER, WIDE)
	_words(Vector2(x, TOP + 58.0), _slot_key(index), &"font", &"star_size", _colour(&"dim"), HORIZONTAL_ALIGNMENT_CENTER, WIDE)
	# What it holds, at its head.
	var held := _slot_content(index)
	var empty := held.is_empty() or held == &"special"
	var head := Vector2(mid, TOP) + HEAD
	var lit := _flare(index)
	_glow(head, 92.0 + 60.0 * lit, _colour(&"gold", (0.24 if open else 0.10) + 0.5 * lit))
	draw_circle(head, HEAD_STAR + 3.0, _colour(&"void"))
	_medal(head, HEAD_STAR, "" if empty else _emblem_of(held))
	_ring(head, HEAD_STAR + 2.0, _colour(&"gold") if open else _colour(&"brass"), 2.0)
	if open:
		_rays(head, HEAD_STAR + 2.0, _colour(&"gold"))
	if lit > 0.0:
		_ring(head, HEAD_STAR + 10.0 + 70.0 * (1.0 - lit), _colour(&"gold", lit), 2.5)
	_words(Vector2(x, head.y + 70.0), tr("空き") if empty else _name_of(held), &"title_font", &"part_size", _colour(&"pale") if open else _colour(&"dim"), HORIZONTAL_ALIGNMENT_CENTER, WIDE)
	_zone(Rect2(x, TOP, WIDE, FIRST - TOP - STEP * 0.5), [&"tab", index])
	# The things it can hold, down a line.
	var first := Vector2(x + 40.0, FIRST)
	if listed.size() > 1:
		draw_line(first, first + Vector2(0.0, STEP * (listed.size() - 1)), _colour(&"brass", 0.3 if open else 0.15), 1.0)
	draw_line(head + Vector2(0.0, HEAD_STAR + 4.0), Vector2(first.x, first.y - STEP * 0.5), _colour(&"brass", 0.25), 1.0)
	for place in listed.size():
		_draw_hung(index, place, listed[place], first + Vector2(0.0, STEP * place), Rect2(x, first.y + STEP * (place - 0.5), WIDE, STEP))
	if foot > DESIGN.y:
		push_warning("A pillar holds more than fits the page.")


# One of the things a slot can hold: its star, its name, and a note.
func _draw_hung(index: int, place: int, entry: Dictionary, at: Vector2, room: Rect2) -> void:
	var open := index == slot
	var known: bool = entry.state != State.UNKNOWN
	var held: bool = entry.state == State.HERE
	var chosen := open and place == row
	var share := 1.0 if open else 0.55
	if chosen:
		_fall(room.grow_individual(-6.0, -4.0, -6.0, -4.0), _colour(&"pale", 0.10), _colour(&"pale", 0.0), true)
	if held:
		_glow(at, SMALL * 2.4, _colour(&"gold", 0.3 * share))
		_rays(at, SMALL, _colour(&"gold", 0.8 * share))
	draw_circle(at, SMALL + 2.0, _colour(&"void"))
	if entry.id == CLEAR_ID:
		_ring(at, SMALL * 0.7, _colour(&"dim", share), 1.5)
		draw_line(at - Vector2(6.0, 6.0), at + Vector2(6.0, 6.0), _colour(&"dim", share), 1.5, true)
	else:
		_medal(at, SMALL, entry.emblem, known, share)
	var free: bool = known and entry.state == State.FREE and entry.id != CLEAR_ID
	_ring(at, SMALL + 1.0, _colour(&"gold" if held else (&"blue" if free else (&"dim" if known else &"dark")), share), 1.5)
	var ink := (&"gold" if held else &"pale") if known else &"faint"
	draw_string(_face(&"bold_font" if chosen or held else &"font"), Vector2(at.x + 34.0, at.y - 2.0), entry.name, HORIZONTAL_ALIGNMENT_LEFT, room.end.x - at.x - 40.0, _size(&"body_size"), _colour(ink, share))
	var note: String = entry.note
	if entry.state == State.ELSEWHERE:
		note = tr("%s に装備中") % _slot_key(entry.other)
	elif held:
		note = tr(HELD)
	draw_string(_face(&"font"), Vector2(at.x + 34.0, at.y + 18.0), note, HORIZONTAL_ALIGNMENT_LEFT, room.end.x - at.x - 40.0, _size(&"star_size"), _colour(&"gold" if held else (&"blue" if entry.state == State.ELSEWHERE else &"faint"), share))
	if chosen:
		_cursor(at, SMALL + 8.0)
	elif open and _hovered(&"row", place):
		_ring(at, SMALL + 7.0, _colour(&"pale", 0.6), 1.5)
	_zone(room, [&"row", place] if open else [&"other", index, place])


# The figures of what the open slot holds now, by their names.
func _held_figures() -> Dictionary:
	var found := {}
	var held := _slot_content(slot)
	if held.is_empty() or held == &"special":
		return found
	for figure: Array in _account(held).figures:
		found[figure[0]] = figure[1]
	return found


# The card: the entry under the cursor in full.
func _draw_card() -> void:
	draw_rect(CARD, _colour(&"panel"))
	draw_rect(CARD, _colour(&"brass", 0.8), false, 1.0)
	draw_rect(CARD.grow(-6.0), _colour(&"brass", 0.3), false, 1.0)
	for corner: Vector2 in [CARD.position, Vector2(CARD.end.x, CARD.position.y), CARD.end, Vector2(CARD.position.x, CARD.end.y)]:
		HubUI.mark(self, corner, 6.0, _colour(&"brass"))
	if told.is_empty():
		return
	var mid := CARD.get_center().x
	var left := CARD.position.x + 30.0
	var inner := CARD.size.x - 60.0
	var fade := 0.35 + 0.65 * maxf(_eased(&"move", UIMotion.SELECT_TIME), _eased(&"turn", UIMotion.SELECT_TIME))
	var unknown: bool = told.unknown
	var here: bool = not entries.is_empty() and entries[clampi(row, 0, entries.size() - 1)].state == State.HERE
	var lit := _flare(slot)
	_words(Vector2(CARD.position.x, CARD.position.y + 40.0), "%s　%s" % [tr(SLOTS[slot][1]), told.kind], &"font", &"label_size", _colour(&"dim", fade), HORIZONTAL_ALIGNMENT_CENTER, CARD.size.x)
	_glow(Vector2(mid, CARD.position.y + 116.0), 110.0, _colour(&"gold" if here else &"blue", 0.12 + 0.4 * lit))
	if told.name == tr("外す") and shown_id == CLEAR_ID:
		_ring(Vector2(mid, CARD.position.y + 116.0), 40.0, _colour(&"dim", fade), 2.0)
		draw_line(Vector2(mid - 18.0, CARD.position.y + 98.0), Vector2(mid + 18.0, CARD.position.y + 134.0), _colour(&"dim", fade), 2.0, true)
	else:
		_medal(Vector2(mid, CARD.position.y + 116.0), 58.0, told.emblem, not unknown, fade)
	_words(Vector2(CARD.position.x + 12.0, CARD.position.y + 220.0), told.name, &"title_font", &"name_size", _colour(&"pale" if not unknown else &"dim", fade), HORIZONTAL_ALIGNMENT_CENTER, CARD.size.x - 24.0)
	HubUI.hairline(self, Vector2(left, CARD.position.y + 244.0), Vector2(left + inner, CARD.position.y + 244.0), _colour(&"brass", 0.5))
	var y := CARD.position.y + 278.0
	var words: String = told.description
	draw_multiline_string(_face(&"font"), Vector2(left, y), words, HORIZONTAL_ALIGNMENT_LEFT, inner, _size(&"body_size"), 4, _colour(&"pale", 0.92 * fade), _breaks())
	y += _face(&"font").get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, inner, _size(&"body_size"), 4, _breaks()).y + 12.0
	# Its figures, beside those of what the slot holds now where they differ.
	var now := _held_figures()
	var listed: Array = told.figures
	for figure: Array in listed:
		_words(Vector2(left, y + 20.0), figure[0], &"font", &"label_size", _colour(&"dim"))
		var held_value: String = now.get(figure[0], "")
		var differs: bool = not held_value.is_empty() and held_value != figure[1] and not here
		_words(Vector2(left, y + 20.0), figure[1], &"bold_font", &"part_size", _colour(&"gold" if differs else &"pale", fade), HORIZONTAL_ALIGNMENT_RIGHT, inner)
		if differs:
			_words(Vector2(left, y + 40.0), tr("いま　%s") % held_value, &"font", &"star_size", _colour(&"faint"), HORIZONTAL_ALIGNMENT_RIGHT, inner)
			y += 18.0
		draw_line(Vector2(left, y + 30.0), Vector2(left + inner, y + 30.0), _colour(&"brass", 0.18), 1.0)
		y += 38.0
	var outcome: String = told.outcome
	if not outcome.is_empty():
		_words(Vector2(left, CARD.end.y - 96.0), outcome, &"font", &"label_size", _colour(&"blue", fade), HORIZONTAL_ALIGNMENT_CENTER, inner)
	# The one action.
	if not told.acts:
		return
	var can: bool = told.can
	var refused := clampf(_since(&"refuse") / REFUSE_TIME, 0.0, 1.0)
	var button := Rect2(left + sin(refused * TAU * 2.0) * 5.0 * (1.0 - refused), CARD.end.y - 78.0, inner, 54.0)
	var plate := StyleBoxFlat.new()
	plate.bg_color = _colour(&"brass", 0.32 + 0.4 * lit) if can else _colour(&"void")
	plate.border_color = _colour(&"gold") if can else _colour(&"dark")
	plate.set_border_width_all(2 if can else 1)
	plate.set_corner_radius_all(4)
	draw_style_box(plate, button)
	_words(Vector2(button.position.x, button.get_center().y + 8.0), told.action, &"title_font", &"figure_size", _colour(&"pale") if can else _colour(&"faint"), HORIZONTAL_ALIGNMENT_CENTER, inner)
	_zone(button, [&"seal"])


# The plate under the card: her main figures in a line, and the way to all
# of them (or back, while they are open).
func _draw_figures_plate() -> void:
	var over := _hovered(&"tab", FIGURES)
	var plate := StyleBoxFlat.new()
	plate.bg_color = _colour(&"panel")
	plate.border_color = _colour(&"gold") if details_open or over else _colour(&"brass", 0.7)
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(4)
	draw_style_box(plate, FIGURES_PLATE)
	var base := FIGURES_PLATE.get_center().y + 6.0
	HubUI.mark(self, Vector2(FIGURES_PLATE.position.x + 24.0, base - 6.0), 6.0, _colour(&"gold"))
	_words(Vector2(FIGURES_PLATE.position.x + 42.0, base), tr(FIGURES_NAME), &"title_font", &"part_size", _colour(&"gold") if details_open else _colour(&"pale"))
	var x := FIGURES_PLATE.position.x + 110.0
	if details_open:
		_words(Vector2(x, base), tr("装備に戻る"), &"font", &"label_size", _colour(&"dim"))
	else:
		# As many of her main figures as the plate holds.
		for stat: Array in stat_rows().slice(0, 3):
			if x + _width(stat[0], &"font", &"star_size") + 8.0 + _width(stat[1], &"bold_font", &"body_size") > FIGURES_PLATE.end.x - 34.0:
				break
			_words(Vector2(x, base), stat[0], &"font", &"star_size", _colour(&"dim"))
			x += _width(stat[0], &"font", &"star_size") + 8.0
			_words(Vector2(x, base), stat[1], &"bold_font", &"body_size", _colour(&"gold"))
			x += _width(stat[1], &"bold_font", &"body_size") + 18.0
	_words(Vector2(FIGURES_PLATE.position.x, base), "›", &"bold_font", &"part_size", _colour(&"dim"), HORIZONTAL_ALIGNMENT_RIGHT, FIGURES_PLATE.size.x - 18.0)
	_zone(FIGURES_PLATE, [&"tab", slot if details_open else FIGURES])


# Her figures in full, over the pillars and the card: two groups side by
# side, a row a figure: its name, its value, what the upgrades add, and
# under them how it is made up.
func _draw_figures() -> void:
	var room := Rect2(FIGURES_ROOM.position, Vector2(CARD.end.x - FIGURES_ROOM.position.x, CARD.end.y - FIGURES_ROOM.position.y))
	draw_rect(room, _colour(&"panel", 0.94))
	draw_rect(room, _colour(&"brass", 0.8), false, 1.0)
	draw_rect(room.grow(-6.0), _colour(&"brass", 0.3), false, 1.0)
	for corner: Vector2 in [room.position, Vector2(room.end.x, room.position.y), room.end, Vector2(room.position.x, room.end.y)]:
		HubUI.mark(self, corner, 6.0, _colour(&"brass"))
	var rows := stat_rows()
	var half := (room.size.x - 132.0) * 0.5
	for group in GROUPS.size():
		var x := room.position.x + 48.0 + group * (half + 36.0)
		var y := room.position.y + 54.0
		_words(Vector2(x, y), tr(GROUPS[group]), &"title_font", &"figure_size", _colour(&"gold"))
		HubUI.trail(self, Vector2(x, y + 14.0), Vector2(x + half, y + 14.0), _colour(&"brass", 0.7))
		y += 26.0
		for stat: Array in rows:
			if stat[5] != group:
				continue
			_words(Vector2(x, y + 24.0), stat[0], &"font", &"body_size", _colour(&"pale"))
			var added: String = stat[2]
			var right := half - (_width(added, &"font", &"star_size") + 8.0 if not added.is_empty() else 0.0)
			_words(Vector2(x, y + 24.0), stat[1], &"title_font", &"figure_size", _colour(&"gold" if stat[4] else &"pale"), HORIZONTAL_ALIGNMENT_RIGHT, right)
			if not added.is_empty():
				_words(Vector2(x, y + 24.0), added, &"font", &"star_size", _colour(&"blue"), HORIZONTAL_ALIGNMENT_RIGHT, half)
			draw_string(_face(&"font"), Vector2(x, y + 45.0), stat[3], HORIZONTAL_ALIGNMENT_LEFT, half, _size(&"star_size"), _colour(&"faint"))
			draw_line(Vector2(x, y + 56.0), Vector2(x + half, y + 56.0), _colour(&"brass", 0.15), 1.0)
			y += 64.0


func _can_clear() -> bool:
	var held := _slot_content(slot)
	return slot != ATTACK_SLOT and not held.is_empty() and held != &"special"


func _emblem_of(id: StringName) -> String:
	var weapon := MetaProgress.find_weapon(id)
	if weapon != null:
		return weapon.emblem
	var move := MetaProgress.find_special(id)
	if move != null:
		return move.emblem
	var skill := MetaProgress.find_skill(id)
	return skill.emblem if skill != null else ""
