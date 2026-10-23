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
