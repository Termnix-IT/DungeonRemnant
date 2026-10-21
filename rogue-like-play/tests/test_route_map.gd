extends SceneTree

# The route through a chapter and the areas on it: the shape of the map
# (layers, choices, fields first, no two choices alike, the boss last, the
# same seed the same map), rewards leaning by the kind of area without being
# fixed, and each area's data (its ground laid out the same every time and
# clear in the middle, what the map tells of it, how it is cleared).

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func describe(map: RouteMap) -> Array:
	var lines := []
	for layer in map.size():
		for waypoint: RouteMap.Waypoint in map.nodes(layer):
			lines.append("%d:%s:%d" % [layer, waypoint.area.id, waypoint.reward])
	return lines


func run_tests() -> void:
	var chapter: ChapterData = load("res://data/chapters/ash_corridor.tres")
	var shaped := true
	var fields_first := true
	var unique := true
	var boss_last := true
	var layers_marked := true
	for seed_value in range(1, 61):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := RouteMap.generate(chapter, rng)
		if map.size() != chapter.layers + 1:
			shaped = false
		for layer in map.size():
			var waypoints := map.nodes(layer)
			var last := layer == map.size() - 1
			if not last and (waypoints.size() < chapter.choices.x or waypoints.size() > chapter.choices.y):
				shaped = false
			var seen := {}
			for waypoint: RouteMap.Waypoint in waypoints:
				var key := "%s:%d" % [waypoint.area.id, waypoint.reward]
				if seen.has(key):
					unique = false
				seen[key] = true
				if layer == 0 and waypoint.area.kind != AreaData.Kind.FIELD:
					fields_first = false
				if waypoint.layer != layer:
					layers_marked = false
				if last != (waypoint.area.kind == AreaData.Kind.BOSS):
					boss_last = false
			if last and waypoints.size() != 1:
				boss_last = false
	check(shaped, "Each map has the chapter's layers, each with 2 or 3 choices, and the boss")
	check(fields_first, "The first layer offers only open fields")
	check(unique, "No two choices of a layer are alike")
	check(boss_last, "The last layer is the boss alone, and only it")
	check(layers_marked, "Each waypoint knows its layer")
	var first := RandomNumberGenerator.new()
	first.seed = 77
	var second := RandomNumberGenerator.new()
	second.seed = 77
	check(describe(RouteMap.generate(chapter, first)) == describe(RouteMap.generate(chapter, second)), "The same seed lays out the same route")

	# Rewards lean by the kind of area, but are not fixed.
	var field: AreaData = load("res://data/areas/moss_plain.tres")
	var arena: AreaData = load("res://data/areas/pillar_arena.tres")
	var rolls := RandomNumberGenerator.new()
	rolls.seed = 5
	var field_counts := {}
	var arena_counts := {}
	for roll in 600:
		var from_field := RouteMap.roll_reward(field, rolls)
		var from_arena := RouteMap.roll_reward(arena, rolls)
		field_counts[from_field] = int(field_counts.get(from_field, 0)) + 1
		arena_counts[from_arena] = int(arena_counts.get(from_arena, 0)) + 1
	check(int(arena_counts.get(AreaData.Reward.BOON, 0)) > int(field_counts.get(AreaData.Reward.BOON, 0)), "Arenas offer boons more often than fields")
	check(int(field_counts.get(AreaData.Reward.ECHO, 0)) > int(arena_counts.get(AreaData.Reward.ECHO, 0)), "Fields offer echo more often than arenas")
	check(field_counts.size() == 3 and arena_counts.size() == 3, "Every kind of reward can still come from either")

	# The areas' data.
	var areas: Array[AreaData] = []
	areas.assign(chapter.areas)
	areas.append(chapter.boss)
	for area in areas:
		var name := String(area.id)
		check(not area.display_name.is_empty() and not area.condition.is_empty() and not area.foe_summary.is_empty() and area.expected_time > 0, "The map can tell of it: " + name)
		check(area.kind_name() != "" and area.stars().length() == 3 and area.echo > 0, "Its kind, stars and echo: " + name)
		var walls := area.walls()
		check(walls == area.walls(), "Its ground is laid out the same every time: " + name)
		var border := true
		for x in area.size.x:
			border = border and walls.has(Vector2i(x, 0)) and walls.has(Vector2i(x, area.size.y - 1))
		for y in area.size.y:
			border = border and walls.has(Vector2i(0, y)) and walls.has(Vector2i(area.size.x - 1, y))
		check(border, "A wall runs all round it: " + name)
		var middle := area.size / 2
		var clear := true
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			clear = clear and not walls.has(middle + offset)
		check(clear, "The middle, where she starts, is open: " + name)
		if area.kind == AreaData.Kind.FIELD:
			check(area.spawn_table != null and (area.survive_time > 0.0 or area.kill_target > 0), "A field sends a crowd and has a goal: " + name)
		else:
			var total := 0
			for wave in area.waves:
				total += wave.total()
			check(area.waves.size() >= 2 and total > 0, "An arena or the boss hall has its waves: " + name)
	var wave: WaveData = arena.waves[2]
	var order := wave.order()
	check(order.size() == wave.total() and order[0] == wave.foes[0] and order[1] == wave.foes[1], "A wave's foes arrive with the kinds taken in turn")
	check(AreaData.reward_name(AreaData.Reward.ECHO).begins_with("残響"), "Rewards have names for the map")

	print("Route map tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
