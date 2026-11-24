class_name StageArea
extends CombatArea

# A small real battlefield for showing the fight outside a run (FightStage):
# the bestiary's observations, the help's demonstrations, the settings'
# previews. It is the fight's own CombatArea, so what stands and strikes in
# it is drawn, sounds and behaves as in play: the same ground and light, the
# same hero and foes, the same warnings, effects, numbers, shards and
# sounds. A change to any of them in the fight is a change here.
#
# It belongs to no run: nothing in it reaches the save, a run's echoes or
# levels, or the bestiary's records (its own `met` and `kills` are thrown
# away with it). Its moments of stopped time stop only itself (HitStop's
# scope), never the engine, so a hit shown here does not hitch the screen
# that shows it; and it runs while the game is stopped (the help opened in
# a run), being apart from that game.
#
# Whoever shows it gives it a scene: actors put in with enter_hero() and
# enter_foe(), and things to do at times with at(). The hero is steered by
# the scene (steer(), press()), not by the player. When `period` is over it
# says so (`ended`) and the stage builds the scene afresh, so a scene never
# carries anything over from its last showing.

signal ended

# The room: wide enough that no wall is seen in a close view.
const CELLS := Vector2i(34, 22)
# A foe put to strike stands still again this long after its blow is done.
const REST_AFTER_BLOW := 0.3

# Which of the fight's themes the room is built in (AreaGround.THEMES).
var theme_index := 0
# The scene starts over after this long (0: it runs on).
var period := 0.0
# Where the light stands when no hero does.
var light_at := Vector2.ZERO
var _steps: Array = []
var _clock := 0.0
var _held := HeroInput.new()
var _pressed: HeroInput = null
var _over := false


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hall := AreaData.new()
	hall.size = CELLS
	ground.build(hall.size, hall.walls(), theme_index, {})
	ground.scatter(theme_index * 31 + 7)
	camera_held = true
	camera.position_smoothing_enabled = false
	camera.global_position = middle()
	light_at = middle()
	# Apart from the game: it runs whether or not the game is stopped, and
	# its own stops hold only itself.
	var own: Array[Node] = [marks, gems, actors, effects]
	for part in own:
		part.process_mode = Node.PROCESS_MODE_ALWAYS
	hit_stop.scope = own


func middle() -> Vector2:
	return ground.bounds().get_center()


# `what` is done `time` seconds into the scene.
func at(time: float, what: Callable) -> void:
	_steps.append([time, what])
	_steps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


# The hero, steered by the scene. She cannot fall here.
func enter_hero(spot: Vector2) -> Hero:
	spawn_hero(spot)
	hero.controlled = false
	# Its stops switch her processing off; she stays in the room's physics.
	hero.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	hero.health.max_hp = 100000
	hero.health.hp = 100000
	hero.motor.equip_skills([MetaProgress.SKILLS[0], MetaProgress.SKILLS[1]])
	hero.equip_special(MetaProgress.SPECIALS[0])
	return hero


# A foe. `awake`: it hunts her as in play; else it stands until it is told
# to strike (strike_with).
func enter_foe(data: FoeData, spot: Vector2, awake: bool = false) -> Foe:
	var foe := spawn_foe(data, spot)
	foe.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	if not awake:
		foe.target = null
	return foe


# What the scene holds down for her: a way to walk, a way to face, the blow.
func steer(move: Vector2 = Vector2.ZERO, aim: Vector2 = Vector2.ZERO, strike_held: bool = false) -> void:
	_held = HeroInput.make(move, aim, false, strike_held)


# One press for her: &"strike", &"dash", &"skill", &"skill_2" or &"special".
func press(what: StringName, aim: Vector2 = Vector2.ZERO) -> void:
	var once := HeroInput.make(_held.move, aim if aim.length() > 0.01 else _held.aim, what == &"strike", _held.strike_held, what == &"dash", what == &"skill")
	once.skill_2_pressed = what == &"skill_2"
	once.special_pressed = what == &"special"
	_pressed = once


# A standing foe strikes at her with one of its attacks, then stands again.
func strike_with(foe: Foe, attack: AttackData) -> void:
	if not is_instance_valid(foe) or foe.dying or hero == null:
		return
	foe.target = hero
	foe.begin_attack(attack, hero.global_position - foe.global_position)
	foe.set_meta(&"resting", true)


# A level's light round her, as the fight shows one gained (there is no
# level here to gain: it is only shown).
func show_level() -> void:
	if hero == null:
		return
	BattleArea.level_light(self, BattleArea.LEAD_TIME)
	GameAudio.play(self, &"level_up", -16.0)


func _process(delta: float) -> void:
	super(delta)
	if hero == null:
		ground.follow(light_at, camera.get_screen_center_position())


func _physics_process(delta: float) -> void:
	super(delta)
	# Its own stop of time holds its clock and her too.
	if hit_stop.active() or _over:
		return
	_clock += delta
	while not _steps.is_empty() and _steps[0][0] <= _clock:
		var step: Array = _steps.pop_front()
		(step[1] as Callable).call()
	if hero != null and not hero.controlled and hero.health.alive():
		hero.step(_pressed if _pressed != null else _held, delta)
		_pressed = null
	# A foe told to strike goes back to standing once its blow is done.
	for foe in foes:
		if foe.has_meta(&"resting") and foe.attack == null and not foe.dying:
			foe.remove_meta(&"resting")
			foe.target = null
	if period > 0.0 and _clock >= period:
		_over = true
		ended.emit()
