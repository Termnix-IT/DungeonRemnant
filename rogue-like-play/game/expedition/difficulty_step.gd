class_name DifficultyStep
extends Resource

# One step of difficulty: the one constraint it adds to those of the steps
# below it, and the echo it adds as their reward (DifficultySteps). Every
# field left at its default changes nothing, so a step sets only its own.
# DifficultySteps.combined() folds the steps up to one into a single
# DifficultyStep that a run reads.

# What the step adds, in one line for the departure ("精鋭が早く多く出る").
@export var summary := ""
# Echo rewards rise by this share of themselves.
@export_range(0.0, 1.0) var echo := 0.1
# Fields bring their crowds this much faster and larger; waves this much larger.
@export_range(0.5, 4.0) var crowd := 1.0
# A heal reward restores this share of what it would.
@export_range(0.0, 1.0) var heal := 1.0
# Elites come first, and come again, after this share of their time.
@export_range(0.1, 1.0) var elite_pace := 1.0
# More elites may be alive at once.
@export_range(0, 10) var elite_cap := 0
# Cards a level-up offers, added (a negative takes cards away).
@export_range(-3, 3) var offers := 0
# Foes (bosses too) come in with this much of their health.
@export_range(0.5, 4.0) var foe_hp := 1.0
# She sets out carrying one curse, drawn from those of RunState.CURSES.
@export var curse := false
# This share of a field's crowd is the chapter's stronger kin (ChapterData.kin).
@export_range(0.0, 1.0) var kin := 0.0
# A boss enrages this much sooner (added to FoeData.phase_two_at, when it has
# a second phase), and calls this many times the help it calls then.
@export_range(0.0, 0.5) var boss_rage := 0.0
@export_range(1.0, 4.0) var boss_summons := 1.0
