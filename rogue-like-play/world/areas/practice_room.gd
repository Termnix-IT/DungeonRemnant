class_name PracticeRoom
extends BattleArea

# The practice ground, reached from the help's demonstrations at the base: a
# walled hall where the player tries the fight's moves with their own hands.
# It is the fight itself (a BattleArea with a run of its own that goes
# nowhere): foes come as in a field, their shards bring levels and cards,
# her skills and special move are in hand. Nothing of it is kept: no echo,
# no record, no foe met, no save. She cannot fall here (she is mended when
# she is low), so a move can be tried until it is understood.
#
# What can be set is told at the top left: how many foes stand at once (the
# number keys, or the pad's Back to go round them; none, to try the moves
# alone), a level at once (L, or L3) and the special move's gauge filled (G,
# or R3). Esc opens the fight's menu, whose way out asks and then leaves
# (`left`).

signal left

const SIZE := Vector2i(40, 28)
const PILLARS: Array[Vector2i] = [Vector2i(9, 7), Vector2i(29, 7), Vector2i(9, 19), Vector2i(29, 19)]
const TABLE := preload("res://data/spawns/trial_field.tres")
# How many foes stand at once for each number key (0: the director rests),
# and what each is called.
const COUNTS: Array[int] = [0, 6, 20, 50]
const COUNT_NAMES: Array[String] = ["いない", "少し", "群れ", "大群"]
const KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4]
# She is mended to full when she falls under this share of her health.
const MEND_UNDER := 0.3
# Where the notes stand, from the screen's top left.
const NOTES_AT := Vector2(26.0, 58.0)

# Which of COUNTS is set.
var crowd := 1
var _crowd_line: Label


func _ready() -> void:
	super()
	run.special = MetaProgress.SPECIALS[0]
	hero.equip_special(run.special)
	hero.motor.equip_skills([MetaProgress.SKILLS[0], MetaProgress.SKILLS[1]])
	abandoned.connect(func(): left.emit())
	menu.abort_button.caption = tr("練習を終える")
	_write_notes()
	_crowd(1)
	hud.show_message(tr("練習場"))
	_banner_left = BANNER_TIME


# What can be set here, in a few quiet lines at the top left.
func _write_notes() -> void:
	var over := CanvasLayer.new()
	over.name = "Notes"
	over.layer = 4
	add_child(over)
	# On a small dark plate, so they read over any floor.
	var plate := PanelContainer.new()
	plate.theme = HubTheme.create()
	plate.theme_type_variation = &"InsetPanel"
	plate.position = NOTES_AT
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(plate)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(lines)
	HubUI.label(lines, tr("練習場"), &"GoldLabel").autowrap_mode = TextServer.AUTOWRAP_OFF
	_crowd_line = HubUI.label(lines, "", &"HudCaption")
	for words: String in [tr("L（L3）　レベルアップ"), tr("G（R3）　必殺ゲージを満たす"), tr("Esc（Start）　メニュー・練習を終える")]:
		HubUI.label(lines, words, &"HudCaption")
	for line in lines.get_children():
		(line as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		(line as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _lay_out() -> void:
	var hall := AreaData.new()
	hall.size = SIZE
	hall.pillars.assign(PILLARS)
	_raise_ground(hall)
	spawn_hero(ground.bounds().get_center(), run.tuning, run.moveset)
	director = EnemyDirector.new()
	director.name = "Director"
	director.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(director)
	director.start(self, TABLE, seed_value)


# How many foes stand at once; none sends away those that are in.
func _crowd(step: int) -> void:
	crowd = clampi(step, 0, COUNTS.size() - 1)
	var count := COUNTS[crowd]
	director.running = count > 0
	director.fixed_alive = maxi(count, 1)
	if count == 0:
		dismiss_foes()
	if _crowd_line != null:
		_crowd_line.text = tr("1〜4（Back）　敵の数：%s") % tr(COUNT_NAMES[crowd])


func _physics_process(delta: float) -> void:
	super(delta)
	# She cannot fall here.
	if hero != null and hero.health.alive() and hero.health.hp < hero.health.max_hp * MEND_UNDER:
		hero.health.hp = hero.health.max_hp
		report_heal(hero, 0)
		hud.show_message(tr("練習場では倒れません"))
		_banner_left = BANNER_TIME * 0.5


func _ask_abandon() -> void:
	menu.hide()
	prompt.ask("", tr("練習を終えますか？"), tr("練習場で得たレベルと強化は残りません。"), tr("練習を終える"), tr("続ける"), false)


func _unhandled_input(event: InputEvent) -> void:
	if choosing() or in_menu():
		return
	super(event)
	if get_tree().paused or not hero.health.alive():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index := KEYS.find(event.physical_keycode)
		if index >= 0:
			_crowd(index)
		elif event.physical_keycode == KEY_L:
			_level()
		elif event.physical_keycode == KEY_G:
			_fill_gauge()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_BACK:
				_crowd((crowd + 1) % COUNTS.size())
			JOY_BUTTON_LEFT_STICK:
				_level()
			JOY_BUTTON_RIGHT_STICK:
				_fill_gauge()


func _level() -> void:
	_on_gems(run.progression.required_exp() - run.progression.exp)


func _fill_gauge() -> void:
	if hero.special != null:
		hero.special_charge = hero.special.charge
