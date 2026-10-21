class_name BattleArea
extends CombatArea

# A battlefield fought as part of a run (RunState): the hero comes in with
# the run's health and build, fallen foes' gems bring levels and each level
# pauses the fight for three boon cards. Given an AreaData, it lays out its
# ground and plays its rules: an open field's growing crowd (EnemyDirector)
# until the hero has lasted survive_time or felled kill_target, or an
# arena's waves (WaveRunner), or a boss hall's boss (its fall wins it; at
# its second phase it calls its summons in on marks). When cleared, the
# foes left vanish, the gems
# lying about fly to her, and `cleared` follows a moment later. The sandbox
# extends it with its own hall and no clearing.

signal cleared

const CHOICE := preload("res://ui/ability_choice.tscn")
# From the clear to `cleared`: the gems fly in and the hero takes a breath.
const CLEAR_PAUSE := 1.4
const BANNER_TIME := 2.6
# From entering a boss hall to the boss's mark, and the mark's time.
const BOSS_DELAY := 1.5
const BOSS_MARK_TIME := 1.0
# The boss comes in this share of the way down from the hall's top.
const BOSS_PLACE := 0.28

@export var seed_value := 0
var data: AreaData
var run: RunState
var hud: ActionHud
var choice: CanvasLayer
var director: EnemyDirector
var waves: WaveRunner
# The boss once it is in, and whether it has fallen.
var boss_foe: Foe
var boss_down := false
var _boss_left := -1.0
# Seconds fought, counted while the hero stands and the fight runs.
var elapsed := 0.0
var finished := false
var _clear_left := -1.0
var _banner_left := 0.0


# Sets what it plays before it enters the tree.
func setup(area_data: AreaData, run_state: RunState, seed_number: int = 0) -> void:
	data = area_data
	run = run_state
	seed_value = seed_number


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if run == null:
		run = RunState.new(seed_value)
	_lay_out()
	if run.hp > 0:
		hero.health.hp = mini(run.hp, hero.health.max_hp)
	hero.use_build(run.build)
	gems.collected.connect(_on_gems)
	hud = ActionHud.new()
	add_child(hud)
	hud.watch(self)
	choice = CHOICE.instantiate()
	choice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(choice)
	choice.selected.connect(_on_chosen)
	hero_fell.connect(_on_hero_down)
	if data != null:
		hud.show_message("%s\n%s" % [data.display_name, objective_text()])
		_banner_left = BANNER_TIME


# The ground, the hero and the rules from its AreaData.
func _lay_out() -> void:
	ground.build(data.size, data.walls(), data.theme)
	spawn_hero(ground.bounds().get_center(), run.tuning)
	if data.kind == AreaData.Kind.FIELD and data.spawn_table != null:
		director = EnemyDirector.new()
		director.name = "Director"
		director.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(director)
		director.start(self, data.spawn_table, seed_value)
	else:
		waves = WaveRunner.new()
		waves.name = "Waves"
		marks.add_child(waves)
		waves.start(self, data.waves, seed_value)
	if data.boss != null:
		_boss_left = BOSS_DELAY


func _physics_process(delta: float) -> void:
	super(delta)
	if get_tree().paused or hero == null or not hero.health.alive():
		return
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			hud.show_message("")
	if _clear_left >= 0.0:
		_clear_left -= delta
		if _clear_left < 0.0:
			run.hp = hero.health.hp
			cleared.emit()
		return
	if data == null or finished:
		return
	elapsed += delta
	if waves != null:
		waves.advance(delta)
	if _boss_left >= 0.0:
		_boss_left -= delta
		if _boss_left < 0.0:
			_bring_boss()
	if is_clear():
		clear()


func is_clear() -> bool:
	if data == null:
		return false
	if data.boss != null:
		return boss_down
	if waves != null:
		return waves.done()
	return (data.survive_time > 0.0 and elapsed >= data.survive_time) or (data.kill_target > 0 and kills >= data.kill_target)


# The area is won: the crowd leaves, the gems come to her, and `cleared`
# follows after CLEAR_PAUSE.
func clear() -> void:
	if finished:
		return
	finished = true
	if director != null:
		director.running = false
	dismiss_foes()
	gems.pull_radius = INF
	hud.show_message("制圧完了")
	_banner_left = CLEAR_PAUSE
	_clear_left = CLEAR_PAUSE


# What the HUD says of the goal now.
func objective_text() -> String:
	if data == null:
		return ""
	if data.boss != null:
		return "%sを倒す" % data.boss.display_name
	if waves != null:
		if waves.wave < 0:
			return "ウェーブ 1/%d　まもなく" % data.waves.size()
		if waves.done():
			return "全ウェーブ撃破"
		return "ウェーブ %d/%d　残り %d体" % [waves.wave + 1, data.waves.size(), waves.remaining()]
	if data.kill_target > 0:
		return "撃破 %d/%d" % [mini(kills, data.kill_target), data.kill_target]
	var left := maxf(0.0, data.survive_time - elapsed)
	return "生き延びる　残り %d:%02d" % [floori(left / 60.0), floori(left) % 60]


# The boss's mark, then the boss.
func _bring_boss() -> void:
	var at := Vector2(ground.bounds().get_center().x, ground.bounds().size.y * BOSS_PLACE)
	waves.mark(at, data.boss, BOSS_MARK_TIME)
	waves.spawned.connect(_on_marked_spawn)


func _on_marked_spawn(foe: Foe) -> void:
	if foe.data != data.boss or boss_foe != null:
		return
	boss_foe = foe
	foe.phase_changed.connect(_on_boss_phase)
	foe.fell.connect(func(_foe: Foe): boss_down = true)
	shake(HURT_SHAKE)


# The boss's second phase: its summons come in on marks around the hall.
func _on_boss_phase(foe: Foe) -> void:
	shake(HURT_SHAKE * 1.5)
	hud.show_message("%sが怒り狂った" % foe.data.display_name)
	_banner_left = BANNER_TIME * 0.6
	if foe.data.summon == null:
		return
	for index in foe.data.summon_count:
		var at := waves.spawn_point()
		if at != Vector2.INF:
			waves.mark(at, foe.data.summon, WaveRunner.MARK_TIME)


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


func _on_hero_down() -> void:
	run.hp = 0
	hud.show_message("倒れました")


func _unhandled_input(event: InputEvent) -> void:
	if choosing() or not hero.health.alive():
		return
	if event.is_action_pressed(&"pause"):
		get_tree().paused = not get_tree().paused
		hud.show_message("一時停止中　Escで再開" if get_tree().paused else "")
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# A cleared or left area never leaves the world paused.
	if is_inside_tree() and choosing():
		get_tree().paused = false
