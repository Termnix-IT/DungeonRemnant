extends CombatArea

# The Phase 1 proving ground (run it with F6): a walled hall with four
# pillars, the hero in the middle and sentinels kept coming at a set count,
# for trying how moving, dashing and striking feel. The number keys set how
# many foes are kept: 1 = 12, 2 = 30, 3 = 60, 4 = 100 (rigs cost about 0.1 ms
# each to draw, so 60 and 100 test the limits). Enter starts over after a
# fall, Esc pauses.

const SIZE := Vector2i(44, 30)
const PILLARS: Array[Vector2i] = [Vector2i(10, 8), Vector2i(32, 8), Vector2i(10, 20), Vector2i(32, 20)]
const COUNTS: Array[int] = [12, 30, 60, 100]
# Foes appear at least this far from the hero, one per SPAWN_GAP seconds.
const SPAWN_DISTANCE := 360.0
const SPAWN_GAP := 0.25
const FOE := preload("res://data/foes/wandering_sentinel.tres")

@export var foe_count := 12
@export var seed_value := 0
var hud: ActionHud
var rng := RandomNumberGenerator.new()
var _spawn_left := 0.0


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	ground.build(SIZE, _walls())
	spawn_hero(ground.bounds().get_center())
	hud = ActionHud.new()
	add_child(hud)
	hud.watch(self)
	hero_fell.connect(func(): hud.show_message("倒れました　Enterで再開"))


func _walls() -> Dictionary:
	var walls := {}
	for x in SIZE.x:
		walls[Vector2i(x, 0)] = true
		walls[Vector2i(x, SIZE.y - 1)] = true
	for y in SIZE.y:
		walls[Vector2i(0, y)] = true
		walls[Vector2i(SIZE.x - 1, y)] = true
	for corner in PILLARS:
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			walls[corner + offset] = true
	return walls


func _physics_process(delta: float) -> void:
	if get_tree().paused or hero == null or not hero.health.alive():
		return
	_spawn_left -= delta
	if _spawn_left <= 0.0 and foes.size() < foe_count:
		_spawn_left = SPAWN_GAP
		var at := _spawn_point()
		if at != Vector2.INF:
			spawn_foe(FOE, at)


# An open point far enough from the hero, or INF if none was found.
func _spawn_point() -> Vector2:
	var area := ground.bounds().grow(-AreaGround.CELL * 1.5)
	for attempt in 24:
		var point := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if point.distance_to(hero.global_position) >= SPAWN_DISTANCE and ground.is_open(point, 20.0):
			return point
	return Vector2.INF


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_tree().paused = not get_tree().paused
		hud.show_message("一時停止中　Escで再開" if get_tree().paused else "")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(event.physical_keycode)
		if index >= 0:
			foe_count = COUNTS[index]
		elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and not hero.health.alive():
			get_tree().paused = false
			get_tree().reload_current_scene()
