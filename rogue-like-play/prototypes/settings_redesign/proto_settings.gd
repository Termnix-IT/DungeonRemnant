class_name ProtoSettings
extends RefCounted

# The settings for the three redesign prototypes: the game's own ten rows
# (HubSettings.CAPTIONS and NOTES, grouped as its TABS) on a GameSettings of
# its own that is never saved and never applied (no bus is turned, no window
# changed, no language switched). What each prototype shows of a row (what
# kind of control it is, its value, its choices, what it does) is worked out
# here once, so the three differ only in how they show it. The help window
# and the question before ending the game are not rebuilt: taking those
# rows' actions is only noted.

# Every row in the order the groups list them.
const ORDER: Array[int] = [0, 1, 2, 3, 4, 5, 9, 6, 7, 8]
const SLIDERS: Array[int] = [0, 1, 2, 3]
const ACTIONS: Array[int] = [7, 8]
const HELP := 7
const QUIT := 8
const LANGUAGE := 9
const ACTION_WORDS := {7: "開く", 8: "終了する"}

var settings: GameSettings
# The action taken last (&"help" or &"quit"), or none.
var acted: StringName = &""


func _init() -> void:
	reset()


func reset() -> void:
	settings = GameSettings.new()
	settings.language = "ja"
	acted = &""


static func groups() -> int:
	return HubSettings.TABS.size()


static func group_name(group: int) -> String:
	return TranslationServer.translate(HubSettings.TABS[group][0])


# A group's rows in order.
static func rows(group: int) -> Array[int]:
	var listed: Array[int] = []
	listed.assign(HubSettings.TABS[group][1])
	return listed


static func group_of(row: int) -> int:
	for group in HubSettings.TABS.size():
		if (HubSettings.TABS[group][1] as Array).has(row):
			return group
	return 0


# &"slider" (a volume), &"cycle" (one of a few choices) or &"action".
static func kind(row: int) -> StringName:
	if SLIDERS.has(row):
		return &"slider"
	return &"action" if ACTIONS.has(row) else &"cycle"


static func caption(row: int) -> String:
	return TranslationServer.translate(HubSettings.CAPTIONS[row])


static func note(row: int) -> String:
	return TranslationServer.translate(HubSettings.NOTES[row])


# A volume from 0 to 100.
func percent(row: int) -> int:
	return settings.volume_percent([settings.volume, settings.music_volume, settings.effects_volume, settings.ambience_volume][row])


# A cycle's choices, as the game names them.
func choices(row: int) -> Array[String]:
	var names: Array[String] = []
	match row:
		4:
			names.assign(GameSettings.SHAKE_NAMES.map(func(name: String) -> String: return tr(name)))
		5:
			names.assign(GameSettings.DISPLAY_NAMES.map(func(name: String) -> String: return tr(name)))
		6:
			names.assign(GameSettings.CONTROLS_NAMES)
		LANGUAGE:
			names.assign(GameSettings.LANGUAGE_NAMES)
	return names


# Which of a cycle's choices is set.
func chosen(row: int) -> int:
	match row:
		4:
			return settings.shake_level
		5:
			return 1 if settings.fullscreen else 0
		6:
			return 0 if settings.show_controls else 1
		LANGUAGE:
			return GameSettings.LANGUAGES.find(settings.shown_language())
	return 0


# The row's value as words: "80%", "標準", "開く".
func value(row: int) -> String:
	match kind(row):
		&"slider":
			return "%d%%" % percent(row)
		&"cycle":
			return choices(row)[chosen(row)]
	return tr(ACTION_WORDS[row])


# Sets a volume (0 to 100, in steps of 5) or a cycle's choice; false when
# nothing changed.
func put(row: int, to: int) -> bool:
	if kind(row) == &"slider":
		var level := clampi(roundi(to / 5.0) * 5, 0, 100)
		if level == percent(row):
			return false
		match row:
			0:
				settings.volume = level / 100.0
			1:
				settings.music_volume = level / 100.0
			2:
				settings.effects_volume = level / 100.0
			3:
				settings.ambience_volume = level / 100.0
		return true
	if kind(row) != &"cycle":
		return false
	var count := choices(row).size()
	var choice := clampi(to, 0, count - 1)
	if choice == chosen(row):
		return false
	match row:
		4:
			settings.shake_level = choice
		5:
			settings.fullscreen = choice == 1
		6:
			settings.show_controls = choice == 0
		LANGUAGE:
			settings.language = GameSettings.LANGUAGES[choice]
	return true


# A step up or down: 5% of a volume, the next or the last choice of a cycle
# (round again past its ends, but for the language, which stops at them).
func change(row: int, by: int) -> bool:
	match kind(row):
		&"slider":
			return put(row, percent(row) + by * 5)
		&"cycle":
			var count := choices(row).size()
			var to := chosen(row) + by
			return put(row, clampi(to, 0, count - 1) if row == LANGUAGE else posmod(to, count))
	return false


# Takes an action's row: the help opens, or the game asks before it ends.
func act(row: int) -> bool:
	if kind(row) != &"action":
		return false
	acted = &"help" if row == HELP else &"quit"
	return true
