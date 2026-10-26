class_name DifficultySteps
extends RefCounted

# The difficulty steps, laid one on another as roguelites commonly ladder
# them (Slay the Spire's ascension): step n plays with the constraints of
# steps 1 to n, and brings back the echo all of them add. Step 0 is the game
# as it is. The first clear of the last chapter opens step 1; clearing it at
# the highest step open opens the next (MetaProgress.steps_open).

const ALL: Array[DifficultyStep] = [
	preload("res://data/steps/step_1.tres"),
	preload("res://data/steps/step_2.tres"),
	preload("res://data/steps/step_3.tres"),
	preload("res://data/steps/step_4.tres"),
	preload("res://data/steps/step_5.tres"),
	preload("res://data/steps/step_6.tres"),
	preload("res://data/steps/step_7.tres"),
	preload("res://data/steps/step_8.tres"),
]
const MAX := 8


# Steps 1 to `level` folded into one: shares multiplied, counts and echo
# added, a curse or kin taken from any step that brings them. Level 0 (or
# below) changes nothing.
static func combined(level: int) -> DifficultyStep:
	var total := DifficultyStep.new()
	total.echo = 0.0
	for index in clampi(level, 0, ALL.size()):
		var step := ALL[index]
		total.echo += step.echo
		total.crowd *= step.crowd
		total.heal *= step.heal
		total.elite_pace *= step.elite_pace
		total.elite_cap += step.elite_cap
		total.offers += step.offers
		total.foe_hp *= step.foe_hp
		total.curse = total.curse or step.curse
		total.kin = maxf(total.kin, step.kin)
		total.boss_rage += step.boss_rage
		total.boss_summons *= step.boss_summons
	return total


# Every constraint in play at `level`, one to a line, for a tooltip.
static func constraints(level: int) -> String:
	var lines: Array[String] = []
	for index in clampi(level, 0, ALL.size()):
		lines.append("段階%d　%s" % [index + 1, ALL[index].summary])
	return "\n".join(lines)


# The echo a level adds, as the departure tells it ("残響 +30%").
static func echo_text(level: int) -> String:
	return "残響 +%d%%" % roundi(combined(level).echo * 100.0)
