class_name BattleArea
extends CombatArea

# A battlefield fought as part of a run (RunState): the hero comes in with
# the run's health and build, fallen foes' gems bring levels and each level
# pauses the fight for three boon cards: the world first slows for a beat
# while a ring of light bursts from her (the lead-in), then stops and the
# cards are dealt. Given an AreaData, it lays out its
# ground and plays its rules: an open field's growing crowd (EnemyDirector)
# until the hero has lasted survive_time or felled kill_target, or an
# arena's waves (WaveRunner), or a boss hall's boss (its fall wins it; at
# its second phase it calls its summons in on marks). When cleared, the
# foes left vanish, the gems
# lying about fly to her, and `cleared` follows a moment later. The sandbox
# extends it with its own hall and no clearing. The run's lasting rules
# (RunState.lasting) widen the gems' pull, keep her last stand, let a
# level-up's cards be drawn again, and make each boon taken from a level
# heal her and, as the fight resumes, burst, shield and quicken her. The
# run's difficulty step (RunState.step_rules) toughens its foes, swells its
# crowd and waves, hastens its elites, mixes in the chapter's stronger kin,
# and makes its boss rage sooner and call more help.

signal cleared
# A setting was changed from the menu (the owner saves it).
signal settings_changed
# The player left the run from the menu (confirmed).
signal abandoned

const CHOICE := preload("res://ui/ability_choice.tscn")
const PROMPT := preload("res://ui/choice_prompt.gd")
# From the clear to `cleared`: the gems fly in and the hero takes a breath.
const CLEAR_PAUSE := 1.4
# An elite's echo, as a number over where it fell.
const ECHO_NUMBER := Color("ffd27a")
const ECHO_OUTLINE := Color("2a1a04")
const BANNER_TIME := 2.6
# From entering a boss hall to the boss's mark, and the mark's time.
const BOSS_DELAY := 1.5
const BOSS_MARK_TIME := 1.0
# The boss comes in this share of the way down from the hall's top.
const BOSS_PLACE := 0.28
# The light that rises around her when a level's boon is taken.
const LEVEL_UP_SCALE := 1.1
# The lead-in to a level-up's cards: how long (real seconds) and how slow the
# world runs, and the ring of light that bursts from her meanwhile.
const LEAD_TIME := 0.32
const LEAD_SLOW := 0.15
const LEAD_RING := 170.0
# The level-up burst (level_burst adds to its radius): its power as a share
# of hers, and its push.
const LEVEL_BURST_RADIUS := 120.0
const LEVEL_BURST_POWER := 2.0
const LEVEL_BURST_KNOCKBACK := 320.0
# How long level_haste quickens her swings.
const LEVEL_HASTE_TIME := 10.0
# A forest's trees (tools/build_painted_terrain.py trees), square frames side
# by side, drawn this many world px across on a 2x2 pillar.
const TREES := preload("res://art/tiles/painted/forest_trees.png")
const TREE_ACROSS := 124.0

@export var seed_value := 0
# The controls being taught (the first area of a first run only; else null).
var lessons: FirstLessons

var data: AreaData
var run: RunState
# The player's settings (the hub's); none: the defaults.
var settings: GameSettings
var menu: DungeonMenu
var prompt: CanvasLayer
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
# A level-up's lead-in is running.
var _leading := false
# A boss's entrance is being staged (the world stopped).
var staging := false


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
	if settings == null:
		settings = GameSettings.new()
	shake_scale = settings.shake_scale()
	_lay_out()
	if run.hp > 0:
		hero.health.hp = mini(run.hp, hero.health.max_hp)
	hero.use_build(run.build)
	if not run.skills.is_empty():
		hero.motor.equip_skills(run.skills)
	hero.special_gain = 1.0 + run.rule(&"special_charge")
	hero.special_power = run.rule(&"special_power")
	hero.equip_special(run.special)
	hero.special_charge = minf(run.special_charge, run.special.charge) if run.special != null else 0.0
	hero.health.last_stands = run.last_stands
	hero.health.mending = run.mending()
	hero.health.stood.connect(_on_stood)
	gems.pull_radius = GemField.PULL_RADIUS + run.rule(&"gem_pull")
	gems.collected.connect(_on_gems)
	hud = ActionHud.new()
	add_child(hud)
	hud.watch(self)
	choice = CHOICE.instantiate()
	choice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(choice)
	choice.selected.connect(_on_chosen)
	choice.reroll_requested.connect(_on_reroll)
	hud.guide.visible = settings.show_controls
	menu = DungeonMenu.new()
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.settings = settings
	menu.run = run
	add_child(menu)
	menu.resumed.connect(_on_resumed)
	menu.settings_changed.connect(_on_settings_changed)
	menu.abort_requested.connect(_ask_abandon)
	prompt = PROMPT.new()
	prompt.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(prompt)
	prompt.confirmed.connect(_on_abandon_confirmed)
	prompt.canceled.connect(func(): menu.open())
	hero_fell.connect(_on_hero_down)
	foe_fell.connect(_on_foe_echo)
	_begin_lessons()
	Input.joy_connection_changed.connect(_on_joy_connection)
	var air := BattleAmbience.new()
	air.name = "Ambience"
	add_child(air)
	GameMusic.cue(self, &"boss" if data != null and data.boss != null else &"battle")
	if data != null:
		hud.show_message(tr(data.display_name))
		_banner_left = BANNER_TIME
		GameAudio.play(self, &"floor", -18.0)


# The ground, the hero and the rules from its AreaData.
func _lay_out() -> void:
	# A forest's pillars stand as trees: their cells stop her but are drawn as floor.
	var screened := {}
	if data.trees:
		for corner in data.pillar_corners():
			for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
				screened[corner + offset] = true
	ground.build(data.size, data.walls(), data.theme, screened)
	if data.trees:
		_plant_trees()
	spawn_hero(ground.bounds().get_center(), run.tuning, run.moveset)
	# The run's difficulty step: tougher foes, a boss quicker to rage.
	var rules := run.step_rules
	foe_hp = rules.foe_hp
	boss_rage = rules.boss_rage
	if data.kind == AreaData.Kind.FIELD and data.spawn_table != null:
		director = EnemyDirector.new()
		director.name = "Director"
		director.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(director)
		director.crowd = rules.crowd
		director.elite_pace = rules.elite_pace
		director.elite_extra = rules.elite_cap
		if rules.kin > 0.0 and run.route != null:
			director.kin = run.route.chapter.kin
			director.kin_share = rules.kin
		director.start(self, data.spawn_table, seed_value)
	else:
		waves = WaveRunner.new()
		waves.name = "Waves"
		marks.add_child(waves)
		waves.crowd = rules.crowd
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
			run.special_charge = hero.special_charge
			cleared.emit()
		return
	if data == null or finished:
		return
	elapsed += delta
	if lessons != null:
		lessons.step(delta, hero.motor.motion().length() > 30.0)
	if waves != null:
		waves.advance(delta)
	if _boss_left >= 0.0:
		_boss_left -= delta
		if _boss_left < 0.0:
			_bring_boss()
	if is_clear():
		clear()


# A tree on each pillar, rooted at the pillar's bottom edge and sorted among
# the fighters, so one walking behind it is hidden by its crown.
func _plant_trees() -> void:
	var frame := TREES.get_height()
	var kinds := TREES.get_width() / frame
	for corner in data.pillar_corners():
		var tree := Sprite2D.new()
		var picture := AtlasTexture.new()
		picture.atlas = TREES
		picture.region = Rect2(posmod(hash(corner), kinds) * frame, 0, frame, frame)
		tree.texture = picture
		tree.offset = Vector2(0.0, -frame * 0.5)
		tree.scale = Vector2.ONE * TREE_ACROSS / frame
		tree.position = (Vector2(corner) + Vector2(1.0, 2.0)) * AreaGround.CELL
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		actors.add_child(tree)


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
	if lessons != null:
		lessons = null
		hud.show_lesson([])
	if director != null:
		director.running = false
	# An elite still standing leaves the share of its gems already cut out of
	# it, so the last blows before the time runs out are not wasted.
	for foe in foes:
		if foe.data.elite and not foe.dying and foe.health.hp < foe.health.max_hp:
			gems.drop(foe.global_position, roundi(foe.data.exp_reward * (1.0 - float(foe.health.hp) / foe.health.max_hp)))
	dismiss_foes()
	gems.pull_radius = INF
	hud.show_message(tr("制圧完了"))
	GameAudio.play(self, &"victory", -16.0)
	_banner_left = CLEAR_PAUSE
	_clear_left = CLEAR_PAUSE


# What the HUD says of the goal now.
func objective_text() -> String:
	if data == null:
		return ""
	if data.boss != null:
		return tr("%sを倒す") % tr(data.boss.display_name)
	if waves != null:
		if waves.wave < 0:
			return tr("ウェーブ 1/%d") % data.waves.size()
		if waves.done():
			return tr("全ウェーブ撃破")
		return tr("ウェーブ %d/%d　残り %d体") % [waves.wave + 1, data.waves.size(), waves.remaining()]
	if data.kill_target > 0:
		return tr("撃破 %d/%d") % [mini(kills, data.kill_target), data.kill_target]
	var left := maxf(0.0, data.survive_time - elapsed)
	return tr("生き延びる　残り %d:%02d") % [floori(left / 60.0), floori(left) % 60]


# The boss's mark, then the boss.
func _bring_boss() -> void:
	var at := Vector2(ground.bounds().get_center().x, ground.bounds().size.y * BOSS_PLACE)
	waves.mark(at, data.boss, BOSS_MARK_TIME)
	waves.spawned.connect(_on_marked_spawn)
	GameAudio.play(self, &"warning", -16.0)


func _on_marked_spawn(foe: Foe) -> void:
	if foe.data != data.boss or boss_foe != null:
		return
	boss_foe = foe
	foe.phase_changed.connect(_on_boss_phase)
	foe.fell.connect(func(_foe: Foe): boss_down = true)
	# Its entrance is staged with the world stopped: nothing moves, nothing is taken.
	staging = true
	get_tree().paused = true
	camera_held = true
	# The area's opening banner gives way to the boss's name.
	hud.show_message("")
	_banner_left = 0.0
	var intro := BossIntro.new()
	intro.name = "BossIntro"
	add_child(intro)
	intro.finished.connect(_after_entrance)
	# A boss met on a run before may have its entrance cut short.
	intro.skippable = run.known.has(foe.data.id)
	intro.present(foe, self, HubTheme.create())


func _after_entrance() -> void:
	staging = false
	camera_held = false
	if not choosing() and not in_menu():
		get_tree().paused = false


# The boss's second phase: its summons come in on marks around the hall.
func _on_boss_phase(foe: Foe) -> void:
	shake(HURT_SHAKE * 1.5)
	hud.show_message(tr("%sが怒り狂った") % tr(foe.data.display_name))
	GameAudio.play(self, &"warning", -16.0)
	_banner_left = BANNER_TIME * 0.6
	if foe.data.summon == null:
		return
	for index in roundi(foe.data.summon_count * run.step_rules.boss_summons):
		var at := waves.spawn_point()
		if at != Vector2.INF:
			waves.mark(at, foe.data.summon, WaveRunner.MARK_TIME)


# An elite's fall adds its echo to the run's, told over where it fell in the
# echo's gold.
func _on_foe_echo(foe: Foe) -> void:
	if foe.data.echo_reward <= 0:
		return
	var echo := run.echo_reward(foe.data.echo_reward)
	run.echo += echo
	popups.show_number(tr("残響 +%d") % echo, number_spot(foe), ECHO_NUMBER, ECHO_OUTLINE)


# The first area of a player's first run teaches the controls, a line at a
# time on the HUD, each until she has done it.
func _begin_lessons() -> void:
	if run == null or not run.guided or run.areas_cleared > 0 or data == null or data.boss != null:
		return
	lessons = FirstLessons.new()
	if hero.motor.skill_attacks[0] == null:
		lessons.skip(&"skill")
	lessons.changed.connect(func(): hud.show_lesson(lessons.current()))
	events.swing_started.connect(func(_attack: AttackData): lessons.note(&"charge" if hero.motor.combo_index == HeroMotor.CHARGED else &"strike"))
	events.dash_started.connect(func(_direction: Vector2): lessons.note(&"dash"))
	events.skill_used.connect(func(_attack: AttackData): lessons.note(&"skill"))
	hud.show_lesson(lessons.current())


func choosing() -> bool:
	return choice.visible or _leading or staging


func _on_gems(amount: int) -> void:
	if run.gain(amount):
		GameAudio.play(self, &"level_up", -16.0)
		_lead_in()


# The beat before the cards: the world slows, a ring of light bursts from
# her, and then the fight stops for the choice.
func _lead_in() -> void:
	if choosing() or run.progression.pending_choices <= 0 or not hero.health.alive():
		return
	_leading = true
	hit_stop.hold(LEAD_TIME, LEAD_SLOW)
	var ring := GroundRing.new()
	marks.add_child(ring)
	ring.start(hero.global_position, LEAD_RING, &"heavy")
	shake(HEAVY_SHAKE * 0.4)
	get_tree().create_timer(LEAD_TIME, true, false, true).timeout.connect(_after_lead)


func _after_lead() -> void:
	if not _leading:
		return
	_leading = false
	hit_stop.release()
	_offer()


# Opens the next level-up's choice, the world paused, if one waits.
func _offer() -> void:
	if choosing() or run.progression.pending_choices <= 0 or not hero.health.alive():
		return
	var offer := run.next_offer()
	if offer.is_empty():
		return
	get_tree().paused = true
	GameMusic.muffle(self, true)
	choice.show_vitals(hero.health.hp, hero.health.max_hp)
	choice.present_boons(offer, run.build, run.progression.level, run.progression.pending_choices, "", run.rerolls_left)


# The cards on offer drawn again, spending one of the run's rerolls.
func _on_reroll() -> void:
	var offer := run.reroll()
	if offer.is_empty():
		return
	choice.show_vitals(hero.health.hp, hero.health.max_hp)
	choice.present_boons(offer, run.build, run.progression.level, run.progression.pending_choices, "", run.rerolls_left)


func _on_chosen(id: StringName) -> void:
	run.choose(id)
	var heal := run.rule(&"level_heal")
	if heal > 0.0:
		report_heal(hero, hero.health.heal(roundi(hero.health.max_hp * heal)))
	if run.progression.pending_choices > 0:
		_offer()
	if not choosing():
		get_tree().paused = false
		GameMusic.muffle(self, false)
		# The power taken rises around her as the fight resumes.
		_effect(&"level_up", hero.global_position + BODY_MIDDLE * 0.5, Vector2.RIGHT, LEVEL_UP_SCALE)
		_rise()


# What the lasting upgrades make of the moment the fight resumes after a
# level-up: a burst that throws the crowd back, a shield, quicker swings.
func _rise() -> void:
	var burst := run.rule(&"level_burst")
	if burst > 0.0:
		var radius := LEVEL_BURST_RADIUS + burst
		blast(hero.global_position, radius, hero.power() * LEVEL_BURST_POWER, LEVEL_BURST_KNOCKBACK, [], &"heavy")
		var ring := GroundRing.new()
		marks.add_child(ring)
		ring.start(hero.global_position, radius, &"heavy")
	var ward := run.rule(&"level_ward")
	if ward > 0.0:
		hero.health.shield(ward)
	var haste := run.rule(&"level_haste")
	if haste > 0.0:
		run.build.boost(&"attack_speed", haste, LEVEL_HASTE_TIME)


# A last stand spent: the run keeps one fewer, and the moment shows.
func _on_stood() -> void:
	run.last_stands = hero.health.last_stands
	_effect(&"level_up", hero.global_position + BODY_MIDDLE * 0.5, Vector2.RIGHT, LEVEL_UP_SCALE * 0.8)
	GameAudio.play(self, &"level_up", -14.0)


func _on_hero_down() -> void:
	run.hp = 0
	hud.show_message(tr("倒れました"))


# The menu is open, or its leaving is being confirmed.
func in_menu() -> bool:
	return menu.visible or prompt.visible


func open_menu() -> void:
	if choosing() or in_menu() or not hero.health.alive() or finished:
		return
	get_tree().paused = true
	GameMusic.muffle(self, true)
	menu.open()


# With the player away the fight waits: the window left for another, or the
# gamepad she is played with pulled out, opens the menu. Only a hero under
# the player's control, so a test or a capture is never stopped.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_hold_for_player()


func _on_joy_connection(_device: int, connected: bool) -> void:
	if not connected and hero != null and hero.using_pad():
		_hold_for_player()


func _hold_for_player() -> void:
	if hero != null and hero.controlled and is_inside_tree():
		open_menu()


func _on_resumed() -> void:
	if not choosing():
		get_tree().paused = false
		GameMusic.muffle(self, false)


func _on_settings_changed() -> void:
	settings.apply_volume()
	settings.apply_display()
	shake_scale = settings.shake_scale()
	hud.guide.visible = settings.show_controls
	settings_changed.emit()


func _ask_abandon() -> void:
	menu.hide()
	prompt.ask("", tr(DungeonMenu.ABANDON_TITLE), tr(DungeonMenu.ABANDON_BODY), tr(DungeonMenu.ABANDON_ACCEPT), tr(DungeonMenu.ABANDON_CANCEL), true)


func _on_abandon_confirmed() -> void:
	abandoned.emit()


func _unhandled_input(event: InputEvent) -> void:
	if choosing() or not hero.health.alive():
		return
	if event.is_action_pressed(&"pause") and not in_menu():
		open_menu()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# A cleared or left area never leaves the world paused.
	if is_inside_tree() and choosing():
		get_tree().paused = false
