class_name RunDirector
extends Node

# A real-time run through a chapter, from the first choice to its end (run
# it with F6 from run_director.tscn). It lays out the route (RouteMap) and
# shows it (RouteMapView); the area chosen is fought (BattleArea) with the
# run's health and build; a cleared area gives its waypoint's reward (three
# boon cards, a heal, or echo) and the route moves on a layer. The boss
# cleared, the hero fallen, or the run left from a fight's menu, ends the
# run (RunEndView, and `finished` with the result, which the base records
# in its MetaProgress). Given the
# base's MetaProgress, the run starts with its lasting upgrades: her
# tuning, the rules they give (RunState.lasting), and with the parting
# blessing a boon chosen once the first area has been picked on the map,
# before it is entered. Given a difficulty step, the run is played with its
# constraints (RunState.use_step).

signal finished(result: Dictionary)
# The result's way home was taken (only when returns_to_base).
signal base_requested
# A setting was changed from a fight's menu (the owner saves it).
signal settings_changed

const CHAPTER := preload("res://data/chapters/ash_corridor.tres")
const CHOICE := preload("res://ui/ability_choice.tscn")
# A heal reward restores this share of her health.
const HEAL_SHARE := 0.35
# From her fall to the end of the run.
const FALL_PAUSE := 1.6

@export var seed_value := 0
# The base's lasting progress; none fights as a new player.
var meta: MetaProgress
# The player's settings, given to each area; none: the defaults.
var settings: GameSettings
# The events (stops without a fight): what the merchant asks for a boon and
# for tending her wounds (and how much it heals), and the share of her
# health the altar takes for a boon.
const MERCHANT_BOON_PRICE := 70
const MERCHANT_HEAL_PRICE := 40
const MERCHANT_HEAL_SHARE := 0.5
const ALTAR_HP_SHARE := 0.3
# Started from the base: the result leads back there instead of to a new run.
var returns_to_base := false
# The difficulty step the run is played at (DifficultySteps; 0: none).
var step := 0
var chapter: ChapterData = CHAPTER
var run: RunState
var area: BattleArea
var map_view: RouteMapView
var choice: CanvasLayer
var end_view: RunEndView
var event_view: EventView
var result: Dictionary = {}
var waypoint: RouteMap.Waypoint
var _rewarding := false
var _blessing := false
# The event she stopped at, what she bought there, the curse its stone
# offers, the boon card it opened, whether the event ends with that card,
# and the line the map tells after it.
var _event: AreaData
var _event_bought := {}
var _event_curse: StringName
var _event_card := false
var _event_ends := false
var _event_note := ""
# The parting blessing is still to be chosen, and the area it waits to enter.
var _blessing_due := false
var _blessed_entry: RouteMap.Waypoint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run = RunState.new(seed_value)
	if meta != null:
		run.tuning = meta.tuning(run.tuning)
		run.use_lasting(meta.lasting())
		run.skills = meta.equipped_skills()
		run.special = meta.equipped_special()
		run.moveset = meta.equipped_weapon()
	run.use_step(step)
	run.route = RouteMap.generate(chapter, run.rng)
	map_view = RouteMapView.new()
	add_child(map_view)
	map_view.chosen.connect(enter)
	choice = CHOICE.instantiate()
	choice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(choice)
	choice.selected.connect(_on_reward_chosen)
	end_view = RunEndView.new()
	add_child(end_view)
	end_view.again_requested.connect(_again)
	event_view = EventView.new()
	add_child(event_view)
	event_view.chosen.connect(_on_event_choice)
	_blessing_due = meta != null and meta.starts_with_boon()
	show_map()


func max_hp() -> int:
	return run.tuning.max_hp


# The parting blessing: a boon from three once the first area is picked;
# false when there is nothing to offer, and the area is entered at once.
func _bless(next: RouteMap.Waypoint) -> bool:
	_blessing_due = false
	var offer := run.build.offer(run.rng, run.card_count())
	if offer.is_empty():
		return false
	_blessing = true
	_blessed_entry = next
	choice.present_boons(offer, run.build, run.progression.level, 1, "旅立ちの加護　強化を1つ選ぶ")
	return true


func show_map(note: String = "") -> void:
	GameMusic.cue(self, &"hub")
	GameMusic.muffle(self, false)
	map_view.present(run.route, run.layer, run, max_hp(), note)


func enter(next: RouteMap.Waypoint) -> void:
	if area != null or not result.is_empty() or _blessing:
		return
	if _blessing_due and _bless(next):
		return
	if next.area.is_event():
		_stop_at(next)
		return
	waypoint = next
	run.taken.append(next)
	area = BattleArea.new()
	area.name = "Area"
	area.setup(next.area, run, seed_value + run.layer * 101 if seed_value != 0 else 0)
	area.settings = settings
	area.cleared.connect(_on_cleared, CONNECT_DEFERRED)
	area.hero_fell.connect(_on_fallen)
	area.abandoned.connect(_on_abandoned, CONNECT_DEFERRED)
	area.settings_changed.connect(func(): settings_changed.emit())
	add_child(area)


func _on_cleared() -> void:
	_leave_area()
	run.areas_cleared += 1
	grant(waypoint.reward)


# The cleared waypoint's reward; a boon reward waits for its card.
func grant(reward: AreaData.Reward) -> void:
	match reward:
		AreaData.Reward.BOON:
			var offer := run.build.offer(run.rng, run.card_count())
			if offer.is_empty():
				grant(AreaData.Reward.ECHO)
				return
			_rewarding = true
			choice.present_boons(offer, run.build, run.progression.level, 1, "報酬　強化を1つ選ぶ")
		AreaData.Reward.HEAL:
			# Thirst halves what a heal brings; a difficulty step may cut it too.
			var share := (HEAL_SHARE + run.rule(&"heal_share")) * (0.5 if run.curses.has(&"thirst") else 1.0) * run.step_rules.heal
			var gained := run.heal(share, max_hp())
			advance("報酬　HPが%d回復した" % gained if gained > 0 else "報酬　回復（HPはすでに満タン）")
		AreaData.Reward.ECHO:
			var echo := run.echo_reward(waypoint.area.echo)
			run.echo += echo
			advance("報酬　残響を%d得た" % echo)


func _on_reward_chosen(id: StringName) -> void:
	if _event_card:
		_event_card = false
		var bought := run.build.find(id)
		run.build.take(bought)
		_event_note = "%s　「%s」を得た" % [_event.display_name, bought.display_name] if _event_note.is_empty() else _event_note + "、「%s」を得た" % bought.display_name
		if _event_ends:
			_leave_event()
		else:
			_show_event()
		return
	if _blessing:
		_blessing = false
		run.build.take(run.build.find(id))
		var entry := _blessed_entry
		_blessed_entry = null
		enter(entry)
		return
	if not _rewarding:
		return
	_rewarding = false
	var boon := run.build.find(id)
	run.build.take(boon)
	advance("報酬　「%s」を得た" % boon.display_name)


# An event: no fight, its window over the map until she leaves it.
func _stop_at(next: RouteMap.Waypoint) -> void:
	waypoint = next
	run.taken.append(next)
	_event = next.area
	_event_bought.clear()
	_event_note = ""
	var left := run.curses_left()
	_event_curse = left[run.rng.randi_range(0, left.size() - 1)] if not left.is_empty() else &""
	map_view.hold()
	_show_event()


func _current_hp() -> int:
	return run.hp if run.hp > 0 else max_hp()


func _show_event() -> void:
	var options := []
	var terms := ""
	match _event.event:
		&"merchant":
			options.append(_paid(&"boon", "強化を1つ選ぶ", MERCHANT_BOON_PRICE, not run.build.can_offer()))
			options.append(_paid(&"heal", "傷の手当て（最大HPの%d%%回復）" % roundi(MERCHANT_HEAL_SHARE * 100.0), MERCHANT_HEAL_PRICE, _current_hp() >= max_hp()))
		&"altar":
			var cost := altar_cost()
			options.append({"id": &"offer", "text": "HPを%d捧げて、強化を1つ選ぶ" % cost, "enabled": _current_hp() > cost, "reason": "HPが足りない"})
		&"curse":
			var named: String = RunState.CURSES[_event_curse][0] if not _event_curse.is_empty() else ""
			if not named.is_empty():
				terms = "呪い「%s」：%s。以後の残響の報酬 +%d%%" % [named, RunState.CURSES[_event_curse][1], roundi(RunState.CURSE_ECHO * 100.0)]
			options.append({"id": &"curse", "text": "呪い「%s」を受けて、強化を1つ選ぶ" % named, "enabled": not _event_curse.is_empty(), "reason": "これ以上の呪いは受けられない"})
	var state := "所持 残響 %s　HP %d / %d" % [UIFormat.amount(run.echo), _current_hp(), max_hp()]
	if not run.curses.is_empty():
		state += "　呪い：%s" % run.curse_names()
	event_view.present(_event, state, options, terms)


# A merchant's ware: its price, off when bought, unaffordable or of no use.
func _paid(id: StringName, text: String, price: int, useless: bool) -> Dictionary:
	var reason := ""
	if _event_bought.has(id):
		reason = "購入済み"
	elif useless:
		reason = "今は必要ない" if id == &"heal" else "取れる強化が残っていない"
	elif run.echo < price:
		reason = "残響が%s足りない" % UIFormat.amount(price - run.echo)
	return {"id": id, "text": "%s　残響 %s" % [text, UIFormat.amount(price)], "enabled": reason.is_empty(), "reason": reason}


func altar_cost() -> int:
	return ceili(max_hp() * ALTAR_HP_SHARE)


func _on_event_choice(id: StringName) -> void:
	if _event == null or _event_card:
		return
	match id:
		EventView.LEAVE:
			_leave_event()
		&"boon":
			if run.echo < MERCHANT_BOON_PRICE or _event_bought.has(id):
				return
			if _event_choice(false):
				run.echo -= MERCHANT_BOON_PRICE
				_event_bought[id] = true
		&"heal":
			if run.echo < MERCHANT_HEAL_PRICE or _event_bought.has(id):
				return
			run.echo -= MERCHANT_HEAL_PRICE
			_event_bought[id] = true
			var gained := run.heal(MERCHANT_HEAL_SHARE, max_hp())
			_event_note = "%s　HPが%d回復した" % [_event.display_name, gained]
			_show_event()
		&"offer":
			var cost := altar_cost()
			if _current_hp() <= cost:
				return
			run.hp = maxi(1, _current_hp() - cost)
			_event_note = "%s　HPを%d捧げた" % [_event.display_name, cost]
			if not _event_choice(true):
				_leave_event()
		&"curse":
			if _event_curse.is_empty():
				return
			run.take_curse(_event_curse)
			_event_note = "%s　呪い「%s」を受けた" % [_event.display_name, RunState.CURSES[_event_curse][0]]
			if not _event_choice(true):
				_leave_event()


# The event's boon card; false when no boon is left to offer.
func _event_choice(ends: bool) -> bool:
	var offer := run.build.offer(run.rng, run.card_count())
	if offer.is_empty():
		return false
	event_view.hide()
	_event_card = true
	_event_ends = ends
	choice.present_boons(offer, run.build, run.progression.level, 1, "%s　強化を1つ選ぶ" % _event.display_name)
	return true


func _leave_event() -> void:
	event_view.hide()
	var note := _event_note
	_event = null
	advance(note)


# On to the next layer, or the run is won past the last.
func advance(note: String = "") -> void:
	run.layer += 1
	if run.layer >= run.route.size():
		finish(true)
	else:
		show_map(note)


func _on_fallen() -> void:
	get_tree().create_timer(FALL_PAUSE, true).timeout.connect(_after_fall)


func _after_fall() -> void:
	if area == null:
		return
	_leave_area()
	finish(false)


# Left from the menu: the run ends where it is, its echo kept.
func _on_abandoned() -> void:
	if area == null:
		return
	_leave_area()
	finish(false, true)


func _leave_area() -> void:
	run.kills += area.kills
	run.time += area.elapsed
	run.met.merge(area.met)
	remove_child(area)
	area.queue_free()
	area = null
	get_tree().paused = false


func finish(cleared: bool, abandoned: bool = false) -> void:
	if not result.is_empty():
		return
	var boons: Array[String] = []
	# [emblem, name with its rank] for the summary's row of emblems.
	var emblems: Array = []
	for boon in run.build.owned():
		boons.append(boon.display_name)
		emblems.append([boon.emblem, boon.display_name if boon.max_level == 1 else "%s %d" % [boon.display_name, run.build.rank(boon.id)]])
	# Measured against the progress before this run is recorded.
	var reached := mini(run.layer, run.route.size() - 1) + 1
	var record := meta != null and reached > meta.best_of(chapter.id)
	var first_clear := meta != null and cleared and meta.clears_of(chapter.id) == 0
	result = {"cleared": cleared, "abandoned": abandoned, "record": record, "first_clear": first_clear, "echo_before": meta.echo if meta != null else -1, "layer": mini(run.layer, run.route.size() - 1), "layers": run.route.size(),
		"chapter": chapter.display_name, "chapter_id": String(chapter.id), "step": run.step, "time": run.time, "kills": run.kills,
		"level": run.progression.level, "boons": boons, "emblems": emblems, "echo": run.echo, "met": run.met.keys()}
	map_view.hide()
	GameMusic.cue(self, &"")
	GameMusic.muffle(self, false)
	end_view.present(result, returns_to_base, chapter.illustration)
	finished.emit(result)


func _again() -> void:
	get_tree().paused = false
	if returns_to_base:
		base_requested.emit()
	else:
		get_tree().reload_current_scene()
