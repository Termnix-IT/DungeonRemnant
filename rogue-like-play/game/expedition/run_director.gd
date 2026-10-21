class_name RunDirector
extends Node

# A real-time run through a chapter, from the first choice to its end (run
# it with F6 from run_director.tscn). It lays out the route (RouteMap) and
# shows it (RouteMapView); the area chosen is fought (BattleArea) with the
# run's health and build; a cleared area gives its waypoint's reward (three
# boon cards, a heal, or echo) and the route moves on a layer. The boss
# cleared, or the hero fallen, ends the run (RunEndView, and `finished`
# with the result); Phase 5 will take it back to the base from there.

signal finished(result: Dictionary)

const CHAPTER := preload("res://data/chapters/ash_corridor.tres")
const CHOICE := preload("res://ui/ability_choice.tscn")
const HERO_TUNING := preload("res://data/hero/mio.tres")
# A heal reward restores this share of her health.
const HEAL_SHARE := 0.35
# From her fall to the end of the run.
const FALL_PAUSE := 1.6

@export var seed_value := 0
var chapter: ChapterData = CHAPTER
var run: RunState
var area: BattleArea
var map_view: RouteMapView
var choice: CanvasLayer
var end_view: RunEndView
var result: Dictionary = {}
var waypoint: RouteMap.Waypoint
var _rewarding := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run = RunState.new(seed_value)
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
	show_map()


func max_hp() -> int:
	return HERO_TUNING.max_hp


func show_map(note: String = "") -> void:
	map_view.present(run.route, run.layer, run, max_hp(), note)


func enter(next: RouteMap.Waypoint) -> void:
	if area != null or not result.is_empty():
		return
	waypoint = next
	run.taken.append(next)
	area = BattleArea.new()
	area.name = "Area"
	area.setup(next.area, run, seed_value + run.layer * 101 if seed_value != 0 else 0)
	area.cleared.connect(_on_cleared, CONNECT_DEFERRED)
	area.hero_fell.connect(_on_fallen)
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
			var gained := run.heal(HEAL_SHARE, max_hp())
			advance("報酬　HPが%d回復した" % gained if gained > 0 else "報酬　回復（HPはすでに満タン）")
		AreaData.Reward.ECHO:
			run.echo += waypoint.area.echo
			advance("報酬　残響を%d得た" % waypoint.area.echo)


func _on_reward_chosen(id: StringName) -> void:
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


func _leave_area() -> void:
	run.kills += area.kills
	run.time += area.elapsed
	remove_child(area)
	area.queue_free()
	area = null
	get_tree().paused = false


func finish(cleared: bool) -> void:
	if not result.is_empty():
		return
	var boons: Array[String] = []
	for boon in run.build.owned():
		boons.append(boon.display_name)
	result = {"cleared": cleared, "layer": mini(run.layer, run.route.size() - 1), "layers": run.route.size(),
		"chapter": chapter.display_name, "time": run.time, "kills": run.kills,
		"level": run.progression.level, "boons": boons, "echo": run.echo}
	map_view.hide()
	end_view.present(result)
	finished.emit(result)


func _again() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
