class_name ChapterData
extends Resource

# A chapter of a run: how many layers of choices lead to its boss, how many
# areas each layer offers, and the areas they are drawn from. The first
# layer offers only fields, so a run opens on the crowd, and every one of
# them is open; past it, only the areas the last one's paths lead to are
# (AreaData.branches). A later chapter is sealed until the one it is
# unlocked_by has been cleared once (Chapters).

@export var id: StringName
@export var display_name := "第1章"
# The base's departure shows these.
@export_multiline var description := ""
@export var illustration: Texture2D
@export_range(1, 10) var layers := 3
# Areas the first layer offers, all open from the start.
@export_range(1, 3) var first_choices := 3
# Areas offered per later layer, picked between these (inclusive).
@export var choices := Vector2i(2, 3)
@export var areas: Array[AreaData] = []
# Stops without a fight: from the second layer on, a layer offers one of
# them among its choices this often.
@export var events: Array[AreaData] = []
@export_range(0.0, 1.0) var event_chance := 0.5
@export var boss: AreaData
# Stronger kin of its crowd's foes (their colour, tougher), mixed into its
# fields from the difficulty step that calls for them (DifficultyStep.kin).
@export var kin: Array[FoeData] = []
# The chapter whose first clear opens this one; empty: open from the start.
@export var unlocked_by: StringName
