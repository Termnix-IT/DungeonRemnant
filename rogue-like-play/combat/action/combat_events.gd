class_name CombatEvents
extends Node

# What happens in a CombatArea's fight, told as it happens, for whatever
# reacts to it: the run's build (TriggerBoon), and later the HUD and sound.

# A blow from the hero (a swing, a wave, a boon's blast) landed on a foe.
signal attack_hit(foe: Foe, info: DamageInfo)
# A foe fell; its statuses are still on it.
signal enemy_killed(foe: Foe)
signal dash_started(direction: Vector2)
signal dash_ended(direction: Vector2)
signal swing_started(attack: AttackData)
signal skill_used(attack: AttackData)
signal damage_taken(lost: int)
