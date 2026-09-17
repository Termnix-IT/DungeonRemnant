class_name StageData
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(1, 100) var floor_count: int = 10
@export var difficulty: String = "標準"
@export_multiline var features: String
@export_multiline var enemy_summary: String
@export var settings: DungeonSettings
@export var illustration: Texture2D
@export var available := true
