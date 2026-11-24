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
# its second phase it calls its summons in on marks). A boss hall opens
# with its boss's entrance: the world is stopped before the hall's first
# frame and let go only when the entrance is over (`entrance`), so she
# cannot move, strike or be struck until the fight begins. When cleared, the
# foes left vanish, the gems
# lying about fly to her, and `cleared` follows a moment later. The sandbox
# extends it with its own hall and no clearing. The run's lasting rules
# (RunState.lasting) widen the gems' pull, keep her last stand, let a
# level-up's cards be drawn again, and make each boon taken from a level
# heal her and, as the fight resumes, burst, shield and quicken her. The
# run's difficulty step (RunState.step_rules) toughens its foes, swells its
# crowd and waves, hastens its elites, mixes in the chapter's stronger kin,
# and makes its boss rage sooner and call more help.
#
# The fight's great moments are staged here, over the rules and never in
# them: she arrives in a pool of light as the view settles on her; a level
# gained bursts into light round her before its cards; a boss is foretold by
# a sigil burning on the floor as the hall darkens and reddens, comes up out
# of it under its entrance (BossIntro), reddens the hall further when it rages,
# and falls in a slowed moment of white light; an area cleared brightens;
# and her fall slows and reddens the world as the view closes on her.

signal cleared
# A setting was changed from the menu (the owner saves it).
signal settings_changed
# The player left the run from the menu (confirmed).
signal abandoned

const CHOICE := preload("res://ui/ability_choice.tscn")
const PROMPT := preload("res://ui/choice_prompt.gd")
# From the clear to `cleared`: the gems fly in and the hero takes a breath.
const CLEAR_PAUSE := 1.4
# A boss's hall is left later: its fall is told as its entrance was
# (BossOutro), and the word of its slaying stands this long before a level's
# cards may come over it.
const BOSS_CLEAR_PAUSE := 2.4
const SLAIN_HOLD := 0.9
# An elite's echo, as a number over where it fell.
const ECHO_NUMBER := Color("ffd27a")
const ECHO_OUTLINE := Color("2a1a04")
const BANNER_TIME := 2.6
# A boss hall's opening, in order: the world is stopped and the entrance
# set up before the first frame (PREPARING); the entrance plays (INTRO);
# the view goes back to her (RETURN); the fight is on (ACTIVE). NONE: not a
# boss hall.
enum Entrance { NONE, PREPARING, INTRO, RETURN, ACTIVE }
# The entrance is let go by the area itself this long after it should have
# ended, should it ever fail to end (real seconds).
const ENTRANCE_GRACE := 1.5
# The boss comes in this share of the way down from the hall's top.
const BOSS_PLACE := 0.28
# The light that rises around her when a level's boon is taken.
const LEVEL_UP_SCALE := 1.1
# The lead-in to a level-up's cards: how long (real seconds) and how slow the
# world runs, and the ring of light that bursts from her meanwhile.
const LEAD_TIME := 0.32
# Once an area's first level has been seen, the beat before a level's cards
# is this long: the moment is kept, the wait is not.
const LEAD_BRISK := 0.22
# A clearing is told by itself for this long (real seconds) before the
# cards of any level it brought: the two are never told at once. And a
# cleared place is not left while a level's cards are owed, for at most
# this long without a hand opening (so nothing can hold it for good).
const CLEAR_BEAT := 0.85
const LEVELS_GRACE := 3.0
const LEAD_SLOW := 0.15
const LEAD_RING := 170.0
# The level-up burst (level_burst adds to its radius): its power as a share
# of hers, and its push.
const LEVEL_BURST_RADIUS := 120.0
const LEVEL_BURST_POWER := 2.0
const LEVEL_BURST_KNOCKBACK := 320.0
# How long level_haste quickens her swings.
const LEVEL_HASTE_TIME := 10.0
# The light of a level gained, and the motes that rise round her with it.
const LEVEL_LIGHT := Color(1.0, 0.86, 0.5)
const LEVEL_MOTES := 30
# She arrives: the view starts this close and settles over this long.
const ARRIVE_ZOOM := 1.52
const ARRIVE_TIME := 0.75
# The dark she comes out of and leaves into (area_veil.gdshader): how much
# of the view is open about her as she arrives, how long before a cleared
# area is left the dark begins to close on her, and how far and in what
# colour it closes as she falls.
const VEIL := preload("res://world/areas/area_veil.gdshader")
const VEIL_FROM := 0.1
# Her arrival begins this many drawn frames after the place is made.
const ARRIVE_AFTER := 3
const LEAVE_TIME := 0.45
const FALL_VEIL := 0.36
const FALL_DARK := Color(0.1, 0.0, 0.012)
# A boss: how much the hall reddens once it is foretold and once it rages,
# how slow and for how long (real seconds) the world runs as it falls, and
# how close the view comes at that moment.
const BOSS_DREAD := 0.4
const RAGE_DREAD := 0.85
# Its rage: how slow and for how long (real seconds) the world runs.
const RAGE_SLOW := 0.3
const RAGE_SLOW_TIME := 0.32
const BOSS_FALL_SLOW := 0.16
const BOSS_FALL_TIME := 0.8
const BOSS_FALL_ZOOM := 1.48
# An area cleared: how much the place brightens.
const CLEAR_LIFT := 1.3
# Her fall: how slow and for how long the world runs, and how close the view comes.
const FALL_SLOW := 0.25
const FALL_SLOW_TIME := 0.9
const FALL_ZOOM := 1.56

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
# Where a boss hall's opening has got to.
var entrance := Entrance.NONE
# Whether the boss has been named (its health is shown from then on).
var boss_named := true
var _intro: BossIntro
var _entrance_began := 0
# The window was left during the entrance: the menu opens once it is over.
var _menu_due := false
# Seconds fought, counted while the hero stands and the fight runs.
var elapsed := 0.0
var finished := false
var _clear_left := -1.0
var _banner_left := 0.0
# A level-up's lead-in is running.
var _leading := false
# A boss's entrance is being staged (the world stopped).
var staging := false
# The sigil burning where the boss will stand.
var sigil: BossSigil
var _slowed := 0
var _zoom: Tween
var _mood: Tween
# The veil, how far it is open (0: all dark; 1: all clear), and whether it
# has begun to close on a cleared area.
var veil: ColorRect
var veil_open := 1.0
var _veiling: Tween
var _leaving := false
# How many hands of cards this area has dealt, and whether the next follows
# another directly.
var _hands := 0
var _chained := false
# A level gained while a clearing is told is held until this (msec), and a
# cleared place waits for owed cards only this long past the last hand.
var _levels_held := false
# A boss's fall being told (null before it, and once it has gone).
var outro: BossOutro
var _levels_after := 0
var _levels_grace_from := 0
var _arrive_in := 0


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
	_arrive()
	if data != null and data.boss != null:
		_prepare_entrance()


# She arrives: the view, close on her, draws back to the fight's, and her
# light blooms where she stands.
func _arrive() -> void:
	camera.zoom = Vector2.ONE * ARRIVE_ZOOM
	# Out of the dark the gate closed on: her light opens the place.
	var over := CanvasLayer.new()
	over.name = "Veil"
	over.layer = 4
	add_child(over)
	veil = ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var look := ShaderMaterial.new()
	look.shader = VEIL
	veil.material = look
	over.add_child(veil)
	_set_veil(VEIL_FROM)
	_place_veil()
	_arrive_in = ARRIVE_AFTER


# The veil opened or closed to `open` over `time`, on the real clock.
func _veil_to(open: float, time: float, dark := Color.BLACK) -> void:
	if veil == null:
		return
	if _veiling != null:
		_veiling.kill()
	(veil.material as ShaderMaterial).set_shader_parameter(&"dark", dark)
	_veiling = create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_veiling.tween_method(_set_veil, veil_open, open, time)


func _set_veil(open: float) -> void:
	veil_open = open
	(veil.material as ShaderMaterial).set_shader_parameter(&"open", open)
	veil.visible = open < 1.0


# The veil's round stays on her wherever she is on the screen.
func _place_veil() -> void:
	var screen := get_viewport().get_visible_rect().size
	var at := hero.get_global_transform_with_canvas().origin + BODY_MIDDLE * camera.zoom.x
	var look := veil.material as ShaderMaterial
	look.set_shader_parameter(&"at", at / screen)
	look.set_shader_parameter(&"aspect", screen.x / screen.y)


func _process(delta: float) -> void:
	super(delta)
	# The place's first frames are long ones (it is drawn for the first
	# time): her arrival begins once they are past, or it would be over
	# before it was seen.
	if _arrive_in > 0:
		_arrive_in -= 1
		if _arrive_in == 0:
			ground.flash(hero.global_position, 420.0, 0.7, AreaGround.HERO_LIGHT, 0.7)
			_veil_to(1.0, ARRIVE_TIME)
			if entrance == Entrance.PREPARING:
				# A boss hall: the view is the entrance's from here.
				camera.zoom = Vector2.ONE * CAMERA_ZOOM
				entrance = Entrance.INTRO
				_entrance_began = Time.get_ticks_msec()
				_intro.begin()
			else:
				_view(CAMERA_ZOOM, ARRIVE_TIME)
	# The entrance never keeps the world: should it be gone, or run long
	# past its end, the area lets the fight begin by itself.
	if entrance == Entrance.INTRO or entrance == Entrance.RETURN:
		var late := Time.get_ticks_msec() - _entrance_began > (BossIntro.total_time() + ENTRANCE_GRACE) * 1000.0
		if not is_instance_valid(_intro):
			camera.zoom = Vector2.ONE * CAMERA_ZOOM
			camera.position_smoothing_enabled = true
			_finish_entrance()
		elif late:
			_intro.skip()
	if veil != null and veil.visible and hero != null:
		_place_veil()
	# A level held back while a clearing was told: its beat and cards now.
	if _levels_held and Time.get_ticks_msec() >= _levels_after and not choosing() and not get_tree().paused:
		_levels_held = false
		# The word of a boss's slaying gives way to them.
		if is_instance_valid(outro):
			outro.leave(LEAD_BRISK)
		_levels_grace_from = Time.get_ticks_msec()
		hud.show_message("")
		_banner_left = 0.0
		GameAudio.play(self, &"level_up", -16.0)
		_lead_in()


# The view eased to a closeness, on the real clock.
func _view(zoom: float, time: float) -> void:
	if _zoom != null:
		_zoom.kill()
	_zoom = create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom.tween_property(camera, "zoom", Vector2.ONE * zoom, time)


# The view goes in close and comes back, over `time` in all.
func _punch(zoom: float, time: float) -> void:
	if _zoom != null:
		_zoom.kill()
	_zoom = create_tween().set_ignore_time_scale(true)
	_zoom.tween_property(camera, "zoom", Vector2.ONE * zoom, time * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom.tween_property(camera, "zoom", Vector2.ONE * CAMERA_ZOOM, time * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# The place's light eased: reddened (dread) and brightened (lift).
func _colour_place(dread: float, lift: float, time: float) -> void:
	if _mood != null:
		_mood.kill()
	_mood = create_tween().set_ignore_time_scale(true).set_parallel().set_trans(Tween.TRANS_SINE)
	_mood.tween_property(ground, "dread", dread, time)
	_mood.tween_property(ground, "lift", lift, time)


# The world slowed for a moment of real time (not while a level's lead-in
# or its cards hold it).
func _slow(duration: float, scale: float) -> void:
	if choosing():
		return
	hit_stop.hold(duration, scale)
	_slowed += 1
	var token := _slowed
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		if token == _slowed and not _leading:
			hit_stop.release())


# The ground, the hero and the rules from its AreaData.
func _lay_out() -> void:
	_raise_ground(data)
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


func _physics_process(delta: float) -> void:
	super(delta)
	if get_tree().paused or hero == null or not hero.health.alive():
		return
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			hud.show_message("")
	if _clear_left >= 0.0:
		# Not left while a level's cards are owed (they come after the
		# clearing has been told): the last of the wait is kept for after.
		var owed := _levels_held or (run.progression.pending_choices > 0 and hero.health.alive())
		if owed and Time.get_ticks_msec() - _levels_grace_from < LEVELS_GRACE * 1000.0:
			_clear_left = maxf(_clear_left, LEAVE_TIME + 0.25)
		_clear_left -= delta
		# The cleared place is left into the dark: it closes on her at the last.
		if _clear_left < LEAVE_TIME and not _leaving:
			_leaving = true
			_veil_to(0.0, LEAVE_TIME)
			if is_instance_valid(outro):
				outro.leave(LEAVE_TIME)
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
	if is_clear():
		clear()


# The ground of an area laid out as a place: its paving and walls, a thing
# with height on each pillar (their cells stop her but are drawn as floor
# under it; a boss's hall keeps a fire on each of its own), and the leavings
# of old fights over the floor.
func _raise_ground(area: AreaData) -> void:
	var corners := area.pillar_corners()
	var screened := {}
	for corner in corners:
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			screened[corner + offset] = true
	ground.build(area.size, area.walls(), area.theme, screened)
	ground.plant(corners, actors, area.pillars.size(), area.boss != null)
	ground.scatter(hash(String(area.id)) + area.size.x)


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
	# The clearing is told by itself: after a boss's fall has had its
	# moment, and before the cards of any level the last echoes bring.
	var boss_hall := data != null and data.boss != null
	var wait := BOSS_FALL_TIME if boss_hall else 0.0
	var beat := BossOutro.word_time() + SLAIN_HOLD if boss_hall else CLEAR_BEAT
	_levels_after = Time.get_ticks_msec() + roundi((wait + beat) * 1000.0)
	_levels_grace_from = _levels_after
	if wait > 0.0:
		get_tree().create_timer(wait, true, false, true).timeout.connect(_tell_clearing)
	else:
		_tell_clearing()
	# The place breathes out: it brightens, and light rises round her.
	_colour_place(0.0, CLEAR_LIFT, 0.8)
	ground.flash(hero.global_position, 560.0, 0.8, LEVEL_LIGHT, 0.8)
	sparks.burst(hero.global_position + BODY_MIDDLE * 0.4, 22, LEVEL_LIGHT, Vector2.UP, 1.3, Vector2(30.0, 150.0), Vector2(0.5, 1.1), 5.0, 1.0)
	_banner_left = CLEAR_PAUSE + wait
	_clear_left = BOSS_CLEAR_PAUSE if boss_hall else CLEAR_PAUSE


func _tell_clearing() -> void:
	if not is_inside_tree() or not finished:
		return
	# A boss's hall: its fall is told as its entrance was, in place of the
	# line a cleared area gets.
	if data != null and data.boss != null:
		outro = BossOutro.new()
		outro.name = "BossOutro"
		add_child(outro)
		outro.present(self, HubTheme.create())
		outro.begin()
		hud.show_message("")
		hud.set_cinematic(true, BossOutro.BAR_TIME)
		return
	hud.show_message(tr("制圧完了"))
	GameAudio.play(self, &"victory", -16.0)


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


# Where the boss stands as the fight begins.
func boss_place() -> Vector2:
	return Vector2(ground.bounds().get_center().x, ground.bounds().size.y * BOSS_PLACE)


# A boss hall's opening is set up here, before the hall's first frame: the
# world is stopped (so she cannot move, even with a key already held as she
# came through the gate, and no foe acts), the view is held, the fight's
# HUD is put away, and the entrance stands ready. It begins once the hall's
# first frames have been drawn (_process).
func _prepare_entrance() -> void:
	entrance = Entrance.PREPARING
	staging = true
	camera_held = true
	boss_named = false
	get_tree().paused = true
	# The hall's own banner gives way to the boss's name.
	hud.show_message("")
	_banner_left = 0.0
	hud.set_cinematic(true, 0.0)
	_intro = BossIntro.new()
	_intro.name = "BossIntro"
	add_child(_intro)
	_intro.foretold.connect(_foretell_boss)
	_intro.roared.connect(_on_boss_roar)
	_intro.returning.connect(_on_entrance_returning)
	_intro.finished.connect(_finish_entrance)
	# A boss met on a run before may have its entrance cut short.
	_intro.skippable = run.known.has(data.boss.id)
	_intro.present(self, boss_place(), HubTheme.create())
	_entrance_began = Time.get_ticks_msec()


# It is foretold: a sigil burns up out of the floor where it will stand,
# the hall darkens and reddens, the ground trembles.
func _foretell_boss() -> void:
	var at := boss_place()
	var rise := BossIntro.ARRIVE_AT - BossIntro.OMEN_AT
	sigil = BossSigil.new()
	sigil.position = at
	marks.add_child(sigil)
	sigil.rise(rise)
	_colour_place(BOSS_DREAD, 0.86, rise)
	shake(HEAVY_SHAKE * 0.7)
	sparks.burst(at, 26, BossSigil.COLOUR, Vector2.UP, 1.4, Vector2(20.0, 130.0), Vector2(0.5, 1.0), 5.0, 1.0)
	GameAudio.play(self, &"warning", -16.0)
	GameAudio.play(self, &"boss_tremor", -11.0)


# The boss, put where it stands (once: asked again, the same boss).
func bring_boss() -> Foe:
	if boss_foe != null:
		return boss_foe
	var foe := spawn_foe(data.boss, boss_place())
	boss_foe = foe
	foe.phase_changed.connect(_on_boss_phase)
	foe.fell.connect(func(_foe: Foe): boss_down = true)
	foe.fell.connect(_on_boss_fell)
	sparks.burst(foe.global_position + BODY_MIDDLE * 0.5, 34, BossSigil.COLOUR, Vector2.UP, 0.9, Vector2(60.0, 260.0), Vector2(0.4, 0.9), 5.0, 1.0)
	ground.flash(foe.global_position, 620.0, 1.0, BossSigil.COLOUR, 0.5)
	return foe


# Its roar: the sigil it stands in blazes and is gone, sparks fly out from
# it, its light floods the hall, and it is named (its health comes up).
func _on_boss_roar() -> void:
	var foe := bring_boss()
	boss_named = true
	if is_instance_valid(sigil):
		sigil.flare()
	ground.flash(foe.global_position, 900.0, 1.5, BossSigil.COLOUR, 0.7)
	sparks.burst(foe.global_position + BODY_MIDDLE, 46, BossSigil.HEART, Vector2.ZERO, PI, Vector2(120.0, 420.0), Vector2(0.35, 0.8), 5.5)


# The view starts back to her: the fight's HUD comes back with it.
func _on_entrance_returning() -> void:
	if entrance == Entrance.INTRO:
		entrance = Entrance.RETURN
	hud.set_cinematic(false, BossIntro.RETURN_TIME)


# The boss falls: the world slows on a burst of white light, the view goes
# in close and comes back, and the hall is let out of its red.
func _on_boss_fell(foe: Foe) -> void:
	_slow(BOSS_FALL_TIME, BOSS_FALL_SLOW)
	shake(SPECIAL_SHAKE * 1.2)
	ground.flash(foe.global_position, 820.0, 0.7, Color(1.0, 0.95, 0.85), 0.9)
	sparks.burst(foe.global_position + BODY_MIDDLE, 70, GemField.LARGE, Vector2.ZERO, PI, Vector2(80.0, 420.0), Vector2(0.5, 1.3), 6.0, 0.6)
	_punch(BOSS_FALL_ZOOM, BOSS_FALL_TIME + 0.5)
	GameAudio.play(self, &"boss_fall", -9.0)


# The entrance is over, however it ended (played whole, cut short, or let
# go by the area itself): the boss stands, the view and the HUD are the
# fight's, and the world goes on. Safe to call again.
func _finish_entrance() -> void:
	if entrance == Entrance.NONE or entrance == Entrance.ACTIVE:
		return
	entrance = Entrance.ACTIVE
	bring_boss()
	boss_named = true
	staging = false
	camera_held = false
	_intro = null
	if is_instance_valid(sigil):
		sigil.flare()
	if ground.dread < BOSS_DREAD:
		_colour_place(BOSS_DREAD, 0.86, 0.3)
	hud.set_cinematic(false, 0.2)
	if not choosing() and not in_menu():
		get_tree().paused = false
	if _menu_due:
		_menu_due = false
		open_menu()


# The boss's second phase: its summons come in on marks around the hall.
func _on_boss_phase(foe: Foe) -> void:
	shake(HURT_SHAKE * 1.5)
	# Its rage: the hall reddens further, its light bursts from it, and the
	# world slows on the moment.
	_colour_place(RAGE_DREAD, 0.9, 0.4)
	ground.flash(foe.global_position, 900.0, 1.3, BossSigil.COLOUR, 0.6)
	sparks.burst(foe.global_position + BODY_MIDDLE, 40, BossSigil.COLOUR, Vector2.ZERO, PI, Vector2(100.0, 380.0), Vector2(0.4, 0.9), 5.5)
	_slow(RAGE_SLOW_TIME, RAGE_SLOW)
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
		# A level gained while a clearing is being told waits its turn: the
		# level is hers at once, its beat and cards come after.
		if finished and Time.get_ticks_msec() < _levels_after:
			_levels_held = true
			return
		GameAudio.play(self, &"level_up", -16.0)
		_lead_in()


# The beat before the cards: the world slows, a ring of light bursts from
# her, and then the fight stops for the choice.
func _lead_in() -> void:
	if choosing() or run.progression.pending_choices <= 0 or not hero.health.alive():
		return
	_leading = true
	var beat := LEAD_TIME if _hands == 0 else LEAD_BRISK
	hit_stop.hold(beat, LEAD_SLOW)
	shake(HEAVY_SHAKE * 0.4)
	BattleArea.level_light(self, beat)
	get_tree().create_timer(beat, true, false, true).timeout.connect(_after_lead)


# A level gained bursts into light round her: a ring on the floor, the floor
# lit, motes in the air, and the words over her head. The fight's, and what
# the help shows of it (StageArea), so the two are one.
static func level_light(area: CombatArea, beat: float) -> void:
	var she := area.hero
	var ring := GroundRing.new()
	area.marks.add_child(ring)
	ring.start(she.global_position, LEAD_RING, &"heavy")
	area.ground.flash(she.global_position, 560.0, 1.2, LEVEL_LIGHT, beat + 0.35)
	area.sparks.burst(she.global_position + BODY_MIDDLE * 0.4, LEVEL_MOTES, LEVEL_LIGHT, Vector2.UP, 1.3, Vector2(40.0, 200.0), Vector2(0.5, 1.1), 5.0, 1.0)
	area._effect(&"level_up", she.global_position + BODY_MIDDLE * 0.5, Vector2.RIGHT, LEVEL_UP_SCALE)
	area.popups.show_number("LEVEL UP", area.number_spot(she) + Vector2(0.0, -16.0), LEVEL_LIGHT, ECHO_OUTLINE, DamagePopups.FONT_SIZE + 2)


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
	# In full the first time in this area; briskly after; at once when it
	# follows another hand (levels gained together).
	choice.pace = 2 if _chained else (0 if _hands == 0 else 1)
	_hands += 1
	_chained = false
	choice.present_boons(offer, run.build, run.progression.level, run.progression.pending_choices, "", run.rerolls_left)


# The cards on offer drawn again, spending one of the run's rerolls.
func _on_reroll() -> void:
	var offer := run.reroll()
	if offer.is_empty():
		return
	choice.pace = 2
	choice.show_vitals(hero.health.hp, hero.health.max_hp)
	choice.present_boons(offer, run.build, run.progression.level, run.progression.pending_choices, "", run.rerolls_left)


func _on_chosen(id: StringName) -> void:
	run.choose(id)
	var heal := run.rule(&"level_heal")
	if heal > 0.0:
		report_heal(hero, hero.health.heal(roundi(hero.health.max_hp * heal)))
	_levels_grace_from = Time.get_ticks_msec()
	if run.progression.pending_choices > 0:
		_chained = true
		_offer()
	if not choosing():
		get_tree().paused = false
		GameMusic.muffle(self, false)
		# The power taken rises around her as the fight resumes.
		_effect(&"level_up", hero.global_position + BODY_MIDDLE * 0.5, Vector2.RIGHT, LEVEL_UP_SCALE)
		ground.flash(hero.global_position, 480.0, 0.9, LEVEL_LIGHT, 0.5)
		sparks.burst(hero.global_position + BODY_MIDDLE * 0.4, 18, LEVEL_LIGHT, Vector2.UP, 1.3, Vector2(40.0, 170.0), Vector2(0.4, 0.9), 5.0, 1.0)
		GameAudio.play(self, &"level_surge", -14.0)
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
	# Her fall: the world slows and reddens, and the view closes on her.
	_slow(FALL_SLOW_TIME, FALL_SLOW)
	_view(FALL_ZOOM, FALL_SLOW_TIME + 0.4)
	_veil_to(FALL_VEIL, FALL_SLOW_TIME + 0.5, FALL_DARK)
	_colour_place(1.0, 0.72, 0.8)
	ground.flash(hero.global_position, 520.0, 1.0, HURT_COLOUR, 0.6)


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
		# During a boss's entrance the menu waits for its end.
		if staging:
			_menu_due = true
		else:
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
