extends CombatArea

# The proving ground of the real-time fight (run it with F6): a wide walled
# hall with pillars, the hero in the middle, and an EnemyDirector sending
# foes from data/spawns/trial_field.tres: sentinels, dashing rats after 15 s
# and a raging charger now and then, more of them as time goes on. The
# number keys instead hold a fixed count for trials (1 = 12, 2 = 30, 3 = 60,
# 4 = 100, 5 = 200); 0 goes back to the growing crowd. Enter starts over
# after a fall, Esc pauses.

const SIZE := Vector2i(64, 44)
const PILLARS: Array[Vector2i] = [Vector2i(12, 10), Vector2i(31, 10), Vector2i(50, 10),
	Vector2i(12, 32), Vector2i(31, 32), Vector2i(50, 32)]
const COUNTS: Array[int] = [12, 30, 60, 100, 200]
const KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const TABLE := preload("res://data/spawns/trial_field.tres")

@export var seed_value := 0
var hud: ActionHud
var director: EnemyDirector


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	ground.build(SIZE, _walls())
	spawn_hero(ground.bounds().get_center())
	director = EnemyDirector.new()
	director.name = "Director"
	director.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(director)
	director.start(self, TABLE, seed_value)
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_tree().paused = not get_tree().paused
		hud.show_message("一時停止中　Escで再開" if get_tree().paused else "")
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index := KEYS.find(event.physical_keycode)
	if index >= 0:
		director.fixed_alive = COUNTS[index]
	elif event.physical_keycode == KEY_0:
		director.fixed_alive = 0
	elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and not hero.health.alive():
		get_tree().paused = false
		get_tree().reload_current_scene()
