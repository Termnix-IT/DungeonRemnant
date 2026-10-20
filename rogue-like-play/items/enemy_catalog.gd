class_name EnemyCatalog
extends RefCounted

# Every monster the encyclopedia lists, keyed as EnemySprites.visual_id()
# keys them (an elite shares its kind's entry): the floors' enemies, the
# nest's brood, then each stage's guardians in floor order. The unnamed
# fallback boss never appears in a stage, so it is left out.
const ENEMIES: Array[EnemyStats] = [
	preload("res://data/enemies/basic_enemy.tres"),
	preload("res://data/enemies/proximity_enemy.tres"),
	preload("res://data/enemies/fast_enemy.tres"),
	preload("res://data/enemies/turret_enemy.tres"),
	preload("res://data/enemies/summoner_enemy.tres"),
	preload("res://data/enemies/charge_enemy.tres"),
]
const STAGES: Array[StageData] = [
	preload("res://data/stages/ancient_ruins.tres"),
	preload("res://data/stages/forest.tres"),
]
const BROOD := preload("res://data/enemies/charge_enemy.tres")


# [{id, stats, boss, where}], enemies first, then the bosses.
static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stage_names: Array[String] = []
	for stage in STAGES:
		stage_names.append(stage.display_name)
	for stats in ENEMIES:
		var where := "突進の巣から生まれる" if stats == BROOD else "・".join(stage_names)
		result.append({"id": EnemySprites.visual_id(stats), "stats": stats, "boss": false, "where": where})
	for stage in STAGES:
		for index in stage.bosses.size():
			var stats := stage.bosses[index]
			result.append({"id": EnemySprites.visual_id(stats), "stats": stats, "boss": true, "where": "%s %dF" % [stage.display_name, (index + 1) * 10]})
	return result


static func has_id(id: String) -> bool:
	return entries().any(func(entry: Dictionary): return entry.id == id)


# How it fights, in a sentence or two, read from its stats.
static func traits(stats: EnemyStats) -> String:
	var lines: Array[String] = []
	match stats.detection:
		EnemyStats.Detection.PROXIMITY:
			lines.append("近くに来るまで潜んで動かず、近づくと襲ってくる。")
		EnemyStats.Detection.TURRET:
			lines.append("その場から動かず、直線上の相手を狙い、予告の次のターンに撃つ（射程 %d）。" % stats.attack_range)
	match stats.behavior:
		EnemyStats.Behavior.SUMMONER:
			lines.append("攻撃はしないが、%dターンごとに突進獣を生む。" % stats.summon_interval)
		EnemyStats.Behavior.CHARGER:
			lines.append("向きを定めて構え、まっすぐ突進してくる。")
		EnemyStats.Behavior.FAST:
			lines.append("1ターンに%d歩動いて素早く迫る。" % stats.move_steps)
	if lines.is_empty() or (stats.detection == EnemyStats.Detection.VISION and stats.behavior == EnemyStats.Behavior.NORMAL):
		lines.append("見つけた相手を追って近づき、隣から攻撃する。")
	return "\n".join(lines)
