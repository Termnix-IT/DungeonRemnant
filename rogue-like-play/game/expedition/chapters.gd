class_name Chapters
extends RefCounted

# Every chapter, in the order the base offers them; the first is open from
# the start and each later one opens once its unlocked_by is cleared.

const ALL: Array[ChapterData] = [
	preload("res://data/chapters/ash_corridor.tres"),
	preload("res://data/chapters/gale_woods.tres"),
]


static func find(id: StringName) -> ChapterData:
	for chapter in ALL:
		if chapter.id == id:
			return chapter
	return null


# The chapter's short name ("第1章").
static func short_name(chapter: ChapterData) -> String:
	return chapter.display_name.get_slice("　", 0)


# The chapter's name without its number ("灰の回廊").
static func title(chapter: ChapterData) -> String:
	var name := chapter.display_name.get_slice("　", 1)
	return name if not name.is_empty() else chapter.display_name


# The chapter the base offers first: the first open one not cleared yet, or
# the last open one once every open one has been cleared.
static func frontier(meta: MetaProgress) -> ChapterData:
	var last := ALL[0]
	for chapter in ALL:
		if not meta.chapter_open(chapter):
			continue
		if meta.clears_of(chapter.id) == 0:
			return chapter
		last = chapter
	return last


# How far the chapter has been taken: how often it was cleared (and the
# highest difficulty step it was cleared at), else the deepest layer reached
# (the boss's, past the last layer), else nothing.
static func record(meta: MetaProgress, chapter: ChapterData) -> String:
	var clears := meta.clears_of(chapter.id)
	if clears > 0:
		var step := meta.step_of(chapter.id)
		return "踏破 %d回" % clears if step == 0 else "踏破 %d回・段階%d" % [clears, step]
	var best := meta.best_of(chapter.id)
	if best == 0:
		return "なし"
	return "ボスまで" if best > chapter.layers else "第%d層まで" % best


# Every foe that can come in the chapter, in the encyclopedia's order: its
# areas' crowds, elites and waves, its boss, and those they call.
static func foes(chapter: ChapterData) -> Array[FoeData]:
	var found := {}
	var halls: Array[AreaData] = chapter.areas.duplicate()
	if chapter.boss != null:
		halls.append(chapter.boss)
	for area in halls:
		if area.spawn_table != null:
			for entry in area.spawn_table.entries:
				found[entry.foe] = true
			if area.spawn_table.elite != null:
				found[area.spawn_table.elite] = true
		for wave in area.waves:
			for foe in wave.foes:
				found[foe] = true
		if area.boss != null:
			found[area.boss] = true
	for foe: FoeData in found.keys():
		if foe != null and foe.summon != null:
			found[foe.summon] = true
	var listed: Array[FoeData] = []
	for foe in FoeCatalog.FOES:
		if found.has(foe):
			listed.append(foe)
	return listed
