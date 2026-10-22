class_name MetaUpgrade
extends Resource

# A lasting upgrade bought at the base with echo, kept from run to run: one
# node of the upgrade tree. Its effect (per_rank per rank) is one of the
# hero's figures applied to her tuning at a run's start (max_hp, defense,
# hurt_mercy, dash_charges, dash_cooldown, move_speed), or a rule a run
# reads from RunState.lasting (echo_rate, last_stand, heal_share, gem_pull,
# start_boon, exp_rate, reroll, offer_count, level_heal, level_burst,
# level_ward, level_haste). Favouring new ways to fight over bigger numbers.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
# The price of each rank in turn; its length is the number of ranks.
@export var costs: Array[int] = []
@export var effect: StringName
@export var per_rank := 1.0
# Its medallion (EmblemIcons key).
@export var emblem := ""
# Where it grows in the tree: its branch (&"body", &"growth"), the upgrade
# it grows from (empty for the root) and its cell, columns right and rows
# down from the root.
@export var branch: StringName
@export var parent: StringName
@export var cell := Vector2i.ZERO
# The figure the upgrades page tells: `figure` holding the value at a rank,
# (figure_base + per_rank * rank) * figure_scale. Empty: the description only.
@export var figure := ""
@export var figure_base := 0.0
@export var figure_scale := 1.0


func max_rank() -> int:
	return costs.size()


# The price of the next rank from `rank`, or -1 when it is full.
func price(rank: int) -> int:
	return costs[rank] if rank >= 0 and rank < costs.size() else -1


# The figure's number at `rank` ("130").
func figure_value(rank: int) -> String:
	var value := snappedf((figure_base + per_rank * rank) * figure_scale, 0.01)
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else str(value)


# The figure as the page tells it at `rank`: what the first rank gives, the
# rank held and the next ("最大HP 115 → 130"), or the last rank's alone.
func figure_line(rank: int) -> String:
	if figure.is_empty():
		return ""
	if rank <= 0:
		return "習得すると　" + figure % figure_value(1)
	if rank >= max_rank():
		return figure % figure_value(rank)
	return figure % ("%s → %s" % [figure_value(rank), figure_value(rank + 1)])
