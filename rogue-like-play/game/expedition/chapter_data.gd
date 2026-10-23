class_name ChapterData
extends Resource

# A chapter of a run: how many layers of choices lead to its boss, how many
# areas each layer offers, and the areas they are drawn from. The first
# layer offers only fields, so a run opens on the crowd. A later chapter is
# sealed until the one it is unlocked_by has been cleared once (Chapters).

@export var id: StringName
@export var display_name := "第1章"
# The base's departure shows these.
@export_multiline var description := ""
@export var illustration: Texture2D
@export_range(1, 10) var layers := 3
# Areas offered per layer, picked between these (inclusive).
@export var choices := Vector2i(2, 3)
@export var areas: Array[AreaData] = []
# Stops without a fight: from the second layer on, a layer offers one of
# them among its choices this often.
@export var events: Array[AreaData] = []
@export_range(0.0, 1.0) var event_chance := 0.5
@export var boss: AreaData
# The chapter whose first clear opens this one; empty: open from the start.
@export var unlocked_by: StringName
