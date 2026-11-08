class_name MetaUpgrade
extends Resource

# A lasting upgrade bought at the base with echo, kept from run to run: one
# node of the upgrade tree. Its effect (per_rank per rank) is one of the
# hero's figures applied to her tuning at a run's start (max_hp, defense,
# hurt_mercy, dash_charges, dash_cooldown, move_speed), a rule a run reads
# from RunState.lasting (echo_rate, last_stand, heal_share, gem_pull,
# start_boon, exp_rate, reroll, offer_count, level_heal, level_burst,
# level_ward, level_haste, skill_cooldown, special_charge, special_power),
# or a skill, special move or weapon learned (skill_unlock, special_unlock,
# weapon_unlock: its `grants`). Favouring new ways to fight over bigger numbers.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
# The price of each rank in turn; its length is the number of ranks.
@export var costs: Array[int] = []
@export var effect: StringName
@export var per_rank := 1.0
# Its medallion (EmblemIcons key).
@export var emblem := ""
# Where it grows in the tree: its branch (&"body", &"growth", &"skill",
# &"special", &"weapon"), the upgrade
# it grows from (empty for the root) and its cell, columns right and rows
# down from the root.
@export var branch: StringName
@export var parent: StringName
@export var cell := Vector2i.ZERO
# A skill_unlock's skill (SkillData.id), a special_unlock's special move
# (SpecialData.id) or a weapon_unlock's weapon (Moveset.id): held from its
# first rank on.
@export var grants: StringName
# The figure the upgrades page tells: `figure` holding the value at a rank,
# (figure_base + per_rank * rank) * figure_scale. Empty: the description only.
@export var figure := ""
@export var figure_base := 0.0
@export var figure_scale := 1.0
# How finely the figure's numbers are told: 0.1 for a reach in cells (a
# distance's pixels times 1 / AreaGround.CELL), where finer would be noise.
@export var figure_snap := 0.01


func max_rank() -> int:
	return costs.size()


# The price of the next rank from `rank`, or -1 when it is full.
func price(rank: int) -> int:
	return costs[rank] if rank >= 0 and rank < costs.size() else -1


# The figure's number at `rank` ("130").
func figure_value(rank: int) -> String:
	return _number((figure_base + per_rank * rank) * figure_scale)


# What one rank adds to the figure, signed and with the figure's unit
# ("+15", "-0.05秒", "+10%"). A figure that carries its own sign ("受けるダメージ
# -%s") keeps that sign for the gain.
func figure_gain() -> String:
	var at := figure.find("%s")
	if at < 0:
		return ""
	var step := per_rank * figure_scale
	var mark := figure[at - 1] if at > 0 and figure[at - 1] in ["+", "-"] else ("+" if step >= 0.0 else "-")
	return mark + _number(absf(step)) + figure.substr(at + 2).replace("%%", "%")


# The figure as the page tells it at `rank`, with what the next rank adds
# beside it: what the first rank gives ("習得すると　最大HP 115（+15）"; the gain
# left off when the figure starts from nothing, where it would only repeat
# the number), the rank held and the next ("最大HP 115 → 130（+15）"), or the
# last rank's alone.
func figure_line(rank: int) -> String:
	if figure.is_empty():
		return ""
	if rank <= 0:
		var first := "習得すると　" + figure % figure_value(1)
		return first if is_zero_approx(figure_base * figure_scale) else "%s（%s）" % [first, figure_gain()]
	if rank >= max_rank():
		return figure % figure_value(rank)
	return "%s（%s）" % [figure % ("%s → %s" % [figure_value(rank), figure_value(rank + 1)]), figure_gain()]


# Whether the description only says again what the figure line tells: it
# names no number but the figure's own (its value at the ranks shown, or a
# rank's gain). Such a description is left off the page; one that tells
# what the upgrade does beyond its number ("光の衝撃") stays.
func description_restates_figure(rank: int) -> bool:
	if figure.is_empty():
		return false
	var told := [_number(absf(per_rank * figure_scale)), figure_value(maxi(rank, 1))]
	if rank < max_rank():
		told.append(figure_value(rank + 1))
	var numbers := RegEx.create_from_string("\\d+(?:\\.\\d+)?").search_all(description)
	if numbers.is_empty():
		return false
	for found in numbers:
		if not found.get_string() in told:
			return false
	return true


func _number(raw: float) -> String:
	var value := snappedf(raw, figure_snap)
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else str(value)
