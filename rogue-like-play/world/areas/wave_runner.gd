class_name WaveRunner
extends Node2D

# An arena's waves (AreaData.waves), one after another: a wave's foes come
# in a few per second, each first shown as a mark on the floor for
# MARK_TIME, on open ground away from the hero; once every foe of a wave is
# down, the next one comes after WAVE_GAP. Done when the last wave is down.
# A difficulty step makes each wave larger (crowd).
# Drawn among the area's floor marks. A boss hall also puts single foes down
# through its marks (mark()), outside the waves.

const MARK_TIME := 0.7
const WAVE_GAP := 1.2
# Foes appear at least this far from the hero.
const MIN_DISTANCE := 200.0
const MARK_RADIUS := 22.0
const MARK_COLOR := Color(0.72, 0.42, 1.0, 0.5)
const TRIES := 30

# A foe that came in through a mark.
signal spawned(foe: Foe)

var area: CombatArea
var waves: Array[WaveData] = []
var rng := RandomNumberGenerator.new()
# The wave now under way, 0-based; waves.size() once all are down.
var wave := -1
# A difficulty step's: each wave brings this many times its foes, the extra
# ones drawn from its own.
var crowd := 1.0
var _queue: Array[FoeData] = []
# [at, foe data, seconds left, seconds in all]
var _marks: Array = []
var _credit := 0.0
var _gap_left := 0.0


func start(combat_area: CombatArea, wave_list: Array[WaveData], seed_value: int = 0) -> void:
	area = combat_area
	waves = wave_list
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	wave = -1
	_gap_left = 0.0


# One foe, on its own mark, outside the waves.
func mark(at: Vector2, foe: FoeData, time: float = MARK_TIME) -> void:
	_marks.append([at, foe, time, time])


func done() -> bool:
	return wave >= waves.size()


# Foes of this wave still to come or standing.
func remaining() -> int:
	return _queue.size() + _marks.size() + area.foes.size()


func advance(delta: float) -> void:
	# Marks run on after the last wave: a boss hall's boss and its summons.
	_step_marks(delta)
	if done():
		return
	if wave >= 0 and remaining() > 0:
		_credit = minf(_credit + delta * waves[wave].spawns_per_second, 2.0)
		while _credit >= 1.0 and not _queue.is_empty():
			var at := spawn_point()
			if at == Vector2.INF:
				break
			_marks.append([at, _queue.pop_front(), MARK_TIME, MARK_TIME])
			_credit -= 1.0
		return
	# This wave is down (or none has begun): the next after a pause.
	_gap_left -= delta
	if _gap_left > 0.0:
		return
	wave += 1
	_gap_left = WAVE_GAP
	if not done():
		_queue = waves[wave].order()
		var base := _queue.size()
		for extra in roundi(base * (crowd - 1.0)):
			_queue.append(_queue[rng.randi_range(0, base - 1)])
		_credit = 1.0


func spawn_point() -> Vector2:
	var bounds := area.ground.bounds().grow(-AreaGround.CELL * 1.5)
	for attempt in TRIES:
		var point := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if point.distance_to(area.hero.global_position) >= MIN_DISTANCE and area.ground.is_open(point, 24.0):
			return point
	return Vector2.INF


func _step_marks(delta: float) -> void:
	for index in range(_marks.size() - 1, -1, -1):
		var mark: Array = _marks[index]
		mark[2] -= delta
		if mark[2] <= 0.0:
			_marks.remove_at(index)
			spawned.emit(area.spawn_foe(mark[1], mark[0]))
	queue_redraw()


func _draw() -> void:
	for mark: Array in _marks:
		var grown := 1.0 - float(mark[2]) / float(mark[3])
		var radius := MARK_RADIUS * (2.0 if (mark[1] as FoeData).boss else 1.0)
		draw_circle(mark[0], radius * grown, Color(MARK_COLOR, 0.25))
		draw_arc(mark[0], radius, 0.0, TAU, 28, MARK_COLOR, 2.0)
