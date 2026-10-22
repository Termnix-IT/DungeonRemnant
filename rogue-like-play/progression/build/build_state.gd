class_name BuildState
extends RefCounted

# The run's build: the boons taken and their ranks. It offers the next
# choice, adds up the stats, shapes each swing as it starts (AttackBoon and
# attack_speed), and, bound to a CombatArea, answers its events with the
# TriggerBoons. A stat can also be raised for a while (boost). A new run
# starts a new BuildState, so nothing carries over.

signal changed

# Triggered blows in one physics frame, at most: a chain that kills shocked
# foes can set off more chains, and this keeps a crowd from looping forever.
const MAX_FIRES_PER_FRAME := 24
const OFFER_COUNT := 3

var pool: Array[BoonData] = []
# Boon id -> rank.
var ranks: Dictionary = {}
var area: CombatArea
var hero: Hero
# TriggerBoon -> seconds until it may fire again.
var _resting: Dictionary = {}
# [stat, amount, seconds left] raised for a while.
var _boosts: Array = []
var _fire_frame := -1
var _fired := 0


func _init(boons: Array[BoonData] = []) -> void:
	pool = boons


func rank(id: StringName) -> int:
	return int(ranks.get(id, 0))


func owned() -> Array[BoonData]:
	var held: Array[BoonData] = []
	for boon in pool:
		if rank(boon.id) > 0:
			held.append(boon)
	return held


func can_take(boon: BoonData) -> bool:
	if boon == null or rank(boon.id) >= boon.max_level:
		return false
	if boon.requires.is_empty():
		return true
	return boon.requires.any(func(id: StringName): return rank(id) > 0)


func find(id: StringName) -> BoonData:
	for boon in pool:
		if boon.id == id:
			return boon
	return null


# Up to `count` different boons that can be taken, picked by weight.
func offer(rng: RandomNumberGenerator, count: int = OFFER_COUNT) -> Array[BoonData]:
	var candidates: Array[BoonData] = []
	for boon in pool:
		if can_take(boon) and boon.weight > 0.0:
			candidates.append(boon)
	var picked: Array[BoonData] = []
	while picked.size() < count and not candidates.is_empty():
		var total := 0.0
		for boon in candidates:
			total += boon.weight
		var roll := rng.randf() * total
		var index := candidates.size() - 1
		for at in candidates.size():
			roll -= candidates[at].weight
			if roll <= 0.0:
				index = at
				break
		picked.append(candidates[index])
		candidates.remove_at(index)
	return picked


func take(boon: BoonData) -> bool:
	if not can_take(boon):
		return false
	ranks[boon.id] = rank(boon.id) + 1
	changed.emit()
	return true


func stat(name: StringName) -> float:
	var total := 0.0
	for boost: Array in _boosts:
		if boost[0] == name:
			total += boost[1]
	for boon in owned():
		for effect in boon.effects:
			total += effect.stat(name, rank(boon.id))
	return total


# A swing as the build makes it: the AttackBoons that watch for its kind
# (combo, charged, skill) change a copy of it, and attack_speed shortens a
# combo or charged swing's times. The data itself is never changed.
func shape(attack: AttackData, kind: StringName, combo_index: int = -1, since_dash: float = INF) -> AttackData:
	var shaped: AttackData = attack.duplicate()
	shaped.inflicts = attack.inflicts.duplicate()
	for boon in owned():
		for effect in boon.effects:
			if effect is AttackBoon and effect.applies(kind, combo_index, since_dash):
				effect.change(shaped, rank(boon.id))
	var speed := stat(&"attack_speed")
	if kind != &"skill" and speed > 0.0:
		var quicken := 1.0 / (1.0 + speed)
		shaped.windup *= quicken
		shaped.active *= quicken
		shaped.recovery *= quicken
		shaped.combo_after *= quicken
		shaped.dash_after *= quicken
	return shaped


# Listens to the area's events with the triggers, on behalf of its hero.
func bind(combat_area: CombatArea, owner_hero: Hero) -> void:
	area = combat_area
	hero = owner_hero
	var events := area.events
	events.attack_hit.connect(func(foe: Foe, _info: DamageInfo): _answer(TriggerBoon.On.HIT, foe))
	events.enemy_killed.connect(func(foe: Foe): _answer(TriggerBoon.On.KILL, foe))
	events.dash_started.connect(func(_direction: Vector2): _answer(TriggerBoon.On.DASH_START, null))
	events.dash_ended.connect(func(_direction: Vector2): _answer(TriggerBoon.On.DASH_END, null))
	events.skill_used.connect(func(_attack: AttackData): _answer(TriggerBoon.On.SKILL, null))
	events.damage_taken.connect(func(_lost: int): _answer(TriggerBoon.On.HURT, null))


# Raises a stat by `amount` for `seconds` of the fight.
func boost(name: StringName, amount: float, seconds: float) -> void:
	_boosts.append([name, amount, seconds])


func step(delta: float) -> void:
	for boost: Array in _boosts:
		boost[2] -= delta
	_boosts = _boosts.filter(func(boost: Array): return boost[2] > 0.0)
	for trigger: TriggerBoon in _resting.keys():
		_resting[trigger] -= delta
		if _resting[trigger] <= 0.0:
			_resting.erase(trigger)


func _answer(event: TriggerBoon.On, foe: Foe) -> void:
	if area == null or hero == null:
		return
	for boon in owned():
		for effect in boon.effects:
			if effect is TriggerBoon and effect.on == event:
				_fire(effect, rank(boon.id), foe)


func _fire(trigger: TriggerBoon, level: int, foe: Foe) -> void:
	if _resting.has(trigger):
		return
	if not trigger.needs_status.is_empty() and (foe == null or not foe.has_status(trigger.needs_status)):
		return
	if trigger.chance < 1.0 and randf() >= trigger.chance:
		return
	var frame := Engine.get_physics_frames()
	if frame != _fire_frame:
		_fire_frame = frame
		_fired = 0
	if _fired >= MAX_FIRES_PER_FRAME:
		return
	_fired += 1
	if trigger.cooldown > 0.0:
		_resting[trigger] = trigger.cooldown
	var center := foe.global_position if trigger.at == TriggerBoon.At.TARGET and foe != null else hero.global_position
	var power := hero.power() * trigger.damage(level)
	match trigger.action:
		TriggerBoon.Action.BLAST:
			area.blast(center, trigger.radius, power, trigger.knockback, trigger.inflicts, trigger.effect)
		TriggerBoon.Action.CHAIN:
			area.chain(center, foe, trigger.jump_count(level), trigger.radius, power, trigger.inflicts)
		TriggerBoon.Action.HEAL:
			if hero.health.heal(trigger.heal_amount(level)) > 0:
				area.report_heal(hero)
