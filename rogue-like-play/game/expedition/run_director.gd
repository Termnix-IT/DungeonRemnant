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
# The shelf of memories offers to trade at most this many of the boons held.
const SHELF_CHOICES := 4
# The spring of cleansing lifts a curse for this much echo, or heals this
# share of her health; one of them, and the stop is over.
const SPRING_PRICE := 50
const SPRING_HEAL_SHARE := 0.35
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
# The run's menu over the map (a fight has its own), and the question it
# asks before the run is left from there.
var map_menu: DungeonMenu
var map_prompt: ChoicePrompt
var result: Dictionary = {}
var waypoint: RouteMap.Waypoint
# The kind of foe whose blow felled her, when one did (null for a burn).
var fallen_to: FoeData
var _rewarding := false
# The echo the area just cleared gave for being cleared (RunState.clear_echo).
var _cleared_echo := 0
var _blessing := false
# The event she stopped at, what she bought there, the curse its stone
# offers, the boon card it opened, whether the event ends with that card,
# and the line the map tells after it.
var _event: AreaData
var _event_bought := {}
var _event_curse: StringName
# The boons the shelf of memories offers to trade (ids), and the one given up.
var _shelf_boons: Array[StringName] = []
var _event_card := false
var _event_ends := false
# The deal whose cards are open (the event choice's id); the cards each deal
# of this stop shows, the same however often they are looked at; whether the
# open deal's price has been paid; and the picks it still owes after this one.
var _event_deal: StringName
var _event_offers := {}
var _event_paid := false
var _event_picks_left := 0
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
	map_view.meta = meta
	add_child(map_view)
	map_view.chosen.connect(enter)
	choice = CHOICE.instantiate()
	choice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(choice)
	choice.selected.connect(_on_reward_chosen)
	choice.declined.connect(_on_reward_declined)
	end_view = RunEndView.new()
	add_child(end_view)
	end_view.again_requested.connect(_again)
	event_view = EventView.new()
	add_child(event_view)
	event_view.chosen.connect(_on_event_choice)
	map_menu = DungeonMenu.new()
	map_menu.resume_caption = "地図に戻る"
	map_menu.settings = settings if settings != null else GameSettings.new()
	map_menu.run = run
	add_child(map_menu)
	map_menu.resumed.connect(func(): map_view.cover(false))
	map_menu.settings_changed.connect(func(): settings_changed.emit())
	map_menu.abort_requested.connect(_ask_abandon)
	map_prompt = ChoicePrompt.new()
	add_child(map_prompt)
	map_prompt.confirmed.connect(_on_abandoned_at_map)
	map_prompt.canceled.connect(func(): map_menu.open())
	map_view.menu_requested.connect(open_map_menu)
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


# The run's menu over the map: her build and where the run stands, the
# controls, the settings, and the way out. Not over a card or an event.
func open_map_menu() -> void:
	if area != null or not result.is_empty() or _blessing or _rewarding or choice.visible or event_view.visible or map_menu.visible or map_prompt.visible:
		return
	map_view.cover(true)
	map_menu.open()


func _ask_abandon() -> void:
	map_menu.hide()
	map_prompt.ask("探索の中断", "探索を中断しますか？", "この探索で得た残響は持ち帰れます。レベルと強化は残りません。", "中断する", "戻る", true)


# Left from the map's menu: the run ends where it stands, its echo kept.
func _on_abandoned_at_map() -> void:
	if area != null or not result.is_empty():
		return
	map_view.cover(false)
	finish(false, true)


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
	# Clearing an area always gives a share of its echo; its reward follows.
	_cleared_echo = run.clear_echo(waypoint.area) + run.trial_echo(waypoint.area, waypoint.layer)
	run.echo += _cleared_echo
	grant(waypoint.reward)


# What the map tells of the echo the cleared area gave, after its reward.
func _echo_note() -> String:
	return "　残響 +%s" % UIFormat.amount(_cleared_echo) if _cleared_echo > 0 else ""


# The cleared waypoint's reward; a boon reward waits for its card. An echo
# reward adds the rest of the area's echo to what clearing it gave.
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
			# A difficulty step may cut what a heal reward brings (thirst
			# halves every healing in RunState.heal).
			var share := (HEAL_SHARE + run.rule(&"heal_share")) * run.step_rules.heal
			var gained := run.heal(share, max_hp())
			advance(("報酬　HPが%d回復した" % gained if gained > 0 else "報酬　回復（HPはすでに満タン）") + _echo_note())
		AreaData.Reward.ECHO:
			var echo := run.bonus_echo(waypoint.area)
			run.echo += echo
			advance("報酬　残響を%d得た" % (echo + _cleared_echo))


func _on_reward_chosen(id: StringName) -> void:
	if _event_card:
		_settle_deal(id)
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
	advance("報酬　「%s」を得た" % boon.display_name + _echo_note())


# An event: no fight, its window over the map until she leaves it.
func _stop_at(next: RouteMap.Waypoint) -> void:
	waypoint = next
	run.taken.append(next)
	_event = next.area
	_event_bought.clear()
	_event_note = ""
	var left := run.curses_left()
	_event_curse = left[run.rng.randi_range(0, left.size() - 1)] if not left.is_empty() else &""
	_shelf_boons.clear()
	_event_offers.clear()
	_event_deal = &""
	_event_paid = false
	_event_picks_left = 0
	if _event.event == &"shelf":
		var held := run.build.owned()
		while not held.is_empty() and _shelf_boons.size() < SHELF_CHOICES:
			_shelf_boons.append(held.pop_at(run.rng.randi_range(0, held.size() - 1)).id)
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
			options.append(_paid(&"heal", "傷の手当て（最大HPの%d%%回復）" % _heal_percent(MERCHANT_HEAL_SHARE), MERCHANT_HEAL_PRICE, _current_hp() >= max_hp()))
		&"altar":
			var cost := altar_cost()
			options.append({"id": &"offer", "text": "HPを%d捧げて、強化を1つ選ぶ" % cost, "enabled": _current_hp() > cost and run.build.can_offer(), "reason": "HPが足りない" if _current_hp() <= cost else "取れる強化が残っていない"})
		&"curse":
			var named: String = RunState.CURSES[_event_curse][0] if not _event_curse.is_empty() else ""
			if not named.is_empty():
				terms = "呪い「%s」：%s。以後の残響の報酬 +%d%%" % [named, RunState.CURSES[_event_curse][1], roundi(RunState.CURSE_ECHO * 100.0)]
			options.append({"id": &"curse", "text": "呪い「%s」を受けて、強化を1つ選ぶ" % named, "enabled": not _event_curse.is_empty(), "reason": "これ以上の呪いは受けられない"})
		&"spring":
			if run.curses.is_empty():
				options.append({"id": &"cleanse", "text": "解く呪いがない", "enabled": false, "reason": "呪いを受けていない"})
			for id in run.curses:
				var short := "" if run.echo >= SPRING_PRICE else "残響が%s足りない" % UIFormat.amount(SPRING_PRICE - run.echo)
				options.append({"id": StringName("cleanse:" + String(id)), "text": "呪い「%s」を解く　残響 %s" % [RunState.CURSES[id][0], UIFormat.amount(SPRING_PRICE)], "enabled": short.is_empty(), "reason": short})
			options.append({"id": &"drink", "text": "泉の水を飲む（最大HPの%d%%回復）" % _heal_percent(SPRING_HEAL_SHARE), "enabled": _current_hp() < max_hp(), "reason": "今は必要ない"})
		&"shelf":
			if _shelf_boons.is_empty():
				options.append({"id": &"give", "text": "手放せる強化がない", "enabled": false, "reason": "強化をまだ持っていない"})
			for id in _shelf_boons:
				var boon := run.build.find(id)
				var named := boon.display_name if boon.max_level == 1 else "%s %d" % [boon.display_name, run.build.rank(id)]
				options.append({"id": StringName("give:" + String(id)), "text": "「%s」を手放して、強化を%dつ選ぶ" % [named, run.build.rank(id)], "enabled": run.build.rank(id) > 0, "reason": "もう手放した"})
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


# What a paid healing of this share gives, as the row tells it: the lore of
# healing adds to it, and thirst halves it.
func _heal_percent(share: float) -> int:
	return roundi((share + run.rule(&"heal_share")) * run.mending() * 100.0)


func altar_cost() -> int:
	return ceili(max_hp() * ALTAR_HP_SHARE)


func _on_event_choice(id: StringName) -> void:
	if _event == null or _event_card:
		return
	var place := _event.display_name
	match id:
		EventView.LEAVE:
			_leave_event()
		&"boon":
			if run.echo < MERCHANT_BOON_PRICE or _event_bought.has(id):
				return
			_open_deal(id, false, "%s　残響 %s で強化を1つ選ぶ" % [place, UIFormat.amount(MERCHANT_BOON_PRICE)])
		&"heal":
			if run.echo < MERCHANT_HEAL_PRICE or _event_bought.has(id):
				return
			run.echo -= MERCHANT_HEAL_PRICE
			_event_bought[id] = true
			var gained := run.heal(MERCHANT_HEAL_SHARE + run.rule(&"heal_share"), max_hp())
			_event_note = "%s　HPが%d回復した" % [place, gained]
			_show_event()
		&"offer":
			var cost := altar_cost()
			if _current_hp() <= cost:
				return
			_open_deal(id, true, "%s　HPを%d捧げて強化を1つ選ぶ" % [place, cost])
		_ when String(id).begins_with("give:"):
			var given := StringName(String(id).trim_prefix("give:"))
			if not _shelf_boons.has(given) or run.build.rank(given) == 0:
				return
			var held := run.build.find(given)
			var named := held.display_name if held.max_level == 1 else "%s %d" % [held.display_name, run.build.rank(given)]
			_open_deal(id, true, "%s　「%s」を手放して強化を選ぶ" % [place, named], [given])
		_ when String(id).begins_with("cleanse:"):
			var curse := StringName(String(id).trim_prefix("cleanse:"))
			if run.echo < SPRING_PRICE or not run.remove_curse(curse):
				return
			run.echo -= SPRING_PRICE
			_event_note = "%s　呪い「%s」が解けた" % [place, RunState.CURSES[curse][0]]
			_leave_event()
		&"drink":
			if _current_hp() >= max_hp():
				return
			var healed := run.heal(SPRING_HEAL_SHARE + run.rule(&"heal_share"), max_hp())
			_event_note = "%s　HPが%d回復した" % [place, healed]
			_leave_event()
		&"curse":
			if _event_curse.is_empty():
				return
			_open_deal(id, true, "%s　呪い「%s」を受けて強化を1つ選ぶ" % [place, RunState.CURSES[_event_curse][0]])


# A deal's cards, shown before its price is paid: they may be left untaken
# (nothing is paid, and the event's window comes back), and looking again
# shows the same cards. With no boon left to offer, the event says so.
func _open_deal(deal: StringName, ends: bool, title: String, excluded: Array[StringName] = []) -> void:
	if not _event_offers.has(deal):
		_event_offers[deal] = run.build.offer(run.rng, run.card_count(), excluded)
	var offer: Array[BoonData] = _event_offers[deal]
	if offer.is_empty():
		_event_note = "%s　ほかに選べる強化がなかった" % _event.display_name
		_show_event()
		return
	event_view.hide()
	_event_card = true
	_event_deal = deal
	_event_ends = ends
	_event_paid = false
	_event_picks_left = 0
	choice.present_boons(offer, run.build, run.progression.level, 1, title, 0, true)


# A card of the open deal taken: its price is paid as the first card is
# (echo, health, a curse, or a boon held with all its ranks), and the boon is
# hers. The shelf owes a pick for each rank given up; the stop ends, or its
# window comes back, once none is owed.
func _settle_deal(id: StringName) -> void:
	var place := _event.display_name
	if not _event_paid:
		_event_paid = true
		_event_offers.erase(_event_deal)
		match _event_deal:
			&"boon":
				run.echo -= MERCHANT_BOON_PRICE
				_event_bought[&"boon"] = true
			&"offer":
				var cost := altar_cost()
				run.hp = maxi(1, _current_hp() - cost)
				_event_note = "%s　HPを%d捧げた" % [place, cost]
			&"curse":
				run.take_curse(_event_curse)
				_event_note = "%s　呪い「%s」を受けた" % [place, RunState.CURSES[_event_curse][0]]
			_:
				var given := StringName(String(_event_deal).trim_prefix("give:"))
				_event_picks_left = maxi(0, run.build.give_up(given) - 1)
				_event_note = "%s　「%s」を手放した" % [place, run.build.find(given).display_name]
	else:
		_event_picks_left -= 1
	var bought := run.build.find(id)
	run.build.take(bought)
	_event_note = "%s　「%s」を得た" % [place, bought.display_name] if _event_note.is_empty() else _event_note + "、「%s」を得た" % bought.display_name
	# The shelf's further picks: never the boon given up.
	if _event_picks_left > 0:
		var given := StringName(String(_event_deal).trim_prefix("give:"))
		var more := run.build.offer(run.rng, run.card_count(), [given] as Array[StringName])
		if not more.is_empty():
			choice.present_boons(more, run.build, run.progression.level, 1, "%s　強化を選ぶ（残り%d）" % [place, _event_picks_left])
			return
	_event_card = false
	_event_deal = &""
	_event_picks_left = 0
	if _event_ends:
		_leave_event()
	else:
		_show_event()


# The open deal's cards left untaken: nothing was paid, and the event's
# window comes back.
func _on_reward_declined() -> void:
	if not _event_card:
		return
	_event_card = false
	_event_deal = &""
	_show_event()


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
	fallen_to = RunDirector.foe_of(area.hero.last_blow) if area != null and area.hero != null else null
	get_tree().create_timer(FALL_PAUSE, true).timeout.connect(_after_fall)


# The kind of foe a blow came from: the foe itself, or the one that shot it.
static func foe_of(blow: DamageInfo) -> FoeData:
	if blow == null or not is_instance_valid(blow.source):
		return null
	if blow.source is Foe:
		return (blow.source as Foe).data
	if blow.source is Projectile:
		return (blow.source as Projectile).shooter
	return null


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
	# [BoonData, rank] for the summary's grid of the build.
	var build: Array = []
	for boon in run.build.owned():
		build.append([boon, run.build.rank(boon.id)])
		boons.append(boon.display_name)
		emblems.append([boon.emblem, boon.display_name if boon.max_level == 1 else "%s %d" % [boon.display_name, run.build.rank(boon.id)]])
	# Measured against the progress before this run is recorded.
	var reached := mini(run.layer, run.route.size() - 1) + 1
	var record := meta != null and reached > meta.best_of(chapter.id)
	var first_clear := meta != null and cleared and meta.clears_of(chapter.id) == 0
	result = {"cleared": cleared, "abandoned": abandoned, "record": record, "first_clear": first_clear, "echo_before": meta.echo if meta != null else -1, "layer": mini(run.layer, run.route.size() - 1), "layers": run.route.size(),
		"chapter": chapter.display_name, "chapter_id": String(chapter.id), "step": run.step, "time": run.time, "kills": run.kills,
		"level": run.progression.level, "boons": boons, "emblems": emblems, "echo": run.echo, "met": run.met.keys(),
		"path": run.taken.map(func(point: RouteMap.Waypoint) -> AreaData: return point.area), "fallen_to": fallen_to if not cleared and not abandoned else null, "build": build, "moveset": run.moveset}
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
