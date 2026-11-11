extends SceneTree

# The first run's lessons: the controls taught one at a time, each until it
# is done, in a first run's first area only, and shown on the fight's HUD.
#   godot --headless --path . --log-file .godot/first-lessons-tests.log --script res://tests/test_first_lessons.gd

const FRAME := 1.0 / 60.0
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func hold(lessons: FirstLessons, seconds: float, moving: bool = false) -> void:
	for index in roundi(seconds / FRAME):
		lessons.step(FRAME, moving)


func run_tests() -> void:
	# The rules, stepped by hand.
	var lessons := FirstLessons.new()
	var turns := [0]
	lessons.changed.connect(func(): turns[0] += 1)
	check(not lessons.done() and lessons.current()[0] == &"move", "The first lesson is how to move")
	lessons.note(&"dash")
	hold(lessons, FirstLessons.MIN_SHOWN + 0.2)
	check(lessons.current()[0] == &"move", "Another lesson's deed does not pass this one, nor does standing still")
	hold(lessons, FirstLessons.MOVE_TIME + 0.1, true)
	check(lessons.current().is_empty() and lessons.index == 1 and turns[0] == 1, "Once she has walked a while it gives way, and a gap follows")
	hold(lessons, FirstLessons.GAP + 0.05)
	check(lessons.current()[0] == &"strike" and turns[0] == 2, "Then the attack comes up")
	for swing in FirstLessons.STRIKES - 1:
		lessons.note(&"strike")
	hold(lessons, FirstLessons.MIN_SHOWN + 0.1)
	check(lessons.current()[0] == &"strike", "A swing or two is not yet the combo")
	lessons.note(&"strike")
	hold(lessons, FRAME * 2.0)
	hold(lessons, FirstLessons.GAP + 0.05)
	check(lessons.current()[0] == &"dash", "Three swings pass it, and the dash comes up")
	lessons.note(&"dash")
	hold(lessons, FirstLessons.MIN_SHOWN * 0.5)
	check(lessons.current()[0] == &"dash", "A lesson met at once still stays long enough to be read")
	hold(lessons, FirstLessons.MIN_SHOWN * 0.5 + FirstLessons.GAP + 0.1)
	check(lessons.current()[0] == &"charge", "Then the charged attack")
	lessons.note(&"charge")
	hold(lessons, FirstLessons.MIN_SHOWN + FirstLessons.GAP + 0.1)
	check(lessons.current()[0] == &"skill", "Then the skill")
	lessons.note(&"skill")
	hold(lessons, FirstLessons.MIN_SHOWN + 0.1)
	check(lessons.done() and lessons.current().is_empty(), "With the skill used, the lessons are over")
	var bare := FirstLessons.new()
	bare.skip(&"skill")
	for deed: StringName in [&"move", &"strike", &"strike", &"strike", &"dash", &"charge"]:
		bare.note(deed)
		hold(bare, FirstLessons.MIN_SHOWN + FirstLessons.GAP + 0.2, true)
	check(bare.done(), "A lesson left out (no skill set) is passed over")
	for lesson: Array in FirstLessons.LESSONS:
		check(lesson.size() == 4 and not String(lesson[1]).is_empty() and not String(lesson[2]).is_empty() and not String(lesson[3]).is_empty(), "A lesson names its key, its button and what it does: %s" % lesson[0])

	# In a fight: only a first run's first area teaches, on the HUD over the guide.
	var plain := await area_of(false, 0)
	check(plain.lessons == null and not plain.hud.lesson.visible, "A run that is not the first teaches nothing")
	plain.free()
	await process_frame
	var later := await area_of(true, 1)
	check(later.lessons == null, "Nor does a first run past its first area")
	later.free()
	await process_frame
	var first := await area_of(true, 0)
	var hud := first.hud
	check(first.lessons != null and hud.lesson.visible and shown_lessons(hud) == ["移動"], "A first run's first area shows the first lesson")
	for frame in 3:
		await process_frame
	var lesson_rect := hud.lesson.get_global_rect()
	var screen := root.get_visible_rect()
	var ring := Rect2(Vector2(screen.size) * 0.5 - Vector2(260, 200), Vector2(520, 400))
	check(screen.grow(-4).encloses(lesson_rect) and not lesson_rect.intersects(hud.guide.get_global_rect()) and not lesson_rect.intersects(ring) and absf(lesson_rect.get_center().x - screen.size.x * 0.5) < 2.0, "The lesson stands at the bottom centre, over the guide and off the ground round her")
	check(not lesson_rect.intersects(hud.hp_gauge.get_global_rect()) and hud.slots.values().all(func(slot: ActionSlot) -> bool: return not slot.visible or not slot.get_global_rect().intersects(lesson_rect)), "Clear of her health and of the action slots")
	# What she does in the fight reaches the lessons.
	first.lessons.index = 2
	first.lessons._gap_left = 0.0
	first.lessons._shown = FirstLessons.MIN_SHOWN
	first.events.dash_started.emit(Vector2.RIGHT)
	first.lessons.step(FRAME, false)
	check(first.lessons.index == 3, "A dash in the fight passes the dash's lesson")
	first.lessons._gap_left = 0.0
	first.lessons.changed.emit()
	check(shown_lessons(hud) == [FirstLessons.LESSONS[3][3]], "The HUD follows to the next lesson")
	first.clear()
	check(first.lessons == null and not hud.lesson.visible, "Clearing the area ends the lessons")
	first.hit_stop.release()
	first.free()
	await process_frame

	print("First lessons tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


# The words of the lesson the HUD shows (its hints, not its helpers).
func shown_lessons(hud: ActionHud) -> Array:
	var words := []
	for child in hud.lesson.get_children():
		if child is Button and not child.is_queued_for_deletion():
			words.append((child as Button).text)
	return words


# A fight in the first chapter's first field, of a run that is guided or not
# and has this many areas behind it.
func area_of(guided: bool, cleared: int) -> BattleArea:
	var run := RunState.new(7)
	run.guided = guided
	run.areas_cleared = cleared
	var area := BattleArea.new()
	var field: AreaData = load("res://data/areas/moss_plain.tres")
	area.setup(field, run, 7)
	root.add_child(area)
	await process_frame
	area.hero.controlled = false
	return area
