class_name Combatant
extends RefCounted

# Health for anything that fights in real time. It settles a blow (defense,
# a floor of 1, the time it stays untouchable after being hurt, and the hero's
# last stands: a blow that would fell her leaves her at 1 instead) and
# nothing else: the push, the flinch and the numbers are its owner's.
# Defense takes its points off a blow, but never more than GUARD_SHARE of
# that blow: taken off whole, a guard of 4 halved a small blow and barely
# touched a heavy one, so the many light blows of a build (chains, bursts,
# burns) came to nothing against an armoured elite or a boss. A defense
# below zero (a curse's) adds its points to every blow, uncapped.

# A last stand was spent: the blow left 1 health.
signal stood

# The most of a blow that defense can take off.
const GUARD_SHARE := 0.3

var max_hp := 10
var hp := 10
var defense := 0
# After a hurt, blows are ignored for this long (the hero's mercy time; zero
# for enemies, whom each swing may hit once).
var mercy_time := 0.0
# Blows that would fell it it survives at 1, and how long it is then untouchable.
var last_stands := 0
var stand_mercy := 1.0
var _mercy_left := 0.0
# Healing reaches it at this share (a curse's thirst halves it), never less
# than 1 for a healing of 1 or more.
var mending := 1.0


func _init(health: int = 10, armor: int = 0, mercy: float = 0.0) -> void:
	max_hp = maxi(1, health)
	hp = max_hp
	defense = armor
	mercy_time = mercy


func alive() -> bool:
	return hp > 0


func protected() -> bool:
	return _mercy_left > 0.0


func step(delta: float) -> void:
	_mercy_left = maxf(0.0, _mercy_left - delta)


# The health actually lost; 0 when the blow is ignored.
func take(info: DamageInfo) -> int:
	if not alive() or protected() or info == null:
		return 0
	var damage := maxi(1, roundi(info.amount) - guard(roundi(info.amount)))
	var lost := mini(hp, damage)
	if lost >= hp and last_stands > 0:
		last_stands -= 1
		lost = hp - 1
		hp = 1
		_mercy_left = maxf(mercy_time, stand_mercy)
		stood.emit()
		return lost
	hp -= lost
	_mercy_left = mercy_time
	return lost


# What defense takes off a blow of this size.
func guard(blow: int) -> int:
	return defense if defense <= 0 else mini(defense, roundi(blow * GUARD_SHARE))


# Untouchable for at least `seconds` from now.
func shield(seconds: float) -> void:
	_mercy_left = maxf(_mercy_left, seconds)


func heal(amount: int) -> int:
	if not alive() or amount <= 0:
		return 0
	var gained := mini(max_hp - hp, maxi(1, roundi(amount * mending)))
	hp += gained
	return gained
