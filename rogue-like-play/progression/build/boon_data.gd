class_name BoonData
extends Resource

# A run-only power the hero takes at a level-up: its name and words, the
# families it belongs to, how many ranks it has, how often it is offered,
# what it needs first, and what it does (its BoonEffect list). Kept by the
# run's BuildState, which drops them all when the run ends.

@export var id: StringName
@export var display_name: String
# "{rank}" in it reads as the rank being offered. At most about 20
# characters: the level-up card has two lines for it.
@export_multiline var description: String
# The families it builds into (連撃, 範囲, 回避, 属性, 状態異常, スキル); a
# build mixes them freely. Two at most, to fit the card's top line.
@export var families: Array[String] = []
# Named as AbilityData's, so the level-up card shows either.
@export_range(1, 10) var max_level := 3
# How often it is offered against the others.
@export_range(0.0, 100.0) var weight := 1.0
# Offered only once one of these is held; empty: always.
@export var requires: Array[StringName] = []
# Its medallion (EmblemIcons key).
@export var emblem := ""
@export var effects: Array[BoonEffect] = []


func effect_description(rank: int = 1) -> String:
	return description.format({"rank": rank})


func families_text() -> String:
	return "・".join(families)


func emblem_key() -> String:
	return emblem
