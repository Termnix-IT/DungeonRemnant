extends BattleArea

# The proving ground of the real-time fight (run it with F6): a wide walled
# hall with pillars, the hero in the middle, and an EnemyDirector sending
# foes from data/spawns/trial_field.tres: sentinels, dashing rats after 15 s
# and a raging charger now and then, more of them as time goes on, with no
# end. The hero fights as a run (BattleArea): gems bring levels and boon
# cards. The number keys instead hold a fixed count for trials (1 = 12,
# 2 = 30, 3 = 60, 4 = 100, 5 = 200); 0 goes back to the growing crowd; L
# gives a level at once, to try builds. She carries the first special move;
# G fills its gauge and H sets the next one, to try them. Enter starts over after a fall; Esc
# opens the menu, whose leaving starts over too.

const SIZE := Vector2i(64, 44)
const PILLARS: Array[Vector2i] = [Vector2i(12, 10), Vector2i(31, 10), Vector2i(50, 10),
	Vector2i(12, 32), Vector2i(31, 32), Vector2i(50, 32)]
const COUNTS: Array[int] = [12, 30, 60, 100, 200]
const KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const TABLE := preload("res://data/spawns/trial_field.tres")


func _ready() -> void:
	super()
	run.special = MetaProgress.SPECIALS[0]
	hero.equip_special(run.special)
	hero_fell.connect(func(): hud.show_message("倒れました　Enterで再開"))
	abandoned.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())


func trial_keys() -> String:
	return "1〜5 敵の数を固定　0 時間で増加　／　L レベルアップ　G 必殺ゲージ　H 必殺技の切り替え（試験用）"


func _lay_out() -> void:
	var hall := AreaData.new()
	hall.size = SIZE
	hall.pillars.assign(PILLARS)
	ground.build(SIZE, hall.walls())
	spawn_hero(ground.bounds().get_center(), run.tuning)
	director = EnemyDirector.new()
	director.name = "Director"
	director.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(director)
	director.start(self, TABLE, seed_value)


func _unhandled_input(event: InputEvent) -> void:
	if choosing() or in_menu():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and not hero.health.alive():
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	super(event)
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index := KEYS.find(event.physical_keycode)
	if index >= 0:
		director.fixed_alive = COUNTS[index]
	elif event.physical_keycode == KEY_0:
		director.fixed_alive = 0
	elif event.physical_keycode == KEY_L and hero.health.alive() and not get_tree().paused:
		_on_gems(run.progression.required_exp() - run.progression.exp)
	elif event.physical_keycode == KEY_G and hero.special != null:
		hero.special_charge = hero.special.charge
	elif event.physical_keycode == KEY_H and not hero.using_special():
		var at := MetaProgress.SPECIALS.find(hero.special)
		run.special = MetaProgress.SPECIALS[(at + 1) % MetaProgress.SPECIALS.size()]
		hero.equip_special(run.special)
		hud.show_message("必殺技：%s" % run.special.display_name)
		_banner_left = BANNER_TIME * 0.5
