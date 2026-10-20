class_name Combatant
extends RefCounted

# Health for anything that fights in real time. It settles a blow (defense,
# a floor of 1, the time it stays untouchable after being hurt) and nothing
# else: the push, the flinch and the numbers are its owner's.

var max_hp := 10
var hp := 10
var defense := 0
# After a hurt, blows are ignored for this long (the hero's mercy time; zero
# for enemies, whom each swing may hit once).
var mercy_time := 0.0
var _mercy_left := 0.0


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
	var damage := maxi(1, roundi(info.amount) - defense)
	var lost := mini(hp, damage)
	hp -= lost
	_mercy_left = mercy_time
	return lost


func heal(amount: int) -> int:
	if not alive() or amount <= 0:
		return 0
	var gained := mini(max_hp - hp, amount)
	hp += gained
	return gained
