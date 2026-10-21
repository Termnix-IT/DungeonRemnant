class_name MetaUpgrade
extends Resource

# A lasting upgrade bought at the base with echo, kept from run to run. Its
# effect is one of: max_hp (her health, per_rank per rank), dash_charges
# (dashes in a row, per_rank per rank), start_boon (a run opens with a boon
# chosen from three). Favouring new ways to fight over bigger numbers.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
# The price of each rank in turn; its length is the number of ranks.
@export var costs: Array[int] = []
@export var effect: StringName
@export var per_rank := 1.0
# Its medallion (EmblemIcons key).
@export var emblem := ""


func max_rank() -> int:
	return costs.size()


# The price of the next rank from `rank`, or -1 when it is full.
func price(rank: int) -> int:
	return costs[rank] if rank >= 0 and rank < costs.size() else -1
