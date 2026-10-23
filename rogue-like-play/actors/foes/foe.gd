class_name Foe
extends CharacterBody2D

# An enemy of the real-time fight: walks where its FoeBrain steers, hurts the
# hero by touch, runs its attacks (a warning on the floor through the
# wind-up, then the blow, which may carry it forward), staggers and is pushed
# back when struck unless it has super armour, carries statuses (Status:
# shocked it walks slower, burning it loses health every tick), and falls.
# Some fight otherwise (FoeData's specials): an attack with a projectile is
# shot at the hero, a summoner calls its brood around itself now and then,
# and a burster's attack is its end. A
# fallen foe fades
# and is retired; its CombatArea keeps it to bring back (revive) rather than
# making a new one. Off screen it thinks only every few frames.

signal fell(foe: Foe)
signal retired(foe: Foe)
# A boss entered its second phase (FoeData.phase_two_at).
signal phase_changed(foe: Foe)

const FADE_DELAY := 0.35
const FADE_TIME := 0.3
# Off screen, the brain runs once per this many physics frames.
const FAR_THINK_FRAMES := 4
# A lunging attack lands by touch: bodies this much apart or closer.
const LUNGE_REACH := 8.0

# Set by whoever makes it (CombatArea.spawn_foe). No preloaded default: a
# default shared with a script constant elsewhere (a spawn table) makes the
# engine report list errors when the game quits.
@export var data: FoeData
var health: Combatant
var brain := FoeBrain.new()
var target: Hero
var area: CombatArea
var view: FoeView
var _tick_from := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var hit_radius := 14.0
var speed := 95.0
var dying := false
# 1, or 2 once a boss has entered its second phase.
var phase := 1
var walk := Vector2.ZERO
var on_screen := true
# The attack under way, and how far into it.
var attack: AttackData
var attack_time := 0.0
var attack_facing := Vector2.RIGHT
var telegraph: Telegraph
# Status id -> seconds left.
var statuses: Dictionary = {}
var _burn_left := 0.0
var _burn_power := 0.0
var _attack_spent := false
var _attack_shown := false
var _lunge := Vector2.ZERO
var _push := Vector2.ZERO
var _stun_left := 0.0
var _contact_left := 0.0
var _desired := Vector2.ZERO
var _think_left := 0
var _think_time := 0.0
var _fade: Tween
# A summoner's time to its next call, and the brood it has alive.
var _summon_left := 0.0
var brood: Array[Foe] = []
# How far from its middle around it a summoner's brood comes in.
const BROOD_SPREAD := Vector2(50.0, 90.0)


func _ready() -> void:
	rng.randomize()
	_tick_from = global_position
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hit_radius = data.hit_radius
	# Bodies as wide as the hit circle plus a little, so a crowd keeps apart
	# about as far as the drawings are wide.
	var feet := $Feet as CollisionShape2D
	feet.shape = feet.shape.duplicate()
	(feet.shape as CircleShape2D).radius = hit_radius + 2.0
	view = FoeView.new()
	view.name = "View"
	add_child(view)
	view.setup(self)
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.name = "OnScreen"
	notifier.rect = Rect2(-40, -view.height - 20, 80, view.height + 40)
	add_child(notifier)
	notifier.screen_entered.connect(_set_on_screen.bind(true))
	notifier.screen_exited.connect(_set_on_screen.bind(false))
	_think_left = rng.randi_range(0, FAR_THINK_FRAMES - 1)
	revive(position)


# Back on its feet at `at`, whole: a new foe, or one retired and kept.
func revive(at: Vector2) -> void:
	position = at
	_tick_from = at
	if _fade != null:
		_fade.kill()
	health = Combatant.new(data.max_hp, data.defense)
	speed = data.speed * (1.0 + rng.randf_range(-data.speed_spread, data.speed_spread))
	phase = 1
	dying = false
	walk = Vector2.ZERO
	_push = Vector2.ZERO
	_lunge = Vector2.ZERO
	_stun_left = 0.0
	_contact_left = 0.0
	_desired = Vector2.ZERO
	attack = null
	telegraph = null
	statuses.clear()
	brood.clear()
	_summon_left = data.summon_every * 0.5
	modulate.a = 1.0
	collision_layer = Hero.FOES
	collision_mask = Hero.WALLS | Hero.FOES | Hero.HEROES
	brain.reset(self)
	view.revive()


func _physics_process(delta: float) -> void:
	step(delta)


# Its picture is drawn between where it stood as the last physics frame
# began and where it stands (TickSmoothing).
func _process(_delta: float) -> void:
	if view != null:
		view.position = TickSmoothing.lag(_tick_from, global_position)


# One physics frame: tests call it directly.
func step(delta: float) -> void:
	if dying:
		return
	health.step(delta)
	_stun_left = maxf(0.0, _stun_left - delta)
	_contact_left = maxf(0.0, _contact_left - delta)
	_lunge = Vector2.ZERO
	_step_statuses(delta)
	if dying:
		return
	if data.summon_every > 0.0 and data.summon != null:
		_step_summons(delta)
	if attack != null:
		_run_attack(delta)
	else:
		_think(delta)
		walk = walk.move_toward(_desired, data.acceleration * delta)
	_push = _push * exp(-8.0 * delta)
	if _push.length() < 1.0:
		_push = Vector2.ZERO
	velocity = walk + _lunge + _push
	_tick_from = global_position
	move_and_slide()
	_touch()
	if attack == null:
		view.walk(walk if _stun_left <= 0.0 else Vector2.ZERO)


func _think(delta: float) -> void:
	_think_time += delta
	if _stun_left > 0.0 or target == null or not target.health.alive():
		_desired = Vector2.ZERO
		return
	_think_left -= 1
	if _think_left > 0:
		return
	_think_left = 1 if on_screen else FAR_THINK_FRAMES
	_desired = brain.step(self, _think_time)
	if has_status(Status.SHOCK):
		_desired *= 1.0 - Status.SHOCK_SLOW
	_think_time = 0.0


# Starts an attack towards `direction`: the warning goes down at once.
func begin_attack(next: AttackData, direction: Vector2) -> void:
	attack = next
	attack_time = 0.0
	attack_facing = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	_attack_spent = false
	_attack_shown = false
	walk = Vector2.ZERO
	_desired = Vector2.ZERO
	if area != null:
		telegraph = area.show_telegraph(attack, global_position, attack_facing)
	view.face(attack_facing.x < 0.0)
	view.brace(true)


func _run_attack(delta: float) -> void:
	attack_time += delta
	walk = walk.move_toward(Vector2.ZERO, data.acceleration * delta)
	if attack_time < attack.windup:
		if telegraph != null:
			telegraph.set_progress(attack_time / attack.windup)
		return
	if not _attack_shown:
		_attack_shown = true
		view.brace(false)
		view.strike()
		if telegraph != null:
			telegraph.strike()
			telegraph = null
	if attack.hitting(attack_time):
		if attack.projectile != null:
			_shoot()
		else:
			if attack.lunge > 0.0 and attack.active > 0.0:
				_lunge = attack_facing * attack.lunge / attack.active
			_land_attack()
		if data.bursts:
			_burst()
			return
	if attack_time >= attack.duration():
		attack = null
		brain.attack_finished(self)


func _land_attack() -> void:
	if _attack_spent or target == null or not target.health.alive():
		return
	var touched := false
	if attack.lunge > 0.0:
		touched = global_position.distance_to(target.global_position) <= hit_radius + target.hit_radius + LUNGE_REACH
	else:
		touched = HitQuery.touches(attack, global_position, attack_facing, target.global_position, target.hit_radius)
	if not touched:
		return
	# Dodged or landed, the blow is spent: a dash through it stays a dodge.
	_attack_spent = true
	var info := DamageInfo.make(data.power * attack.damage_scale, target.global_position - global_position, attack.knockback, self)
	target.receive(info)


# A ranged attack's shot, once, along the way it faced at the wind-up.
func _shoot() -> void:
	if _attack_spent or area == null:
		return
	_attack_spent = true
	# From the height her own waves fly at, so it meets her where blows are measured (at the feet).
	area.launch(attack.projectile, global_position + Hero.AIM_ORIGIN * 0.5, attack_facing, data.power, true)


# A burster's end: its blow has landed (or missed); it goes up and is gone.
func _burst() -> void:
	if area != null:
		area.report_burst(self)
	attack = null
	vanish()


# A summoner calls its brood while she is near, up to its limit.
func _step_summons(delta: float) -> void:
	_summon_left -= delta
	if _summon_left > 0.0 or area == null or target == null:
		return
	_summon_left = data.summon_every
	brood = brood.filter(func(child: Foe): return is_instance_valid(child) and not child.dying)
	if global_position.distance_to(target.global_position) > data.summon_range:
		return
	var room := mini(data.summon_count, data.summon_limit - brood.size())
	if room <= 0:
		return
	view.strike()
	for index in room:
		var at := global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(BROOD_SPREAD.x, BROOD_SPREAD.y)
		var child := area.summon(data.summon, at)
		if child != null:
			brood.append(child)


func _cancel_attack() -> void:
	if telegraph != null:
		telegraph.cancel()
		telegraph = null
	if attack != null:
		attack = null
		brain.attack_finished(self)
	view.brace(false)


# A blow from the hero; the health lost.
func receive(info: DamageInfo) -> int:
	if dying:
		return 0
	var lost := health.take(info)
	for id in info.inflicts:
		apply_status(id, info.amount)
	_push += info.direction * info.knockback * (1.0 - data.knockback_resist)
	var flinch := data.hitstun > 0.0 and info.flinch
	if flinch:
		_stun_left = data.hitstun
		walk = Vector2.ZERO
		# A hit breaks off a wind-up; once the blow comes, it comes.
		if attack != null and attack_time < attack.windup:
			_cancel_attack()
	view.hurt(flinch and attack == null)
	if not health.alive():
		_fall()
	elif phase == 1 and data.phase_two_at > 0.0 and health.hp <= health.max_hp * data.phase_two_at:
		_enter_phase_two()
	return lost


# The attacks it may use now: its own, and in a second phase those too.
func attack_list() -> Array[AttackData]:
	if phase < 2:
		return data.attacks
	var both: Array[AttackData] = data.attacks.duplicate()
	both.append_array(data.phase_two_attacks)
	return both


# Breaks off what it was doing, quickens, and tells its area (which calls
# its summons and shows it).
func _enter_phase_two() -> void:
	phase = 2
	_cancel_attack()
	speed *= data.phase_two_speed
	brain.cooldown = data.phase_two_cooldown
	phase_changed.emit(self)


# Puts a status on (or renews it). `power` is the blow's strength, which a
# burn's ticks are a share of.
func apply_status(id: StringName, power: float = 0.0) -> void:
	if dying or Status.duration(id) <= 0.0:
		return
	if id == Status.BURN:
		_burn_power = maxf(_burn_power if statuses.has(id) else 0.0, power)
		if not statuses.has(id):
			_burn_left = Status.BURN_TICK
	statuses[id] = Status.duration(id)
	view.show_statuses(statuses)


func has_status(id: StringName) -> bool:
	return statuses.has(id)


func _step_statuses(delta: float) -> void:
	if statuses.is_empty():
		return
	for id: StringName in statuses.keys():
		statuses[id] -= delta
		if statuses[id] <= 0.0:
			statuses.erase(id)
			view.show_statuses(statuses)
	if statuses.has(Status.BURN):
		_burn_left -= delta
		if _burn_left <= 0.0:
			_burn_left += Status.BURN_TICK
			var info := DamageInfo.make(maxf(1.0, _burn_power * Status.BURN_SHARE), Vector2.ZERO)
			info.flinch = false
			if area != null:
				area.deal(self, info)
			else:
				receive(info)


# A touch hurts only outside an attack: during one, the attack is the blow.
func _touch() -> void:
	if attack != null or _contact_left > 0.0 or target == null or not target.health.alive():
		return
	var offset := target.global_position - global_position
	if offset.length() > hit_radius + target.hit_radius + 4.0:
		return
	var lost := target.receive(DamageInfo.make(data.contact_damage, offset, data.contact_knockback, self))
	# A touch the hero dodged is tried again soon; one that landed waits.
	_contact_left = data.contact_cooldown if lost > 0 else 0.1


func _fall() -> void:
	_cancel_attack()
	dying = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	view.fall()
	fell.emit(self)
	_fade = create_tween()
	_fade.tween_interval(FADE_DELAY)
	_fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_fade.tween_callback(_retire)


# Leaves without falling (its area was cleared): no gem, no kill, no
# event; it fades and is retired.
func vanish() -> void:
	if dying:
		return
	_cancel_attack()
	dying = true
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_fade.tween_callback(_retire)


func _retire() -> void:
	if retired.get_connections().is_empty():
		queue_free()
	else:
		retired.emit(self)


func _set_on_screen(shown: bool) -> void:
	on_screen = shown
	# A hidden rig stops animating (RigView); the foe still walks.
	view.visible = shown
