class_name SkillData
extends Resource

# An active skill the hero can set in a skill slot (skill_1 on Q / Y,
# skill_2 on E / B) from the status page: its name and emblem for the
# screens, the attack it lets loose and how long it rests after. Skills
# are owned from the start (owned_from_start) or, later, learned on the
# upgrade tree's skill branch.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
# Its medallion (EmblemIcons key).
@export var emblem := ""
@export var attack: AttackData
@export_range(0.0, 120.0) var cooldown := 6.0
@export var owned_from_start := true
