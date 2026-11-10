class_name FoeBrain
extends RefCounted

# What a foe means to do: chase the hero, and when its cooldown is over,
# start one of its attacks (Foe.attack_list) that fits the distance, picked
# at random among those that do, but never the one it used last while
# another fits: a boss does not repeat itself, so what it does next can be
# read from what it just did. The foe runs the attack itself
# (Foe.begin_attack) and reports its end.

const FIRST_ATTACK_DELAY := Vector2(0.4, 1.2)

var cooldown := 0.0
# The attack it started last (null: none yet).
var last: AttackData


func reset(foe: Foe) -> void:
	# A pack that arrives together does not strike together.
	cooldown = foe.rng.randf_range(FIRST_ATTACK_DELAY.x, FIRST_ATTACK_DELAY.y)
	last = null


# The velocity it wants to walk at, after `elapsed` seconds since it last
# thought.
func step(foe: Foe, elapsed: float) -> Vector2:
	cooldown = maxf(0.0, cooldown - elapsed)
	var offset := foe.target.global_position - foe.global_position
	var distance := offset.length()
	if cooldown <= 0.0:
		var fitting: Array[AttackData] = []
		for attack in foe.attack_list():
			if distance >= attack.use_from and distance <= attack.use_until:
				fitting.append(attack)
		if fitting.size() > 1:
			fitting.erase(last)
		if not fitting.is_empty():
			last = fitting[foe.rng.randi_range(0, fitting.size() - 1)]
			foe.begin_attack(last, offset)
			return Vector2.ZERO
	if distance < 1.0:
		return Vector2.ZERO
	return offset / distance * foe.speed


func attack_finished(foe: Foe) -> void:
	cooldown = foe.data.phase_two_cooldown if foe.phase == 2 else foe.data.attack_cooldown
