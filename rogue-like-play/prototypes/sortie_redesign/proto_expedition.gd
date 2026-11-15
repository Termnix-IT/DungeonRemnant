class_name ProtoExpedition
extends RefCounted

# The departure for the three redesign prototypes: the game's own chapters
# (Chapters.ALL), its own rules for which are open and which difficulty
# steps are (MetaProgress.chapter_open and steps_open), on a MetaProgress of
# its own that is never saved. What each prototype tells of a chapter (how
# far it has been taken, its way, its boss, the foes that come in it, what
# she carries, the step and what it adds, the action's words) is worked out
# here once, the same way the shipped page does, so the three differ only in
# how they show it.

const UNKNOWN := "？？？"

var meta: MetaProgress
# The difficulty step chosen to set out at.
var step := 0
# The chapter set out for last (its place in Chapters.ALL), or -1.
var departed := -1


func _init() -> void:
	reset()


# A game part of the way through (the first chapter cleared, the second
# entered, the rest sealed), or with `ended` one past its ending, where
# every chapter is open and four difficulty steps are.
func reset(ended := false) -> void:
	meta = MetaProgress.new()
	meta.echo = 240
	meta.loadout = [&"slam", &"thunder_flash"]
	meta.special = &"echo_burst"
	step = 0
	departed = -1
	var all := Chapters.ALL
	if ended:
		for chapter in all:
			meta.chapter_clears[chapter.id] = 2
			meta.chapter_best[chapter.id] = chapter.layers + 1
			for foe in Chapters.foes(chapter):
				meta.met[foe.id] = true
		meta.chapter_clears[all[0].id] = 6
		meta.chapter_steps[all[0].id] = 2
		meta.chapter_steps[all.back().id] = 3
		return
	meta.chapter_clears[all[0].id] = 2
	meta.chapter_best[all[0].id] = all[0].layers + 1
	meta.chapter_best[all[1].id] = 3
	for foe in Chapters.foes(all[0]):
		meta.met[foe.id] = true
	var second := Chapters.foes(all[1])
	for index in mini(4, second.size()):
		meta.met[second[index].id] = true


func chapter(index: int) -> ChapterData:
	return Chapters.ALL[index]


func count() -> int:
	return Chapters.ALL.size()


# The chapter the departure opens on.
func frontier() -> int:
	return Chapters.ALL.find(Chapters.frontier(meta))


func open(index: int) -> bool:
	return meta.chapter_open(chapter(index))


func cleared(index: int) -> bool:
	return meta.clears_of(chapter(index).id) > 0


# The deepest layer reached in it (the boss's: one past its layers).
func best(index: int) -> int:
	return meta.best_of(chapter(index).id)


# How far it has been taken, as a door says it: 封印中, 未踏 or its record.
func state(index: int) -> String:
	if not open(index):
		return tr("封印中")
	var told := Chapters.record(meta, chapter(index))
	return tr("未踏") if told == tr("なし") else told


# What opens a sealed chapter.
func opener(index: int) -> String:
	var key := Chapters.find(chapter(index).unlocked_by)
	return tr("%sを踏破すると開く") % (Chapters.short_name(key) if key != null else tr("前の章"))


func description(index: int) -> String:
	return tr(chapter(index).description) if open(index) else tr("封印されている。%s。") % opener(index)


func route(index: int) -> String:
	return tr("%d層とボス") % chapter(index).layers


func record(index: int) -> String:
	return Chapters.record(meta, chapter(index))


# The boss's name once met.
func boss_name(index: int) -> String:
	var hall := chapter(index).boss
	var boss := hall.boss if hall != null else null
	return tr(boss.display_name) if boss != null and meta.has_met(boss.id) else tr(UNKNOWN)


# The foes that come in it: [picture, name, met], pictured once met and a
# dark shape until then.
func foes(index: int) -> Array:
	var listed := []
	for foe in Chapters.foes(chapter(index)):
		var met := meta.has_met(foe.id)
		listed.append([HubCodex.tile_picture(foe.visual_id, met, foe.tint), tr(foe.display_name) if met else tr(UNKNOWN), met])
	return listed


# What she carries: [emblem key, name] of her weapon, skills and special move.
func gear() -> Array:
	var listed := []
	var weapon := MetaProgress.find_weapon(meta.weapon)
	if weapon != null:
		listed.append([weapon.emblem, tr(weapon.display_name)])
	for id in meta.loadout:
		var skill := MetaProgress.find_skill(id)
		if skill != null:
			listed.append([skill.emblem, tr(skill.display_name)])
	var move := MetaProgress.find_special(meta.special)
	if move != null:
		listed.append([move.emblem, tr(move.display_name)])
	return listed


# The highest difficulty step open (0: the steps are not open yet).
func steps_open() -> int:
	return meta.steps_open()


func choose_step(level: int) -> bool:
	var to := clampi(level, 0, steps_open())
	if to == step:
		return false
	step = to
	return true


# What the chosen step adds.
func step_note() -> String:
	return tr("制約なし") if step == 0 else tr(DifficultySteps.ALL[step - 1].summary)


# The echo the chosen step brings back ("残響 +30%"), or nothing at step 0.
func step_echo() -> String:
	return "" if step == 0 else DifficultySteps.echo_text(step)


# Every constraint in play at the chosen step, one to a line.
func step_lines() -> PackedStringArray:
	return DifficultySteps.constraints(step).split("\n", false)


# Why the next step is not open, at the highest one that is.
func step_hint() -> String:
	var most := steps_open()
	if step < most or most >= DifficultySteps.MAX:
		return ""
	return tr("段階%dで%sを踏破すると開く") % [most, Chapters.short_name(Chapters.ALL.back())]


# The action's words: "第1章へ出撃する（段階3）" or "第2章は封印中".
func action(index: int) -> String:
	var name := Chapters.short_name(chapter(index))
	if not open(index):
		return tr("%sは封印中") % name
	return tr("%sへ出撃する") % name + (tr("（段階%d）") % step if step > 0 else "")


# Sets out for a chapter; a sealed one is refused.
func set_out(index: int) -> bool:
	if not open(index):
		return false
	departed = index
	return true
