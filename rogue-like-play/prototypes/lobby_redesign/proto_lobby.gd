class_name ProtoLobby
extends RefCounted

# The lobby for the three redesign prototypes: the game's own five entries
# (HubLobby.ENTRIES), what each tells (the same words and figures the
# shipped lobby works out), her lines (HubLobby.SPEECHES) and the echo held,
# on a MetaProgress and GameSettings of its own that are never saved. So the
# three differ only in how they show it. Entering an entry opens nothing
# here: it is only noted.

const RANKS := {
	"echo_lantern": 1, "sturdy_body": 2, "firm_guard": 1, "double_dash": 1, "learn_thunder_flash": 1,
	"parting_blessing": 1, "quick_study": 1, "learn_echo_burst": 1,
}

var meta: MetaProgress
var settings: GameSettings
# The chapter the departure opens on.
var chapter: ChapterData
# The entry entered last, or none; her line now, and which comes next.
var entered: StringName = &""
var line := ""
var _spoken := 0


func _init() -> void:
	reset()


# A game part of the way through: the first chapter cleared, the second
# entered, some echo held and upgrades it can buy.
func reset() -> void:
	meta = ProtoLobby.sample()
	settings = GameSettings.new()
	settings.language = "ja"
	chapter = Chapters.frontier(meta)
	entered = &""
	line = ""
	_spoken = 0


static func sample() -> MetaProgress:
	var made := MetaProgress.new()
	var all := Chapters.ALL
	made.echo = 240
	made.ranks = RANKS.duplicate()
	made.runs = 7
	made.chapter_clears[all[0].id] = 2
	made.chapter_best[all[0].id] = all[0].layers + 1
	made.chapter_best[all[1].id] = 3
	for foe in Chapters.foes(all[0]):
		made.met[foe.id] = true
	var second := Chapters.foes(all[1])
	for index in mini(4, second.size()):
		made.met[second[index].id] = true
	made.loadout = [&"slam", &"thunder_flash"]
	made.special = &"echo_burst"
	return made


func count() -> int:
	return HubLobby.ENTRIES.size()


func id(index: int) -> StringName:
	return HubLobby.ENTRIES[index][0]


# The entry's name in the menu: "出撃".
func name(index: int) -> String:
	return tr(HubLobby.ENTRIES[index][1])


# The entry's mark (a NavigationIcon kind).
func kind(index: int) -> StringName:
	return HubLobby.ENTRIES[index][2]


# What the entry is headed by: the departure, by the chapter it opens on.
func title(index: int) -> String:
	return tr(chapter.display_name) if index == 0 else name(index)


func description(index: int) -> String:
	return tr(chapter.description) if index == 0 else tr(HubLobby.DESCRIPTIONS[id(index)])


# The picture of what the entry opens: the departure, its chapter's.
func art(index: int) -> Texture2D:
	return chapter.illustration if index == 0 else HubLobby.ART[id(index)]


# The words of the action that opens it: "出撃先を選ぶ".
func action(index: int) -> String:
	return tr(HubLobby.ACTIONS[id(index)], "lobby")


# How many upgrades the echo held can buy a rank of.
func ready() -> int:
	var found := 0
	for upgrade in MetaProgress.UPGRADES:
		found += 1 if meta.can_buy(upgrade.id) else 0
	return found


# The entry's two facts, [caption, value] each, as the lobby's panel tells them.
func facts(index: int) -> Array:
	match id(index):
		&"departure":
			return [[tr("道のり"), tr("%d層とボス") % chapter.layers], [tr("記録"), Chapters.record(meta, chapter)]]
		&"upgrade":
			var ranks := 0
			for upgrade in MetaProgress.UPGRADES:
				ranks += meta.rank(upgrade.id)
			return [[tr("習得した段階"), tr("%d 段階") % ranks], [tr("強化できる"), tr("%d 件") % ready()]]
		&"status":
			var held := meta.loadout.filter(func(skill: StringName) -> bool: return not skill.is_empty()).size()
			return [[tr("装備中のスキル"), "%d / %d" % [held, MetaProgress.SKILL_SLOTS]], [tr("最大HP"), str(meta.tuning(load("res://data/hero/mio.tres")).max_hp)]]
		&"codex":
			var met := FoeCatalog.FOES.filter(func(foe: FoeData) -> bool: return meta.has_met(foe.id)).size()
			return [[tr("出会った敵"), "%d / %d" % [met, FoeCatalog.FOES.size()]], [tr("探索の回数"), tr("%d 回") % meta.runs]]
	return [[tr("音量"), "%d%%" % settings.volume_percent()], [tr("画面"), tr(GameSettings.DISPLAY_NAMES[1 if settings.fullscreen else 0])]]


# Whether the entry has something waiting: an upgrade the echo can buy.
func waiting(index: int) -> bool:
	return id(index) == &"upgrade" and ready() > 0


# She says her next line, from the set for how far the journey has come.
func talk() -> String:
	var lines := HubLobby.lines_for(meta)
	line = tr(lines[_spoken % lines.size()])
	_spoken += 1
	return line


func enter(index: int) -> void:
	entered = id(index)
