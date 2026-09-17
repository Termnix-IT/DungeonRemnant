class_name EnemyStats
extends ActorStats

enum Detection { VISION, PROXIMITY, TURRET }
enum Behavior { NORMAL, FAST, SUMMONER, CHARGER }

@export var behavior: Behavior = Behavior.NORMAL
@export_range(1, 3) var move_steps: int = 1
@export_range(1, 50) var summon_interval: int = 6
@export_range(1, 12) var summon_cap: int = 6
@export var elite: bool = false

@export var detection: Detection = Detection.VISION
@export var display_name := "敵"
@export var is_boss := false
@export_range(1, 20) var detection_range: int = 6
@export_range(1, 12) var attack_range: int = 1
@export_range(0, 10000) var exp_reward: int = 10
@export_range(0, 10000) var gold_reward: int = 10
