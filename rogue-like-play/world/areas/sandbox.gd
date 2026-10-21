extends CombatArea

# The proving ground of the real-time fight (run it with F6): a wide walled
# hall with pillars, the hero in the middle, and an EnemyDirector sending
# foes from data/spawns/trial_field.tres: sentinels, dashing rats after 15 s
# and a raging charger now and then, more of them as time goes on. The
# hero fights as a run (RunState): fallen foes drop gems, gems bring levels,
# and each level offers three boons (the level-up cards, the world paused).
# The number keys instead hold a fixed count for trials (1 = 12, 2 = 30,
# 3 = 60, 4 = 100, 5 = 200); 0 goes back to the growing crowd; L gives a
# level at once, to try builds. Enter starts over after a fall, Esc pauses.

const SIZE := Vector2i(64, 44)
const PILLARS: Array[Vector2i] = [Vector2i(12, 10), Vector2i(31, 10), Vector2i(50, 10),
	Vector2i(12, 32), Vector2i(31, 32), Vector2i(50, 32)]
const COUNTS: Array[int] = [12, 30, 60, 100, 200]
const KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const TABLE := preload("res://data/spawns/trial_field.tres")
const CHOICE := preload("res://ui/ability_choice.tscn")

@export var seed_value := 0
var hud: ActionHud
var director: EnemyDirector
var run: RunState
var choice: CanvasLayer


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	ground.build(SIZE, _walls())
	run = RunState.new(seed_value)
	spawn_hero(ground.bounds().get_center())
	hero.use_build(run.build)
	gems.collected.connect(_on_gems)
	director = EnemyDirector.new()
	director.name = "Director"
	director.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(director)
	director.start(self, TABLE, seed_value)
	hud = ActionHud.new()
	add_child(hud)
	hud.watch(self)
	choice = CHOICE.instantiate()
	choice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(choice)
	choice.selected.connect(_on_chosen)
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


func choosing() -> bool:
	return choice.visible


func _on_gems(amount: int) -> void:
	if run.gain(amount):
		_offer()


# Opens the next level-up's choice, the world paused, if one waits.
func _offer() -> void:
	if choosing() or run.progression.pending_choices <= 0 or not hero.health.alive():
		return
	var offer := run.next_offer()
	if offer.is_empty():
		return
	get_tree().paused = true
	choice.present_boons(offer, run.build, run.progression.level, run.progression.pending_choices)


func _on_chosen(id: StringName) -> void:
	run.choose(id)
	if run.progression.pending_choices > 0:
		_offer()
	if not choosing():
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if choosing():
		return
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
	elif event.physical_keycode == KEY_L and hero.health.alive() and not get_tree().paused:
		_on_gems(run.progression.required_exp() - run.progression.exp)
	elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and not hero.health.alive():
		get_tree().paused = false
		get_tree().reload_current_scene()
