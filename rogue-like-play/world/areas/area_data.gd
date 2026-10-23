class_name AreaData
extends Resource

# One battlefield a run can enter: what the route map tells of it, the
# ground it is fought on, and how it is cleared. An open field sends a
# growing crowd (spawn_table) until the hero has lasted survive_time or felled
# kill_target; an arena sends its waves one after another; a boss hall sends
# its boss (and any waves beside it) and is won when the boss falls.
# reward_weights decide which reward a node of it offers, so the kind of
# area leans the reward without fixing it. An event is a stop without a
# fight (`event` names what happens there: RunDirector plays it).

enum Kind { FIELD, ARENA, BOSS, EVENT }
enum Reward { BOON, HEAL, ECHO }

const KIND_NAMES := {Kind.FIELD: "フィールド", Kind.ARENA: "アリーナ", Kind.BOSS: "ボス", Kind.EVENT: "イベント"}
const REWARD_NAMES := {Reward.BOON: "強化", Reward.HEAL: "回復", Reward.ECHO: "残響"}

@export var id: StringName
@export var display_name := "エリア"
@export var kind: Kind = Kind.FIELD
# 1 to 3, shown as stars.
@export_range(1, 3) var difficulty := 1
# What the map says of it beyond its kind: its special conditions, and the
# foes it sends. One line each on the map's card: about 17 characters.
@export var condition := ""
@export var foe_summary := ""
# Seconds a player is expected to spend in it, for the map.
@export_range(10, 1200) var expected_time := 150
# Reward (Reward) -> weight.
@export var reward_weights: Dictionary = {Reward.BOON: 1.0, Reward.HEAL: 1.0, Reward.ECHO: 1.0}
# Echo given when an ECHO reward is taken.
@export_range(0, 10000) var echo := 40

@export_group("Event")
# What happens at an event: merchant, altar or curse (RunDirector). Its
# node on the map shows `emblem` instead of a reward.
@export var event: StringName
@export var emblem := ""

@export_group("Ground")
@export var size := Vector2i(40, 28)
# AreaGround's painted terrain: 0 slate, 1 moss, 2 ember, 3 sanctum, 4 grove.
@export_range(0, 4) var theme := 0
# The top-left cells of 2x2 pillars.
@export var pillars: Array[Vector2i] = []
# Extra 2x2 pillars strewn over the ground, placed the same way every time.
@export_range(0, 200) var scattered_pillars := 0
# Each pillar stands as a tree (a forest's), drawn among the fighters.
@export var trees := false

@export_group("Clearing")
@export var spawn_table: SpawnTable
@export_range(0.0, 3600.0) var survive_time := 0.0
@export_range(0, 10000) var kill_target := 0
@export var waves: Array[WaveData] = []
# A boss hall's boss, which comes in BOSS_DELAY after she enters.
@export var boss: FoeData


func kind_name() -> String:
	return KIND_NAMES[kind]


static func reward_name(reward: Reward) -> String:
	return REWARD_NAMES[reward]


func is_event() -> bool:
	return kind == Kind.EVENT


func stars() -> String:
	if is_event():
		return ""
	return "★".repeat(difficulty) + "☆".repeat(3 - difficulty)


# The wall cells of its ground: the border, its pillars, and the strewn
# ones (from a generator seeded by its id, so the same area is always laid
# out alike; kept clear of the middle, where the hero starts).
func walls() -> Dictionary:
	var cells := {}
	for x in size.x:
		cells[Vector2i(x, 0)] = true
		cells[Vector2i(x, size.y - 1)] = true
	for y in size.y:
		cells[Vector2i(0, y)] = true
		cells[Vector2i(size.x - 1, y)] = true
	for corner: Vector2i in pillar_corners():
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			cells[corner + offset] = true
	return cells


# The top-left cells of its 2x2 pillars: the placed ones, then the strewn
# ones (from a generator seeded by its id, kept clear of the middle).
func pillar_corners() -> Array[Vector2i]:
	var corners: Array[Vector2i] = pillars.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(id))
	var middle := Rect2i(size / 2 - Vector2i(5, 4), Vector2i(10, 8))
	for index in scattered_pillars:
		var corner := Vector2i(rng.randi_range(3, size.x - 5), rng.randi_range(3, size.y - 5))
		if not middle.has_point(corner):
			corners.append(corner)
	return corners
