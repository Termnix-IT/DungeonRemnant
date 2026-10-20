class_name EnemySprites
extends RefCounted

# Which illustration rig draws an enemy (art/enemies/rig/<visual id>_rig.tscn),
# a picture of it for screens that name it, and the cues the battle
# presentation holds on an enemy: its wind-up, strike and hurt, which the rig
# plays as its attack, flinch and fall (Enemy.pose_frame).
const RIG_DIRECTORY := "res://art/enemies/rig/"
const FRAME_WIND_UP := 4
const FRAME_STRIKE := 5
const FRAME_HURT := 6
const FRAME_DOWN := 7
const BOSS_IDS := {
	"石門の守護者": "boss_stone_gate",
	"疾風の番人": "boss_gale_warden",
	"魔砲の監視者": "boss_cannon_watcher",
	"召喚の司祭": "boss_summoning_priest",
	"遺跡王": "boss_ruin_king",
	"根の番人": "boss_root_warden",
	"疾風の狼王": "boss_gale_wolf_king",
	"胞子の砲台": "boss_spore_cannon",
	"群れの主": "boss_swarm_lord",
	"古樹の王": "boss_ancient_tree_king",
}

static var _portraits: Dictionary = {}


static func visual_id(stats: EnemyStats) -> String:
	if stats.is_boss:
		var named: String = BOSS_IDS.get(stats.display_name, "")
		return named if not named.is_empty() and ResourceLoader.exists(rig_path(named)) else "boss"
	if stats.behavior == EnemyStats.Behavior.SUMMONER:
		return "summoner"
	if stats.behavior == EnemyStats.Behavior.FAST:
		return "fast"
	if stats.behavior == EnemyStats.Behavior.CHARGER:
		return "charge"
	if stats.detection == EnemyStats.Detection.TURRET:
		return "turret"
	if stats.detection == EnemyStats.Detection.PROXIMITY:
		return "proximity"
	return "basic"


static func rig_path(id: String) -> String:
	return RIG_DIRECTORY + id + "_rig.tscn"


# The enemy's whole picture for a portrait: {"texture", "region"} (the
# atlas and the rectangle of its body), read once from the rig's body mesh.
# An enemy drawn in parts (the sentinel) has a picture of its own instead,
# <id>_portrait.png beside its rig; without either it is empty.
static func portrait(stats: EnemyStats) -> Dictionary:
	if stats == null:
		return {}
	var id := visual_id(stats)
	if not _portraits.has(id):
		var found := {}
		if ResourceLoader.exists(rig_path(id)):
			var rig: Node = (load(rig_path(id)) as PackedScene).instantiate()
			var body := rig.get_node_or_null(^"Parts/Body") as Polygon2D
			if body != null and body.texture != null:
				var region := Rect2(body.uv[0], Vector2.ZERO)
				for point in body.uv:
					region = region.expand(point)
				found = {"texture": body.texture, "region": region}
			rig.free()
		var own := RIG_DIRECTORY + id + "_portrait.png"
		if found.is_empty() and ResourceLoader.exists(own):
			var picture: Texture2D = load(own)
			found = {"texture": picture, "region": Rect2(Vector2.ZERO, picture.get_size())}
		_portraits[id] = found
	return _portraits[id]
