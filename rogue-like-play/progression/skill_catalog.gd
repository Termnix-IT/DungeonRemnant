class_name SkillCatalog
extends RefCounted

# The permanent tree: base HP (RunCarryover.upgrade) at its centre, and four
# branches wired out of it, each a chain of tiers. A tier opens when the one
# before it (or base HP, for a branch's first tier) reaches its cap. A
# branch's tiers continue one price sequence, so splitting the old single
# nodes into tiers changed neither their costs nor their total bonus.
const BRANCHES: Array = [
	[preload("res://data/upgrades/vitality.tres"), preload("res://data/upgrades/vitality_2.tres"), preload("res://data/upgrades/vitality_3.tres"), preload("res://data/upgrades/vitality_4.tres")],
	[preload("res://data/upgrades/attack.tres"), preload("res://data/upgrades/attack_2.tres"), preload("res://data/upgrades/attack_3.tres"), preload("res://data/upgrades/attack_4.tres")],
	[preload("res://data/upgrades/mana.tres"), preload("res://data/upgrades/mana_2.tres"), preload("res://data/upgrades/mana_3.tres")],
	[preload("res://data/upgrades/defense.tres"), preload("res://data/upgrades/defense_2.tres"), preload("res://data/upgrades/defense_3.tres")],
]
static var NODES: Array[SkillNode] = _flatten()


static func _flatten() -> Array[SkillNode]:
	var nodes: Array[SkillNode] = []
	for branch: Array in BRANCHES:
		for node: SkillNode in branch:
			nodes.append(node)
	return nodes


static func find(id: StringName) -> SkillNode:
	for node in NODES:
		if node.id == id:
			return node
	return null


# The nodes that open once this one is capped.
static func children(id: StringName) -> Array[SkillNode]:
	var found: Array[SkillNode] = []
	for node in NODES:
		if node.prerequisite == id:
			found.append(node)
	return found


# Saves before version 4 held each branch as one node of the first tier's id
# (vitality up to 20, ...). Spreads such a rank over the branch's tiers in
# order; nothing is gained or lost. Returns {} for an unknown id or a rank
# beyond the branch.
static func spread_legacy(id: StringName, rank: int) -> Dictionary:
	for branch: Array in BRANCHES:
		if branch[0].id != id:
			continue
		var levels := {}
		var left := rank
		for node: SkillNode in branch:
			var filled := mini(left, node.max_rank)
			if filled > 0:
				levels[String(node.id)] = filled
			left -= filled
		return levels if left == 0 else {}
	return {}
