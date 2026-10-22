class_name SpecialData
extends Resource

# A special move the hero can set in the special slot (on R / LB) from the
# status page, once learned on the upgrade tree's special branch: its name
# and emblem for the screens, the attack it lets loose, and how much of the
# gauge it takes. The gauge fills from the fight (HeroTuning's special_per_*)
# and carries from area to area within a run; a full gauge lets it loose,
# staged with a cut-in, and the hero is untouchable while it plays.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
# Its medallion (EmblemIcons key).
@export var emblem := ""
@export var attack: AttackData
# The gauge it needs, full.
@export_range(10.0, 1000.0) var charge := 100.0
