class_name HubStatus
extends Control

# The status page: an open book, her record. Its chapters are her four slots
# (the attack, the two skills, the special move) and, last, her figures; the
# tabs at the book's right edge are the chapters, turned with Q/E (LB/RB),
# left/right, or the pointer. The left page is the chapter: what the slot
# holds now, under a seal of red wax, over an index of everything it can
# hold (a slot that can be emptied lists "外す" first). The right page is the
# entry under the cursor, read as a page: its picture, its account in prose,
# and a ledger that sets its figures beside those of what the slot holds
# now, so a change is compared before it is made. Enter (A) presses the seal
# on the entry: the page asks for the equip (equip_requested) and, once Main
# has saved it, shows the seal coming down (present_equip). X empties the
# slot. R (Y) turns to her figures, written in full across both pages with
# each one's breakdown, and back to the chapter left.
#
# The page is one focusable control that draws itself, ink on parchment, in
# a design space of 1520x686 scaled to its rect: the book and its paper are
# a shader (ui/grimoire/grimoire_book.gdshader), the rest is drawn in
# _draw() with the colours, faces and sizes of the theme's Grimoire type.
# The pointer acts through zones named while drawing: a click chooses a row
# or a tab, a second click on the chosen row seals it.

signal equip_requested(slot: int, id: StringName)
# The page turned to her figures or back: its keys have changed.
signal view_changed

enum State { FREE, HERE, ELSEWHERE, UNKNOWN }

const BOOK := preload("res://ui/grimoire/grimoire_book.gdshader")
# The painted grain of the paper and the leather (tools/build_grimoire_art.py).
const PAPER_GRAIN := preload("res://art/ui/grimoire/paper.png")
const LEATHER_GRAIN := preload("res://art/ui/grimoire/leather.png")
const DESIGN := Vector2(1520.0, 686.0)
const LEFT := 116.0
const RIGHT := 784.0
const PAGE_WIDTH := 560.0
const GUTTER := 730.0
const PAGE_TOP := 14.0
const PAGE_BOTTOM := 672.0
const ROW := 44.0
const LIST_TOP := 268.0
# The index shows this many entries; a longer one scrolls with the cursor.
const VISIBLE_ROWS := 9
const TAB_LEFT := 1400.0
const TAB_HEIGHT := 104.0
const TAB_STEP := 114.0
const TAB_TOP := 44.0
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
# The chapter after the slots': her figures.
const FIGURES := 4
const ORDINALS := ["第一章", "第二章", "第三章", "第四章", "第五章"]
const CHAPTER_LINES := ["%s で振るう武器", "%s で放つ技", "%s で放つ技", "%s で解き放つ必殺技"]
const FIGURES_NAME := "能力"
# Her figures' two groups, a page each.
const GROUPS := ["戦う力", "探索と成長"]

var meta: MetaProgress
# The chapter open (a slot), and whether the book is turned to her figures.
var slot := 1
var details_open := false
# The cursor's row in the chapter's index, and the index itself:
# {id, emblem, name, note, state, other} an entry (`other`: the slot that
# holds it now, or -1).
var row := 0
var entries: Array = []
# What the right page tells: the account of the entry under the cursor.
var told := {}
var shown_id: StringName = &""
# How many of her figures the open pages show.
var shown_rows := 0
var _base: HeroTuning
var _pad := false
# The slots an equip asked for would change, for the moment once it is saved.
var _changing: Array[int] = []
var _sealed: Array[int] = []
var _book: ColorRect
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
	theme_type_variation = &"Grimoire"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_book = ColorRect.new()
	_book.set_anchors_preset(Control.PRESET_FULL_RECT)
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.show_behind_parent = true
	var paper := ShaderMaterial.new()
	paper.shader = BOOK
	paper.set_shader_parameter(&"paper_grain", PAPER_GRAIN)
	paper.set_shader_parameter(&"leather_grain", LEATHER_GRAIN)
	_book.material = paper
	add_child(_book)
	resized.connect(_fit)
	theme_changed.connect(_fit)
	_fit()


# Places the design space in the rect, and the book's shader with it.
func _fit() -> void:
	if _book == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_zoom = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = ((size - DESIGN * _zoom) * 0.5).round()
	var paper := _book.material as ShaderMaterial
	paper.set_shader_parameter(&"extent", size)
	paper.set_shader_parameter(&"origin", _origin)
	paper.set_shader_parameter(&"zoom", _zoom)
	for item: StringName in [&"page_dark", &"page_light", &"cover_dark", &"cover_light"]:
		paper.set_shader_parameter(item, get_theme_color(item))
	queue_redraw()


func refresh(current: MetaProgress) -> void:
	meta = current
	_quiet = true
	_list()
	row = clampi(row, 0, maxi(0, entries.size() - 1))
	_tell()
	_quiet = false
	queue_redraw()


# --- The book's state ---

func chapter() -> int:
	return FIGURES if details_open else slot


# The chapter's index: everything the slot can hold, in the game's order.
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


# Turns to a chapter (FIGURES for her figures), the cursor on what it holds.
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


# R (Y): to her figures, and back to the chapter left.
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


# Called once an equip has been saved: the seal comes down on the slots it
# changed, and the cursor rests on what the open slot now holds.
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
		# Back from her figures returns to the chapter; from a chapter the
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


func _draw() -> void:
	_zones.clear()
	if meta == null:
		return
	_fade = 1.0
	draw_set_transform(_origin, 0.0, Vector2.ONE * _zoom)
	_draw_tabs()
	# A chapter turned to arrives from the side it was turned from.
	var turning := _since(&"turn") < TURN_TIME
	_fade = _eased(&"turn", TURN_TIME)
	draw_set_transform(_origin + Vector2(16.0 * _way * (1.0 - _fade), 0.0) * _zoom, 0.0, Vector2.ONE * _zoom)
	if details_open:
		_draw_figures()
	else:
		_draw_chapter()
		_draw_entry()
	_fade = 1.0
	draw_set_transform(_origin, 0.0, Vector2.ONE * _zoom)
	if turning and _way != 0.0:
		# The leaf turning: a shadow sweeping across the spread.
		var sweep := _since(&"turn") / TURN_TIME
		var x := lerpf(1400.0, 60.0, sweep) if _way > 0.0 else lerpf(60.0, 1400.0, sweep)
		var shadow := get_theme_color(&"ink")
		_shade_across(Rect2(x - 110.0, PAGE_TOP, 110.0, PAGE_BOTTOM - PAGE_TOP), Color(shadow, 0.0), Color(shadow, 0.22 * (1.0 - sweep)))
		draw_line(Vector2(x, PAGE_TOP), Vector2(x, PAGE_BOTTOM), Color(shadow, 0.35 * (1.0 - sweep)), 2.0)
	draw_set_transform(Vector2.ZERO)


func _shade_across(rect: Rect2, left: Color, right: Color) -> void:
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([left, right, right, left]))


func _ring(centre: Vector2, radius: float, colour: Color, width := 1.5, from := 0.0, to := TAU) -> void:
	draw_arc(centre, radius, from, to, maxi(24, int(radius * 0.9)), colour, width, true)


# The picture inside a medallion, without its bronze rim, as a disc.
func _picture(centre: Vector2, radius: float, key: String, tint: Color) -> void:
	var picture := EmblemIcons.texture(key)
	if picture == null:
		return
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for index in 56:
		var way := Vector2.from_angle(TAU * index / 56.0)
		points.append(centre + way * radius)
		uvs.append(Vector2(0.5, 0.5) + way * 0.36)
	draw_polygon(points, PackedColorArray([tint]), uvs, picture)


# An emblem as a painted miniature: the picture in a double ring of ink; a
# thing not learned as its faded shadow, nothing as a dashed ring.
func _miniature(centre: Vector2, radius: float, key: String, known := true) -> void:
	draw_circle(centre + Vector2(1.5, 2.5), radius + 3.0, _colour(&"ink", 0.22))
	if key.is_empty():
		draw_circle(centre, radius, _colour(&"page_dark", 0.8))
		for step in 18:
			_ring(centre, radius - 3.0, _colour(&"sepia", 0.8), 1.2, TAU * step / 18.0, TAU * (step + 0.5) / 18.0)
	elif known:
		_picture(centre, radius, key, Color(1.0, 1.0, 1.0, _fade))
	else:
		draw_circle(centre, radius, _colour(&"page_dark"))
		_picture(centre, radius, key, _colour(&"shadow"))
	_ring(centre, radius, _colour(&"ink"), 2.0)
	_ring(centre, radius + 4.5, _colour(&"sepia", 0.8), 1.0)


# A seal of red wax, the slot's key pressed into it.
func _wax(centre: Vector2, radius: float, letter: String, press := 1.0, alpha := 1.0) -> void:
	var points := PackedVector2Array()
	var under := PackedVector2Array()
	for index in 40:
		var wobble := 1.0 + 0.045 * sin(index * 2.3 + radius) + 0.03 * sin(index * 5.1)
		var point := centre + Vector2.from_angle(TAU * index / 40.0) * radius * press * wobble
		points.append(point)
		under.append(point + Vector2(1.5, 3.0))
	draw_colored_polygon(under, _colour(&"ink", 0.3 * alpha))
	draw_colored_polygon(points, _colour(&"seal", alpha))
	_ring(centre, radius * press * 0.72, _colour(&"seal_dark", alpha), 2.0)
	_ring(centre - Vector2(1.0, 1.5), radius * press * 0.9, _colour(&"seal_light", 0.3 * alpha), 1.5, PI * 1.1, PI * 1.7)
	var size := int(radius * press * (0.72 if letter.length() < 2 else 0.5))
	draw_string(_face(&"title_font"), Vector2(centre.x - radius, centre.y + size * 0.36), letter, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size, _colour(&"seal_light", 0.95 * alpha))


# The letter a slot's seal carries: the key that uses the slot.
func _seal_letter(index: int) -> String:
	return tr("攻", "seal") if index == ATTACK_SLOT else _slot_key(index)


func _rule(y: float, left: float, width: float) -> void:
	var mid := left + width * 0.5
	draw_line(Vector2(left, y), Vector2(mid - 12.0, y), _colour(&"sepia", 0.7), 1.0)
	draw_line(Vector2(mid + 12.0, y), Vector2(left + width, y), _colour(&"sepia", 0.7), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(mid, y - 5.0), Vector2(mid + 5.0, y), Vector2(mid, y + 5.0), Vector2(mid - 5.0, y)]), _colour(&"sepia"))


# A row of dots between a name and its figure.
func _leader(from: float, to: float, y: float, colour: Color) -> void:
	var x := from
	while x < to:
		draw_circle(Vector2(x, y), 1.0, colour)
		x += 7.0


# The chapters' tabs at the book's edge; the open one stands out in red.
func _draw_tabs() -> void:
	var upright := TranslationServer.get_locale().begins_with("ja")
	for index in FIGURES + 1:
		var here := index == chapter()
		var rect := Rect2(TAB_LEFT, TAB_TOP + TAB_STEP * index, 64.0 if here else 48.0, TAB_HEIGHT)
		draw_rect(Rect2(rect.position + Vector2(0.0, 4.0), rect.size), _colour(&"ink", 0.35))
		draw_rect(rect, _colour(&"seal") if here else (_colour(&"tab_lit") if _hovered(&"tab", index) else _colour(&"tab")))
		draw_rect(Rect2(rect.position, Vector2(6.0, rect.size.y)), _colour(&"ink", 0.16))
		var label := tr(FIGURES_NAME) if index == FIGURES else tr(SLOTS[index][1])
		var colour := _colour(&"seal_light") if here else _colour(&"ink")
		var size := _size(&"tab_size")
		if upright:
			var y := rect.position.y + (TAB_HEIGHT - label.length() * (size + 4.0)) * 0.5 + size
			for letter in label.length():
				draw_string(_face(&"title_font"), Vector2(rect.position.x + 6.0, y), label[letter], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 6.0, size, colour)
				y += size + 4.0
		else:
			# Words in a script written across run down the tab, turned.
			var small := size - 3
			var wide := _face(&"title_font").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
			draw_set_transform(_origin + Vector2(rect.position.x + rect.size.x * 0.5 - small * 0.36 + 3.0, rect.position.y + (TAB_HEIGHT - wide) * 0.5) * _zoom, PI * 0.5, Vector2.ONE * _zoom)
			draw_string(_face(&"title_font"), Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, small, colour)
			draw_set_transform(_origin, 0.0, Vector2.ONE * _zoom)
		_zone(rect, [&"tab", index])


# The left page: the chapter's head, what the slot holds, and its index.
func _draw_chapter() -> void:
	_words(Vector2(LEFT, 54.0), tr(ORDINALS[slot]), &"font", &"label_size", _colour(&"sepia"), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
	_words(Vector2(LEFT, 98.0), tr(SLOTS[slot][1]), &"title_font", &"title_size", _colour(&"ink"), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
	_words(Vector2(LEFT, 124.0), tr(CHAPTER_LINES[slot]) % _slot_key(slot), &"font", &"label_size", _colour(&"sepia"), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
	_rule(142.0, LEFT, PAGE_WIDTH)
	# What the chapter holds now, under its seal.
	var held := _slot_content(slot)
	var sealed_special := held == &"special"
	if sealed_special:
		held = &""
	var centre := Vector2(LEFT + 42.0, 186.0)
	_words(Vector2(LEFT + 96.0, 172.0), tr("いまの装備"), &"font", &"mark_size", _colour(&"sepia"))
	_miniature(centre, 34.0, "seal_special" if sealed_special else _emblem_of(held), not sealed_special)
	if held.is_empty():
		_words(Vector2(LEFT + 96.0, 208.0), tr("封印") if sealed_special else tr("空欄"), &"title_font", &"held_size", _colour(&"faint"))
	else:
		_words(Vector2(LEFT + 96.0, 208.0), _name_of(held), &"title_font", &"held_size", _colour(&"ink"))
		_draw_seal(Vector2(LEFT + PAGE_WIDTH - 40.0, 186.0), 28.0, slot)
	# The index.
	var known := 0
	var total := 0
	for entry: Dictionary in entries:
		if entry.id != CLEAR_ID:
			total += 1
			known += 0 if entry.state == State.UNKNOWN else 1
	_words(Vector2(LEFT, 252.0), tr("目録"), &"title_font", &"body_size", _colour(&"ink"))
	_words(Vector2(LEFT, 252.0), tr("習得  %d / %d") % [known, total], &"font", &"mark_size", _colour(&"sepia"), HORIZONTAL_ALIGNMENT_RIGHT, PAGE_WIDTH)
	draw_line(Vector2(LEFT, 260.0), Vector2(LEFT + PAGE_WIDTH, 260.0), _colour(&"ink", 0.8), 1.5)
	var top := clampi(row - VISIBLE_ROWS / 2, 0, maxi(0, entries.size() - VISIBLE_ROWS))
	for index in range(top, mini(entries.size(), top + VISIBLE_ROWS)):
		_draw_row(index, index - top)
	if top > 0:
		_words(Vector2(LEFT, LIST_TOP + 2.0), "▲", &"font", &"small_size", _colour(&"sepia"), HORIZONTAL_ALIGNMENT_RIGHT, PAGE_WIDTH + 14.0)
	if top + VISIBLE_ROWS < entries.size():
		_words(Vector2(LEFT, LIST_TOP + ROW * VISIBLE_ROWS), "▼", &"font", &"small_size", _colour(&"sepia"), HORIZONTAL_ALIGNMENT_RIGHT, PAGE_WIDTH + 14.0)


# A slot's seal: at rest, or coming down just after an equip was saved.
func _draw_seal(centre: Vector2, radius: float, index: int) -> void:
	var press := 1.0
	var alpha := 1.0
	var since := _since(&"seal")
	if _sealed.has(index) and since < SEAL_TIME:
		var share := clampf(since / 0.2, 0.0, 1.0)
		press = lerpf(2.4, 1.0, 1.0 - pow(1.0 - share, 3.0))
		alpha = share
		if since > 0.18:
			var spread := clampf((since - 0.18) / (SEAL_TIME - 0.18), 0.0, 1.0)
			_ring(centre, radius + 8.0 + 44.0 * spread, _colour(&"seal", 0.55 * (1.0 - spread)), 2.0)
	_wax(centre, radius, _seal_letter(index), press, alpha)


func _draw_row(index: int, place: int) -> void:
	var entry: Dictionary = entries[index]
	var top := LIST_TOP + ROW * place
	var rect := Rect2(LEFT - 16.0, top, PAGE_WIDTH + 32.0, ROW)
	var base := top + 29.0
	var here := index == row
	var unknown: bool = entry.state == State.UNKNOWN
	_zone(rect, [&"row", index])
	if here:
		# The reader's place: a wash of ink and a red mark in the margin.
		var slide := _eased(&"move", UIMotion.SELECT_TIME)
		_shade_across(Rect2(rect.position.x, top + 3.0, rect.size.x * (0.6 + 0.4 * slide), ROW - 6.0), _colour(&"wash"), _colour(&"wash", 0.12))
		draw_rect(Rect2(rect.position.x, top + 3.0, 4.0, ROW - 6.0), _colour(&"seal"))
	elif _hovered(&"row", index):
		draw_rect(Rect2(rect.position.x, top + 3.0, rect.size.x, ROW - 6.0), _colour(&"wash", 0.4))
	var name_colour := _colour(&"faint") if unknown else _colour(&"ink")
	if entry.id == CLEAR_ID:
		_miniature(Vector2(LEFT + 18.0, top + ROW * 0.5), 13.0, "")
		name_colour = _colour(&"sepia") if _can_clear() else _colour(&"faint")
	else:
		_miniature(Vector2(LEFT + 18.0, top + ROW * 0.5), 14.0, entry.emblem, not unknown)
	_words(Vector2(LEFT + 46.0, base), entry.name, &"title_font" if here else &"font", &"row_size", name_colour)
	var name_end := LEFT + 46.0 + _width(entry.name, &"title_font", &"row_size") + 12.0
	var right := LEFT + PAGE_WIDTH
	# Where it stands, in the margin at the right.
	if entry.state == State.HERE:
		_wax(Vector2(right - 13.0, top + ROW * 0.5), 12.0, _seal_letter(slot))
		var mark := tr(HELD)
		var mark_width := _width(mark, &"title_font", &"mark_size")
		_words(Vector2(right - 32.0 - mark_width, base - 2.0), mark, &"title_font", &"mark_size", _colour(&"seal"))
		right -= mark_width + 42.0
	elif entry.state == State.ELSEWHERE:
		var mark := tr("%s に装備中") % _slot_key(entry.other)
		var mark_width := _width(mark, &"font", &"mark_size")
		_words(Vector2(right - mark_width, base - 2.0), mark, &"font", &"mark_size", _colour(&"note"))
		right -= mark_width + 12.0
	var note: String = entry.note
	var note_width := _width(note, &"font", &"label_size")
	_words(Vector2(right - note_width, base - 2.0), note, &"font", &"label_size", _colour(&"faint") if unknown else _colour(&"sepia"))
	_leader(name_end, right - note_width - 10.0, base - 6.0, _colour(&"faint" if unknown else &"sepia", 0.7))


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


# The right page: the entry under the cursor, read as a page.
func _draw_entry() -> void:
	if told.is_empty():
		return
	var entry: Dictionary = entries[clampi(row, 0, entries.size() - 1)]
	var unknown: bool = told.unknown
	var centre := Vector2(RIGHT + 88.0, 112.0)
	# Rays round the picture, as an illuminated initial has; they reach out
	# for a moment when its seal comes down.
	if not unknown and not entry.emblem.is_empty():
		var burst := 0.0
		if entry.state == State.HERE and _sealed.has(slot) and _since(&"seal") < SEAL_TIME:
			burst = sin(PI * clampf(_since(&"seal") / SEAL_TIME, 0.0, 1.0))
		for ray in 28:
			var way := Vector2.from_angle(TAU * ray / 28.0)
			var reach := (92.0 if ray % 2 == 0 else 98.0) + 14.0 * burst
			draw_line(centre + way * 86.0, centre + way * reach, _colour(&"seal" if burst > 0.0 else &"sepia", 0.6 + 0.4 * burst), 1.0 + burst, true)
	_miniature(centre, 78.0, entry.emblem, not unknown)
	var text_left := RIGHT + 200.0
	var text_width := PAGE_WIDTH - 200.0
	_words(Vector2(text_left, 76.0), told.kind, &"font", &"label_size", _colour(&"sepia"))
	_words(Vector2(text_left, 130.0), told.name, &"title_font", &"name_size", _colour(&"faint") if unknown else _colour(&"ink"), HORIZONTAL_ALIGNMENT_LEFT, text_width)
	var where := ""
	var where_colour := &"sepia"
	match entry.state:
		State.HERE:
			where = tr("この章に記されている")
			where_colour = &"seal"
		State.ELSEWHERE:
			where = tr("「%s」の章に記されている") % tr(SLOTS[entry.other][1])
			where_colour = &"note"
		State.UNKNOWN:
			where = tr("まだ記されていない")
			where_colour = &"faint"
	_words(Vector2(text_left, 162.0), where, &"font", &"label_size", _colour(where_colour))
	_rule(216.0, RIGHT, PAGE_WIDTH)
	var y := 258.0
	var body := _face(&"font")
	var body_size := _size(&"body_size")
	var description: String = told.description
	# Japanese breaks between any two letters; a script with spaces, at them.
	var breaks := TextServer.BREAK_MANDATORY | (TextServer.BREAK_GRAPHEME_BOUND if TranslationServer.get_locale().begins_with("ja") else TextServer.BREAK_WORD_BOUND)
	draw_multiline_string(body, Vector2(RIGHT, y), description, HORIZONTAL_ALIGNMENT_LEFT, PAGE_WIDTH, body_size, 3, _colour(&"ink"), breaks)
	y += body.get_multiline_string_size(description, HORIZONTAL_ALIGNMENT_LEFT, PAGE_WIDTH, body_size, 3, breaks).y + 22.0
	# The ledger: this entry's figures beside those of what the chapter holds.
	var held := _slot_content(slot)
	var compare: bool = not unknown and not held.is_empty() and held != &"special" and held != entry.id and entry.id != CLEAR_ID
	var figures: Array = told.figures
	if not figures.is_empty():
		var now: Array = _account(held).figures if compare else []
		var mine := RIGHT + PAGE_WIDTH - (190.0 if compare else 0.0)
		_words(Vector2(RIGHT, y), tr("記録"), &"title_font", &"label_size", _colour(&"ink"))
		if compare:
			_words(Vector2(mine - 170.0, y), tr("候補"), &"title_font", &"mark_size", _colour(&"ink"), HORIZONTAL_ALIGNMENT_RIGHT, 170.0)
			_words(Vector2(RIGHT + PAGE_WIDTH - 180.0, y), tr("いまの「%s」") % _name_of(held), &"font", &"mark_size", _colour(&"sepia"), HORIZONTAL_ALIGNMENT_RIGHT, 180.0)
		draw_line(Vector2(RIGHT, y + 10.0), Vector2(RIGHT + PAGE_WIDTH, y + 10.0), _colour(&"ink", 0.8), 1.5)
		y += 40.0
		for index in figures.size():
			var figure: Array = figures[index]
			var value_width := _width(figure[1], &"title_font", &"value_size")
			_words(Vector2(RIGHT, y), figure[0], &"font", &"body_size", _colour(&"sepia"))
			_words(Vector2(mine - value_width, y), figure[1], &"title_font", &"value_size", _colour(&"ink"))
			_leader(RIGHT + _width(figure[0], &"font", &"body_size") + 10.0, mine - value_width - 10.0, y - 6.0, _colour(&"sepia", 0.6))
			if compare and index < now.size():
				var other: Array = now[index]
				var words: String = other[1] if other[0] == figure[0] else "%s %s" % [other[0], other[1]]
				_words(Vector2(RIGHT + PAGE_WIDTH - 180.0, y), words, &"font", &"label_size", _colour(&"sepia"), HORIZONTAL_ALIGNMENT_RIGHT, 180.0)
			y += 36.0
	# The foot of the page: what pressing the seal would do.
	var foot := 632.0
	draw_line(Vector2(RIGHT, foot - 42.0), Vector2(RIGHT + PAGE_WIDTH, foot - 42.0), _colour(&"sepia", 0.5), 1.0)
	if told.can:
		_wax(Vector2(RIGHT + 28.0, foot - 4.0), 22.0, _seal_letter(slot), 1.0 + 0.04 * sin(_clock * 3.0))
		_words(Vector2(RIGHT + 66.0, foot - 8.0), tr("%s で封を押す") % ("A" if _pad else "Enter"), &"title_font", &"body_size", _colour(&"ink"))
		_words(Vector2(RIGHT + 66.0, foot + 16.0), told.outcome, &"font", &"label_size", _colour(&"seal"), HORIZONTAL_ALIGNMENT_LEFT, PAGE_WIDTH - 66.0)
		_zone(Rect2(RIGHT, foot - 38.0, PAGE_WIDTH, 64.0), [&"seal"])
	elif entry.state == State.HERE:
		_words(Vector2(RIGHT, foot), tr("すでに封が押されている"), &"font", &"label_size", _colour(&"sepia"))
	elif unknown:
		_words(Vector2(RIGHT, foot), tr("まだ封を押せない"), &"font", &"label_size", _colour(&"faint"))
	else:
		_words(Vector2(RIGHT, foot), tr("外すものがない"), &"font", &"label_size", _colour(&"faint"))
	if _since(&"refuse") < REFUSE_TIME:
		draw_line(Vector2(RIGHT, foot + 26.0), Vector2(RIGHT + PAGE_WIDTH * (1.0 - _since(&"refuse") / REFUSE_TIME), foot + 26.0), _colour(&"seal", 0.8), 2.0)


# The last chapter: her figures in full, a group on each page, each with
# what the upgrades add and where it comes from.
func _draw_figures() -> void:
	var rows := stat_rows()
	for group in 2:
		var left := LEFT if group == 0 else RIGHT
		_words(Vector2(left, 54.0), tr(ORDINALS[FIGURES]) if group == 0 else tr("ミオの記録"), &"font", &"label_size", _colour(&"sepia"), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
		_words(Vector2(left, 98.0), tr(GROUPS[group]), &"title_font", &"title_size", _colour(&"ink"), HORIZONTAL_ALIGNMENT_CENTER, PAGE_WIDTH)
		_rule(122.0, left, PAGE_WIDTH)
		var y := 176.0
		for entry: Array in rows:
			if entry[5] != group:
				continue
			var right := left + PAGE_WIDTH
			var added: String = entry[2]
			if not added.is_empty():
				var added_width := _width(added, &"font", &"label_size")
				_words(Vector2(right - added_width, y), added, &"font", &"label_size", _colour(&"seal"))
				right -= added_width + 8.0
			var value_width := _width(entry[1], &"title_font", &"row_size")
			_words(Vector2(left, y), entry[0], &"font", &"value_size", _colour(&"ink"))
			_words(Vector2(right - value_width, y), entry[1], &"title_font", &"row_size", _colour(&"ink"))
			_leader(left + _width(entry[0], &"font", &"value_size") + 10.0, right - value_width - 10.0, y - 6.0, _colour(&"sepia", 0.6))
			_words(Vector2(left + 16.0, y + 23.0), entry[3], &"font", &"small_size", _colour(&"note"), HORIZONTAL_ALIGNMENT_LEFT, PAGE_WIDTH - 16.0)
			y += 72.0
