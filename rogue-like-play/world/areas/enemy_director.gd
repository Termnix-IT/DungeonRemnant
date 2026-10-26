class_name EnemyDirector
extends Node

# Keeps a CombatArea supplied with foes from its SpawnTable: as many alive as
# the table aims for at the area's time (or a fixed number, for trials),
# brought in a few per second just outside what the camera shows, and an
# elite now and then. It counts time only while the hero stands. A difficulty
# step makes the crowd larger and quicker, the elites sooner and more, and
# mixes the chapter's stronger kin into the crowd (set before start()).

# Foes appear at least this far (world px) outside the camera's view.
const VIEW_MARGIN := 80.0
# And at most this much farther out.
const SPREAD := 260.0
# Never closer to the hero than this, even when the view is not known.
const MIN_DISTANCE := 300.0
const TRIES := 30

var area: CombatArea
var table: SpawnTable
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var running := true
# Above zero: keep exactly this many foes alive, no elites, whatever the time.
var fixed_alive := 0
# A difficulty step's: the crowd aimed for and brought in this many times
# the table's, elites after this share of their time and this many more at
# once, and this share of the crowd drawn from `kin` instead.
var crowd := 1.0
var elite_pace := 1.0
var elite_extra := 0
var kin: Array[FoeData] = []
var kin_share := 0.0
var _credit := 0.0
var _next_elite := INF


func start(combat_area: CombatArea, spawn_table: SpawnTable, seed_value: int = 0) -> void:
	area = combat_area
	table = spawn_table
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	elapsed = 0.0
	_credit = 0.0
	_next_elite = table.elite_first * elite_pace if table.elite != null else INF


func target_alive() -> int:
	return fixed_alive if fixed_alive > 0 else roundi(table.alive_at(elapsed) * crowd)


func _physics_process(delta: float) -> void:
	advance(delta)


# One step of the area's time; tests call it directly.
func advance(delta: float) -> void:
	if not running or area == null or table == null or area.hero == null or not area.hero.health.alive():
		return
	elapsed += delta
	# A fixed trial count fills four times as fast.
	var rate := table.spawns_per_second * (4.0 if fixed_alive > 0 else crowd)
	_credit = minf(_credit + delta * rate, maxf(1.0, rate))
	var alive := area.foes.size()
	var aim := target_alive()
	while _credit >= 1.0 and alive < aim:
		var data := pick()
		var at := spawn_point()
		if data == null or at == Vector2.INF:
			break
		area.spawn_foe(data, at)
		_credit -= 1.0
		alive += 1
	if fixed_alive <= 0 and elapsed >= _next_elite:
		_next_elite += table.elite_every * elite_pace
		if elites_alive() < table.elite_cap + elite_extra:
			var at := spawn_point()
			if at != Vector2.INF:
				area.spawn_foe(table.elite, at)


func elites_alive() -> int:
	var count := 0
	for foe in area.foes:
		if foe.data.elite:
			count += 1
	return count


# A foe from the entries open at this time, by weight, or now and then one of
# the stronger kin; null if none is.
func pick() -> FoeData:
	if not kin.is_empty() and kin_share > 0.0 and rng.randf() < kin_share:
		return kin[rng.randi_range(0, kin.size() - 1)]
	var total := 0.0
	for entry in table.entries:
		if entry.active_at(elapsed):
			total += entry.weight
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	for entry in table.entries:
		if not entry.active_at(elapsed):
			continue
		roll -= entry.weight
		if roll <= 0.0:
			return entry.foe
	return table.entries.back().foe


# An open point on the ground just outside the camera's view; failing that,
# any open point out of view and away from the hero; INF if none is found.
func spawn_point() -> Vector2:
	var hero_at := area.hero.global_position
	var view := area.view_rect().grow(VIEW_MARGIN)
	var inner := maxf(MIN_DISTANCE, view.size.length() * 0.5)
	var ground := area.ground.bounds().grow(-AreaGround.CELL * 1.5)
	for attempt in TRIES:
		var point := hero_at + Vector2.from_angle(rng.randf() * TAU) * (inner + rng.randf() * SPREAD)
		if ground.has_point(point) and not view.has_point(point) and area.ground.is_open(point, 20.0):
			return point
	for attempt in TRIES:
		var point := Vector2(rng.randf_range(ground.position.x, ground.end.x), rng.randf_range(ground.position.y, ground.end.y))
		if not view.has_point(point) and point.distance_to(hero_at) >= MIN_DISTANCE and area.ground.is_open(point, 20.0):
			return point
	return Vector2.INF
