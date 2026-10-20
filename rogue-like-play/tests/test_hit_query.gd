extends SceneTree

# The real-time hit rules: an attack's shape against target circles
# (HitQuery), its timing (AttackData), health (Combatant) and the hit stop.

var failures := 0
var checks := 0


class Target extends Node2D:
	var hit_radius := 0.0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func shape(kind: AttackData.Shape, reach: float, arc: float = 120.0, width: float = 40.0) -> AttackData:
	var attack := AttackData.new()
	attack.shape = kind
	attack.reach = reach
	attack.arc_degrees = arc
	attack.width = width
	return attack


func run_tests() -> void:
	var arc := shape(AttackData.Shape.ARC, 92.0, 120.0)
	var at := Vector2(100, 100)
	check(HitQuery.touches(arc, at, Vector2.RIGHT, at + Vector2(80, 0)), "An arc hits straight ahead")
	check(HitQuery.touches(arc, at, Vector2.RIGHT, at + Vector2(55, 55)), "An arc hits within its opening")
	check(not HitQuery.touches(arc, at, Vector2.RIGHT, at + Vector2(0, 80)), "An arc misses beside it")
	check(not HitQuery.touches(arc, at, Vector2.RIGHT, at + Vector2(0, 80), 14.0), "A body's size does not widen an arc to its side")
	check(HitQuery.touches(arc, at, Vector2.RIGHT, at + Vector2(30, 75), 14.0), "A body's size reaches into an arc's edge")
	check(not HitQuery.touches(arc, at, Vector2.RIGHT, at + Vector2(-60, 0), 14.0), "An arc misses behind")
	check(HitQuery.touches(arc, at, Vector2.RIGHT, at + Vector2(-5, 0), 14.0), "A body overlapping the attacker is hit")
	check(HitQuery.touches(arc, at, Vector2.RIGHT, at + Vector2(100, 0), 14.0), "A body's size reaches an arc's tip")
	check(not HitQuery.touches(arc, at, Vector2.RIGHT, at + Vector2(110, 0), 14.0), "An arc ends at its reach")
	check(HitQuery.touches(arc, at, Vector2.UP, at + Vector2(0, -80)), "An arc turns with the facing")
	var circle := shape(AttackData.Shape.CIRCLE, 124.0)
	check(HitQuery.touches(circle, at, Vector2.RIGHT, at + Vector2(0, -130), 14.0), "A circle hits all around")
	check(not HitQuery.touches(circle, at, Vector2.RIGHT, at + Vector2(0, -140), 14.0), "A circle ends at its reach")
	var line := shape(AttackData.Shape.LINE, 100.0, 0.0, 40.0)
	check(not HitQuery.touches(line, at, Vector2.RIGHT, at + Vector2(50, 25)), "A line misses beside its width")
	check(HitQuery.touches(line, at, Vector2.RIGHT, at + Vector2(50, 25), 6.0), "A body's size reaches into a line")
	check(not HitQuery.touches(line, at, Vector2.RIGHT, at + Vector2(-10, 0)), "A line misses behind")
	check(HitQuery.touches(line, at, Vector2.RIGHT, at + Vector2(105, 0), 6.0), "A line reaches its end")

	var near := Target.new()
	near.position = at + Vector2(50, 0)
	near.hit_radius = 14.0
	var far := Target.new()
	far.position = at + Vector2(400, 0)
	var spent := Target.new()
	spent.position = at + Vector2(40, 10)
	var plain := Node2D.new()
	plain.position = at + Vector2(60, -5)
	for node in [near, far, spent, plain]:
		root.add_child(node)
	var found := HitQuery.targets(arc, at, Vector2.RIGHT, [near, far, spent, plain], {spent: true})
	check(found == [near, plain], "Targets lists what the shape touches, skipping those already hit, in order")
	far.free()
	check(HitQuery.targets(arc, at, Vector2.RIGHT, [far, near], {}) == [near], "A freed target is skipped")

	var attack: AttackData = preload("res://data/attacks/sword_combo_1.tres")
	check(not attack.hitting(attack.windup - 0.001) and attack.hitting(attack.windup) and not attack.hitting(attack.windup + attack.active), "A swing hits only between its wind-up and the end of its active time")
	check(is_equal_approx(attack.duration(), attack.windup + attack.active + attack.recovery), "A swing lasts wind-up, active and recovery")
	for path in ["res://data/attacks/sword_combo_1.tres", "res://data/attacks/sword_combo_2.tres", "res://data/attacks/sword_combo_3.tres", "res://data/attacks/sword_charged.tres"]:
		var each: AttackData = load(path)
		check(each.combo_after <= each.duration() and each.dash_after <= each.duration(), "Its cancels fall within the swing: " + path)

	var body := Combatant.new(20, 3, 0.5)
	check(body.take(DamageInfo.make(10.0, Vector2.RIGHT)) == 7, "Defense takes off the damage")
	check(body.protected() and body.take(DamageInfo.make(10.0, Vector2.RIGHT)) == 0, "A hurt body is protected for its mercy time")
	body.step(0.6)
	check(not body.protected() and body.take(DamageInfo.make(1.0, Vector2.RIGHT)) == 1, "A blow always takes at least 1")
	body.step(0.6)
	check(body.take(DamageInfo.make(100.0, Vector2.RIGHT)) == 12 and not body.alive(), "A blow takes no more than what is left")
	check(body.take(DamageInfo.make(5.0, Vector2.RIGHT)) == 0 and body.heal(5) == 0, "A fallen body takes no blows and no healing")
	var foe := Combatant.new(30)
	check(foe.take(DamageInfo.make(10.0, Vector2.RIGHT)) == 10 and foe.take(DamageInfo.make(10.0, Vector2.RIGHT)) == 10, "Without mercy time, blows land back to back")
	check(foe.heal(50) == 20 and foe.hp == 30, "Healing stops at full health")
	check(DamageInfo.make(5.0, Vector2(3, 4)).direction.is_equal_approx(Vector2(0.6, 0.8)), "A blow's direction is a unit vector")

	var stop := HitStop.new()
	root.add_child(stop)
	stop.request(0.03)
	check(stop.active() and is_equal_approx(Engine.time_scale, HitStop.SLOW), "A hit stop slows the world")
	stop.request(5.0)
	var started := Time.get_ticks_msec()
	while stop.active() and Time.get_ticks_msec() - started < 1000:
		await process_frame
	var held := Time.get_ticks_msec() - started
	check(not stop.active() and is_equal_approx(Engine.time_scale, 1.0), "The hit stop ends and the world runs again")
	check(held < HitStop.MAX_HOLD * 1000.0 + 120.0, "Blows in a row stretch the hit stop only up to its cap")
	stop.request(1.0)
	stop.queue_free()
	await process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "Leaving the tree ends the hit stop")

	print("Hit query tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
