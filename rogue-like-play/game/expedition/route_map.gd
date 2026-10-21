class_name RouteMap
extends RefCounted

# A run's way through a chapter, laid out when the run begins: a list of
# layers, each a few nodes to choose between, and the boss alone at the end.
# A waypoint is an area and the reward it offers, rolled from the area's
# reward_weights. Any node of a layer leads to any node of the next.

class Waypoint:
	var area: AreaData
	var reward: AreaData.Reward
	var layer := 0

	func _init(area_data: AreaData, reward_kind: AreaData.Reward, layer_index: int) -> void:
		area = area_data
		reward = reward_kind
		layer = layer_index


var chapter: ChapterData
var layers: Array = []


static func generate(chapter_data: ChapterData, rng: RandomNumberGenerator) -> RouteMap:
	var map := RouteMap.new()
	map.chapter = chapter_data
	for index in chapter_data.layers:
		var pool: Array[AreaData] = []
		for area in chapter_data.areas:
			if index > 0 or area.kind == AreaData.Kind.FIELD:
				pool.append(area)
		var count := rng.randi_range(chapter_data.choices.x, chapter_data.choices.y)
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
		map.layers.append(nodes)
	var last: Array[Waypoint] = [Waypoint.new(chapter_data.boss, AreaData.Reward.ECHO, chapter_data.layers)]
	map.layers.append(last)
	return map


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
