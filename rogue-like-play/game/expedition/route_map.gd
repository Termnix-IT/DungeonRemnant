class_name RouteMap
extends RefCounted

# A run's way through a chapter, laid out when the run begins: a list of
# layers, each a few nodes to choose between, and the boss alone at the end.
# A waypoint is an area and the reward it offers, rolled from the area's
# reward_weights. From the second layer on, a layer may also offer one of
# the chapter's events (in place of its last choice when it is full).
#
# The first layer is open whole (first_choices of it). Each node leads on to
# as many nodes of the next layer as its area's branches roll, one or two as
# a rule and three from the trials, so a pick narrows the way ahead
# as node maps commonly do. Paths go to neighbouring nodes, in step down both
# layers so they keep apart, and every node is reached by one at least.

class Waypoint:
	var area: AreaData
	var reward: AreaData.Reward
	var layer := 0
	# The nodes of the next layer its paths lead to (Waypoints).
	var next: Array = []

	func _init(area_data: AreaData, reward_kind: AreaData.Reward, layer_index: int) -> void:
		area = area_data
		reward = reward_kind
		layer = layer_index


var chapter: ChapterData
var layers: Array = []


static func generate(chapter_data: ChapterData, rng: RandomNumberGenerator) -> RouteMap:
	var map := RouteMap.new()
	map.chapter = chapter_data
	# How many paths each node of the layer before would take on.
	var wants: Array[int] = []
	for index in chapter_data.layers:
		var pool: Array[AreaData] = []
		for area in chapter_data.areas:
			if index > 0 or area.kind == AreaData.Kind.FIELD:
				pool.append(area)
		var count := chapter_data.first_choices if index == 0 else rng.randi_range(chapter_data.choices.x, chapter_data.choices.y)
		# A stage that opens three ways is given three to open onto.
		if not wants.is_empty():
			count = maxi(count, mini(wants.max(), chapter_data.choices.y))
		var nodes: Array[Waypoint] = []
		var tries := 0
		while nodes.size() < count and tries < 50:
			tries += 1
			var node := Waypoint.new(pool[rng.randi_range(0, pool.size() - 1)], AreaData.Reward.BOON, index)
			node.reward = roll_reward(node.area, rng)
			# No two choices alike: a different area, or the same with
			# another reward.
			if nodes.any(func(other: Waypoint): return other.area == node.area and other.reward == node.reward):
				continue
			nodes.append(node)
		if index > 0 and not chapter_data.events.is_empty() and rng.randf() < chapter_data.event_chance:
			var stop := Waypoint.new(chapter_data.events[rng.randi_range(0, chapter_data.events.size() - 1)], AreaData.Reward.BOON, index)
			if nodes.size() >= chapter_data.choices.y:
				nodes[nodes.size() - 1] = stop
			else:
				nodes.append(stop)
		if index > 0:
			link(map.layers[index - 1], nodes, wants)
		wants.clear()
		for node in nodes:
			wants.append(rng.randi_range(node.area.branches.x, node.area.branches.y))
		map.layers.append(nodes)
	var boss := Waypoint.new(chapter_data.boss, AreaData.Reward.ECHO, chapter_data.layers)
	if not map.layers.is_empty():
		for node: Waypoint in map.layers.back():
			node.next = [boss]
	var last: Array[Waypoint] = [boss]
	map.layers.append(last)
	return map


# Joins a layer to the next. Each node takes the paths it wants (no more than
# the next layer has) to a run of neighbouring nodes, the runs stepping down
# the next layer as the nodes step down this one, so paths keep apart (a node
# leading to the whole layer steps nowhere, and holds no other back). Where a
# node of the next layer would be left unreached, the node beside it takes
# one more path.
static func link(from: Array, to: Array, wants: Array[int]) -> void:
	var count := from.size()
	var room := to.size()
	if count == 0 or room == 0:
		return
	var starts: Array[int] = []
	var ends: Array[int] = []
	# The last node above whose run did not take the whole layer.
	var above := -1
	for row in count:
		var reach := clampi(wants[row] if row < wants.size() else 1, 1, room)
		# Where its run would sit with the layer spread evenly.
		var start := roundi(float(row) * (room - reach) / maxf(1.0, count - 1))
		if above >= 0:
			start = maxi(start, maxi(starts[above], ends[above] - reach + 1))
		start = clampi(start, 0, room - reach)
		starts.append(start)
		ends.append(start + reach - 1)
		if reach < room:
			above = row
	starts[0] = 0
	for row in range(1, count):
		starts[row] = mini(starts[row], ends[row - 1] + 1)
	ends[count - 1] = room - 1
	for row in count:
		(from[row] as Waypoint).next = to.slice(starts[row], ends[row] + 1)


# The nodes open after `previous` (the area last taken): where its paths
# lead, or the whole first layer at the start.
func open_after(previous: Waypoint) -> Array:
	return nodes(0) if previous == null else previous.next


static func roll_reward(area: AreaData, rng: RandomNumberGenerator) -> AreaData.Reward:
	var total := 0.0
	for reward: int in area.reward_weights:
		total += float(area.reward_weights[reward])
	var roll := rng.randf() * total
	for reward: int in area.reward_weights:
		roll -= float(area.reward_weights[reward])
		if roll <= 0.0:
			return reward as AreaData.Reward
	return AreaData.Reward.BOON


func size() -> int:
	return layers.size()


func nodes(layer: int) -> Array:
	return layers[layer] if layer >= 0 and layer < layers.size() else []
