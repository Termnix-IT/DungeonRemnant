class_name FirstLessons
extends RefCounted

# The controls, taught in the first area of a player's first run, as action
# roguelites commonly teach them: one line at a time on the HUD (the key and
# what it does), each staying until it has been done, then giving way to the
# next after a short gap. It only keeps count; the area tells it what she
# does (step, note) and shows what current() says.

# A lesson came up, was met, or the last one is over: current() has changed.
signal changed

# [id, the keys, the gamepad's buttons, what they do], in the order taught.
const LESSONS := [
	[&"move", "WASD", "左スティック", "移動"],
	[&"strike", "左クリック", "X・RT", "攻撃　続けて押すと連撃"],
	[&"dash", "Space", "A", "ダッシュ　赤い印は、これで抜ける"],
	[&"charge", "左クリック長押し", "X・RT長押し", "溜め攻撃　溜まったら離す"],
	[&"skill", "Q", "Y", "スキル"],
]
# Walking is learned after this long on the move; the attack after this
# many swings.
const MOVE_TIME := 0.8
const STRIKES := 3
# A lesson stays at least this long, so it can be read, and the next comes
# up this long after it leaves.
const MIN_SHOWN := 1.2
const GAP := 0.6

# The lesson being taught (LESSONS.size() once all are learned).
var index := 0
# Lessons left out (a skill slot left empty has nothing to teach).
var skipped: Array[StringName] = []
var _shown := 0.0
var _met := false
var _moved := 0.0
var _strikes := 0
var _gap_left := 0.0


func done() -> bool:
	return index >= LESSONS.size()


# The lesson to show now ([id, keys, buttons, words]); empty between two
# lessons and once all are learned.
func current() -> Array:
	return [] if done() or _gap_left > 0.0 else LESSONS[index]


# Leaves a lesson out (before it comes up).
func skip(id: StringName) -> void:
	skipped.append(id)
	_pass_skipped()


func step(delta: float, moving: bool) -> void:
	if done():
		return
	if _gap_left > 0.0:
		_gap_left -= delta
		if _gap_left <= 0.0:
			changed.emit()
		return
	_shown += delta
	if LESSONS[index][0] == &"move" and moving:
		_moved += delta
		_met = _met or _moved >= MOVE_TIME
	if _met and _shown >= MIN_SHOWN:
		_next()


# She did something: &"strike", &"dash", &"charge" or &"skill". It counts
# only for the lesson being shown.
func note(what: StringName) -> void:
	if done() or _gap_left > 0.0 or LESSONS[index][0] != what:
		return
	if what == &"strike":
		_strikes += 1
		if _strikes < STRIKES:
			return
	_met = true


func _next() -> void:
	index += 1
	_shown = 0.0
	_met = false
	_pass_skipped()
	_gap_left = 0.0 if done() else GAP
	changed.emit()


func _pass_skipped() -> void:
	while not done() and skipped.has(LESSONS[index][0]):
		index += 1
