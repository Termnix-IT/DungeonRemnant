class_name ProtoRoute
extends RefCounted

# The run the three route prototypes show: a real chapter's route, laid out
# by the game's own RouteMap from a fixed seed, and a RunState part of the
# way along it, neither of them ever saved. Everything a prototype tells of
# an area is asked here, and answered as the shipped map answers it
# (RouteMapView._tell): the same names, rewards, echo, foes met or not, and
# the boss kept in the dark until her way reaches it. Which areas are open is
# RouteMap.open_after() and nothing else, so the three differ only in how
# they show the same choice.

enum Mark { TAKEN, OPEN, AHEAD, SHUT, PASSED }

const CHAPTER := "res://data/chapters/gale_woods.tres"
const SEED := 10
# The areas taken before each named state, as rows of their layers.
const STATES := {&"start": [], &"mid": [0, 1], &"boss": [0, 1, 1, 1]}
const BOONS := [&"thunder_blade", &"thunder_blade", &"whirlwind", &"life_feast", &"gale_step"]
const VEILED_NAME := "？？？"
const VEILED_NOTE := "この章の最奥で、何かが待ち構えている"

var chapter: ChapterData
var run: RunState
var meta: MetaProgress
var route: RouteMap
# The areas open now, and every area still within her reach.
var open: Array = []
var reach: Dictionary = {}
# The open area under the cursor, and whether going there has been asked.
var cursor := 0
var armed := false
# What the last area gave, as the map tells it at its top.
var note := ""


func _init() -> void:
	chapter = load(CHAPTER)
	reset(&"mid")


# Puts the run in a named state: &"start" (nothing taken, a new player's
# record), &"mid" (two areas in, three ways open) or &"boss" (the boss next).
func reset(state: StringName) -> void:
	run = RunState.new(SEED)
	route = RouteMap.generate(chapter, run.rng)
	run.route = route
	meta = MetaProgress.new()
	var rows: Array = STATES[state]
	for index in rows.size():
		var point: RouteMap.Waypoint = route.nodes(index)[rows[index]]
		run.taken.append(point)
		for foe in Chapters.area_foes(point.area):
			meta.met[String(foe.id)] = true
	run.layer = rows.size()
	note = ""
	if rows.is_empty():
		for id: String in ["moss_sentinel", "gale_rat"]:
			meta.met[id] = true
	else:
		run.hp = 68
		run.echo = 124 + 60 * (rows.size() - 2)
		run.progression.level = 3 + rows.size()
		for id: StringName in BOONS.slice(0, 3 + rows.size()):
			run.build.take(run.build.find(id))
		note = "報酬　「%s」を得た　残響 +27" % TranslationServer.translate(run.build.find(&"gale_step").display_name)
	refresh()


# Works out what is open and what is within reach, as the shipped map does.
func refresh() -> void:
	var previous: RouteMap.Waypoint = run.taken[run.layer - 1] if run.layer > 0 and run.layer - 1 < run.taken.size() else null
	open = route.open_after(previous)
	reach = reach_from(open)
	cursor = clampi(cursor, 0, maxi(0, open.size() - 1))
	armed = false


# Every area that can still be come to from these.
func reach_from(points: Array) -> Dictionary:
	var found := {}
	var frontier := points.duplicate()
	while not frontier.is_empty():
		var point: RouteMap.Waypoint = frontier.pop_back()
		if not found.has(point):
			found[point] = true
			frontier.append_array(point.next)
	return found


func selected() -> RouteMap.Waypoint:
	return open[cursor] if cursor >= 0 and cursor < open.size() else null


func mark(point: RouteMap.Waypoint) -> Mark:
	if open.has(point):
		return Mark.OPEN
	if point.layer < run.layer:
		return Mark.TAKEN if run.taken.has(point) else Mark.PASSED
	return Mark.AHEAD if reach.has(point) else Mark.SHUT


# The boss before her way reaches it.
func veiled(point: RouteMap.Waypoint) -> bool:
	return point.area.boss != null and not open.has(point)


# Where she stands: the area last taken, or null at the start.
func here() -> RouteMap.Waypoint:
	return run.taken[run.layer - 1] if run.layer > 0 else null


func max_hp() -> int:
	return run.tuning.max_hp


func hp() -> int:
	return run.hp if run.hp > 0 else max_hp()


# The pick gone ahead with: the area is taken and the next layer opens.
# Past the boss the run starts over, so the prototype can be played round.
func advance() -> void:
	var point := selected()
	if point == null:
		return
	if point.area.boss != null:
		reset(&"start")
		return
	run.taken.append(point)
	run.layer += 1
	for foe in Chapters.area_foes(point.area):
		meta.met[String(foe.id)] = true
	note = ""
	cursor = 0
	refresh()


func met(foe: FoeData) -> bool:
	return meta == null or meta.has_met(foe.id)


# The echo an area brings in all, as the map's card counts it.
func echo_of(point: RouteMap.Waypoint) -> int:
	if point.area.is_event() or point.area.boss != null:
		return 0
	var trial := run.trial_echo(point.area, point.layer)
	if point.reward == AreaData.Reward.ECHO:
		return run.echo_reward(point.area.echo) + trial
	return run.clear_echo(point.area) + trial


# Everything told of an area, in words the screens lay out as they like.
func tell(point: RouteMap.Waypoint) -> Dictionary:
	var area := point.area
	var state := mark(point)
	var told := {
		"point": point, "mark": state, "veiled": veiled(point), "event": area.is_event(), "boss": area.boss != null,
		"name": TranslationServer.translate(area.display_name), "kind": area.kind_name(), "danger": 0 if area.is_event() else area.difficulty,
		"time": "", "reward": -1, "reward_words": "", "echo": 0, "goal": "", "summary": "", "foes": [], "ways": point.next.size(),
		"state": {Mark.OPEN: "", Mark.AHEAD: "この先にある", Mark.TAKEN: "通ってきた", Mark.PASSED: "通り過ぎた", Mark.SHUT: "この道からは行けない"}[state],
	}
	if told.veiled:
		told.name = VEILED_NAME
		told.goal = VEILED_NOTE
		told.danger = 0
		return told
	if area.is_event():
		told.kind = "イベント"
		told.reward_words = TranslationServer.translate(area.condition)
		told.summary = TranslationServer.translate(area.foe_summary)
		return told
	told.time = "%d分%02d秒" % [area.expected_time / 60, area.expected_time % 60]
	told.goal = TranslationServer.translate(area.condition)
	told.summary = TranslationServer.translate(area.foe_summary)
	if area.boss == null:
		told.reward = point.reward
		told.reward_words = AreaData.reward_name(point.reward)
		told.echo = echo_of(point)
	for foe in Chapters.area_foes(area):
		told.foes.append([foe, met(foe)])
	return told


# The areas further on, within reach now, that picking `point` would put out
# of it (the other ways open now are not counted: a pick always leaves them).
func closes(point: RouteMap.Waypoint) -> Dictionary:
	var kept := reach_from([point])
	var lost := {}
	for other: RouteMap.Waypoint in reach:
		if not kept.has(other) and not open.has(other):
			lost[other] = true
	return lost


# A way from an open area to `point`, by the areas it passes (empty when no
# way leads there); it keeps to `through` where it can.
func way_to(point: RouteMap.Waypoint, through: Array = []) -> Array:
	var starts := open.duplicate()
	if not through.is_empty() and starts.has(through[0]):
		starts.erase(through[0])
		starts.push_front(through[0])
	for start: RouteMap.Waypoint in starts:
		var found := _walk(start, point, through)
		if not found.is_empty():
			return found
	return []


func _walk(from: RouteMap.Waypoint, to: RouteMap.Waypoint, through: Array) -> Array:
	if from == to:
		return [from]
	if from.layer >= to.layer:
		return []
	var nexts := from.next.duplicate()
	nexts.sort_custom(func(a: RouteMap.Waypoint, b: RouteMap.Waypoint) -> bool: return through.has(a) and not through.has(b))
	for next: RouteMap.Waypoint in nexts:
		var rest := _walk(next, to, through)
		if not rest.is_empty():
			return [from] + rest
	return []
