class_name StageScenes
extends RefCounted

# The scenes the help and the settings show on a FightStage: each a function
# that fills a fresh StageArea (who stands where, and what is done when).
# They are played with the fight's own hero, foes, warnings, effects and
# sounds, so what a player sees here is what the game does.
#
# A scene only tells her what to press and when (as a player would), and
# where the foes stand: what follows (the blows, the falls, the shards) is
# the fight's own doing.

const SENTINEL := preload("res://data/foes/wandering_sentinel.tres")
const RAT := preload("res://data/foes/dashing_rat.tres")
const CHARGER := preload("res://data/foes/raging_charger.tres")

# The scenes of the help's controls, in the order they are listed:
# [id, name, what is shown].
const CONTROLS := [
	[&"move", "移動", "足元の輪が主人公です。移動の向きへ走ります。"],
	[&"strike", "攻撃・連撃", "続けて押すと連撃になり、最後の一撃が締めです。"],
	[&"charge", "溜め攻撃", "長押しで溜め、離すと周りをまとめて打ちます。"],
	[&"dash", "回避", "赤い印が埋まる前に、ダッシュで外へ抜けます。"],
	[&"skill", "スキル", "使うと、しばらく待ってからまた使えます。"],
	[&"special", "必殺技", "ゲージが満ちると、周りの敵をまとめて倒します。"],
	[&"shards", "残響のかけら", "倒した敵が落とすかけらを集めると、レベルが上がります。"],
]


static func scene(id: StringName) -> Callable:
	match id:
		&"move":
			return move
		&"strike":
			return strike
		&"charge":
			return charge
		&"dash":
			return dash
		&"skill":
			return skill
		&"special":
			return special
		&"shards":
			return shards
		&"shake":
			return shake
		&"sounds":
			return sounds
	return move


# She runs round a square.
static func move(area: StageArea) -> void:
	area.period = 4.0
	area.enter_hero(area.middle() + Vector2(-80.0, -45.0))
	var ways: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var legs: Array[float] = [0.66, 0.4, 0.66, 0.4]
	var clock := 0.5
	for index in ways.size():
		area.at(clock, area.steer.bind(ways[index], ways[index]))
		clock += legs[index]
		area.at(clock, area.steer.bind(Vector2.ZERO, ways[index]))
		clock += 0.18


# Three blows in a row at a sentinel: the combo and its last blow.
static func strike(area: StageArea) -> void:
	area.period = 4.0
	area.enter_hero(area.middle() + Vector2(-40.0, 10.0))
	area.enter_foe(SENTINEL, area.middle() + Vector2(30.0, 10.0))
	area.enter_foe(SENTINEL, area.middle() + Vector2(52.0, -34.0))
	area.steer(Vector2.ZERO, Vector2.RIGHT)
	for blow in 3:
		area.at(0.7 + blow * 0.36, area.press.bind(&"strike", Vector2.RIGHT))
	for blow in 3:
		area.at(2.4 + blow * 0.36, area.press.bind(&"strike", Vector2(1.0, -0.5)))


# The blow held, and let go among foes: rats, which the one blow fells.
static func charge(area: StageArea) -> void:
	area.period = 4.2
	area.enter_hero(area.middle())
	for index in 5:
		area.enter_foe(RAT, area.middle() + Vector2.RIGHT.rotated(index * TAU / 5.0 + 0.4) * 70.0)
	area.at(0.6, func():
		area.steer(Vector2.ZERO, Vector2.RIGHT, true)
		area.press(&"strike", Vector2.RIGHT))
	area.at(1.9, area.steer.bind(Vector2.ZERO, Vector2.RIGHT, false))


# A charger's slam warned of on the floor, and dashed out of.
static func dash(area: StageArea) -> void:
	area.period = 4.4
	area.enter_hero(area.middle() + Vector2(40.0, 16.0))
	var beast := area.enter_foe(CHARGER, area.middle() + Vector2(134.0, 0.0))
	area.at(0.7, area.strike_with.bind(beast, CHARGER.attacks[0]))
	area.at(0.7 + CHARGER.attacks[0].windup - 0.2, func():
		area.steer(Vector2.LEFT, Vector2.LEFT)
		area.press(&"dash", Vector2.LEFT))
	area.at(0.7 + CHARGER.attacks[0].windup + 0.25, area.steer)
	area.at(2.6, area.steer.bind(Vector2.RIGHT, Vector2.RIGHT))
	area.at(3.0, area.steer.bind(Vector2.ZERO, Vector2.RIGHT))
	area.at(3.1, area.press.bind(&"strike", Vector2.RIGHT))


# Her two skills, one after the other.
static func skill(area: StageArea) -> void:
	area.period = 5.0
	area.enter_hero(area.middle() + Vector2(-70.0, 0.0))
	for index in 4:
		area.enter_foe(SENTINEL, area.middle() + Vector2(10.0 + (index % 2) * 46.0, -30.0 + (index / 2) * 60.0))
	for index in 3:
		area.enter_foe(RAT, area.middle() + Vector2(150.0, -50.0 + index * 50.0))
	area.steer(Vector2.ZERO, Vector2.RIGHT)
	area.at(0.8, area.press.bind(&"skill", Vector2.RIGHT))
	area.at(2.6, area.press.bind(&"skill_2", Vector2.RIGHT))


# The special move let loose in a crowd.
static func special(area: StageArea) -> void:
	area.period = 4.6
	var she := area.enter_hero(area.middle())
	for index in 9:
		area.enter_foe(SENTINEL if index % 3 > 0 else RAT, area.middle() + Vector2.RIGHT.rotated(index * TAU / 9.0) * (86.0 + 24.0 * (index % 2)))
	area.at(0.3, func(): she.special_charge = she.special.charge)
	area.at(1.2, area.press.bind(&"special", Vector2.RIGHT))


# Foes felled, their shards lying, drawn to her as she comes near, and the
# level they bring.
static func shards(area: StageArea) -> void:
	area.period = 5.2
	area.enter_hero(area.middle() + Vector2(-150.0, 20.0))
	var spots: Array[Vector2] = [Vector2(40.0, -30.0), Vector2(90.0, 30.0), Vector2(150.0, -10.0)]
	var fallen: Array[Foe] = []
	for spot in spots:
		fallen.append(area.enter_foe(SENTINEL, area.middle() + spot))
	area.at(0.5, func():
		for foe in fallen:
			foe.receive(DamageInfo.make(10000.0, Vector2.RIGHT)))
	area.at(1.5, area.steer.bind(Vector2(1.0, 0.0), Vector2.RIGHT))
	area.at(2.75, area.steer.bind(Vector2.ZERO, Vector2.RIGHT))
	# The last of them in, the level they bring: its light and its sound, as
	# the fight shows a level (the cards it brings are tried in the practice
	# ground).
	area.at(3.3, area.show_level)


# Blows given and taken, one after another: what the shake setting scales.
static func shake(area: StageArea) -> void:
	area.period = 4.6
	area.enter_hero(area.middle() + Vector2(-40.0, 10.0))
	var beast := area.enter_foe(CHARGER, area.middle() + Vector2(56.0, 0.0))
	area.steer(Vector2.ZERO, Vector2.RIGHT)
	area.at(0.5, area.strike_with.bind(beast, CHARGER.attacks[0]))
	area.at(2.2, func():
		area.steer(Vector2.ZERO, Vector2.RIGHT, true)
		area.press(&"strike", Vector2.RIGHT))
	area.at(3.4, area.steer.bind(Vector2.ZERO, Vector2.RIGHT, false))


# A short fight with every kind of the fight's sounds in it.
static func sounds(area: StageArea) -> void:
	area.period = 5.0
	area.enter_hero(area.middle() + Vector2(-50.0, 0.0))
	for index in 4:
		area.enter_foe(SENTINEL, area.middle() + Vector2(20.0 + (index % 2) * 44.0, -26.0 + (index / 2) * 52.0))
	area.steer(Vector2.ZERO, Vector2.RIGHT)
	for blow in 3:
		area.at(0.6 + blow * 0.36, area.press.bind(&"strike", Vector2.RIGHT))
	area.at(2.2, area.press.bind(&"skill", Vector2.RIGHT))
	area.at(3.2, area.steer.bind(Vector2.RIGHT, Vector2.RIGHT))
	area.at(4.2, area.steer)
