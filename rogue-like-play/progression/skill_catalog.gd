class_name SkillCatalog
extends RefCounted

const NODES: Array[SkillNode] = [preload("res://data/upgrades/vitality.tres"), preload("res://data/upgrades/attack.tres"), preload("res://data/upgrades/defense.tres"), preload("res://data/upgrades/mana.tres")]

static func find(id: StringName) -> SkillNode:
	for node in NODES:
		if node.id == id:
			return node
	return null
