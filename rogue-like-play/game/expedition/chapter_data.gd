class_name ChapterData
extends Resource

# A chapter of a run: how many layers of choices lead to its boss, how many
# areas each layer offers, and the areas they are drawn from. The first
# layer offers only fields, so a run opens on the crowd.

@export var id: StringName
@export var display_name := "第1章"
# The base's departure shows these.
@export_multiline var description := ""
@export var illustration: Texture2D
@export_range(1, 10) var layers := 3
# Areas offered per layer, picked between these (inclusive).
@export var choices := Vector2i(2, 3)
@export var areas: Array[AreaData] = []
@export var boss: AreaData
