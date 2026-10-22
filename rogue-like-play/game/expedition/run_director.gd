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
# before it is entered.

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
# Started from the base: the result leads back there instead of to a new run.
var returns_to_base := false
var chapter: ChapterData = CHAPTER
var run: RunState
var area: BattleArea
var map_view: RouteMapView
var choice: CanvasLayer
var end_view: RunEndView
var result: Dictionary = {}
var waypoint: RouteMap.Waypoint
var _rewarding := false
var _blessing := false
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
	_blessing_due = meta != null and meta.starts_with_boon()
	show_map()


func max_hp() -> int:
	return run.tuning.max_hp


# The parting blessing: a boon from three once the first area is picked;
# false when there is nothing to offer, and the area is entered at once.
func _bless(next: RouteMap.Waypoint) -> bool:
	_blessing_due = false
	var offer := run.build.offer(run.rng)
	if offer.is_empty():
		return false
	_blessing = true
	_blessed_entry = next
	choice.present_boons(offer, run.build, run.progression.level, 1, "旅立ちの加護　強化を1つ選ぶ")
	return true


func show_map(note: String = "") -> void:
	map_view.present(run.route, run.layer, run, max_hp(), note)


func enter(next: RouteMap.Waypoint) -> void:
	if area != null or not result.is_empty() or _blessing:
		return
	if _blessing_due and _bless(next):
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
			var offer := run.build.offer(run.rng)
			if offer.is_empty():
				grant(AreaData.Reward.ECHO)
				return
			_rewarding = true
			choice.present_boons(offer, run.build, run.progression.level, 1, "報酬　強化を1つ選ぶ")
		AreaData.Reward.HEAL:
			var gained := run.heal(HEAL_SHARE + run.rule(&"heal_share"), max_hp())
			advance("報酬　HPが%d回復した" % gained if gained > 0 else "報酬　回復（HPはすでに満タン）")
		AreaData.Reward.ECHO:
			var echo := run.echo_reward(waypoint.area.echo)
			run.echo += echo
			advance("報酬　残響を%d得た" % echo)


func _on_reward_chosen(id: StringName) -> void:
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
	result = {"cleared": cleared, "abandoned": abandoned, "layer": mini(run.layer, run.route.size() - 1), "layers": run.route.size(),
		"chapter": chapter.display_name, "time": run.time, "kills": run.kills,
		"level": run.progression.level, "boons": boons, "emblems": emblems, "echo": run.echo, "met": run.met.keys()}
	map_view.hide()
	end_view.present(result, returns_to_base, chapter.illustration)
	finished.emit(result)


func _again() -> void:
	get_tree().paused = false
	if returns_to_base:
		base_requested.emit()
	else:
		get_tree().reload_current_scene()
