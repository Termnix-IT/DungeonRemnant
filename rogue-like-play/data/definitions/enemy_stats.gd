class_name EnemyStats
extends ActorStats

enum Detection { VISION, PROXIMITY, TURRET }

@export var detection: Detection = Detection.VISION
@export var display_name := "敵"
@export var is_boss := false
@export_range(1, 20) var detection_range: int = 6
@export_range(1, 12) var attack_range: int = 1
@export_range(0, 10000) var exp_reward: int = 10
@export_range(0, 10000) var gold_reward: int = 10
