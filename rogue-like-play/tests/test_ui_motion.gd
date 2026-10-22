extends SceneTree

# The base's motion (UIMotion): a button's restrained hover, focus and press
# that never move the layout; a purchase shown only after it was saved, the
# echo pulsing within bounds, a refused or unsaved purchase showing nothing;
# marks that slide and rows that arrive; rapid navigation settling every
# page; and no tween left behind.

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func settle(seconds: float = 0.35) -> void:
	await create_timer(seconds).timeout
	await process_frame


func near_scale(control: Control, value: float) -> bool:
	return control.scale.distance_to(Vector2.ONE * value) < 0.002


func run_tests() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.meta.echo = 1000
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	hub.show_page("upgrade")
	var page: MetaUpgradePage = hub.upgrade_page
	var button: Button = page.buttons[0]
	var motion := UIMotion.of(button)
	await settle()
	var position_before := button.position
	var size_before := button.size
	button.release_focus()
	button.mouse_entered.emit()
	await settle(0.14)
	check(near_scale(button, 1.015), "Hover reaches a restrained scale")
	check(button.pivot_offset.is_equal_approx(button.size * 0.5), "Scaling uses the centre pivot")
	button.mouse_exited.emit()
	await settle(0.14)
	check(near_scale(button, 1.0), "Mouse exit returns to rest")
	button.grab_focus()
	await settle(0.14)
	check(near_scale(button, 1.015), "Keyboard and controller focus get the same response")
	button.mouse_entered.emit()
	button.mouse_exited.emit()
	await settle(0.14)
	check(near_scale(button, 1.015), "Mouse exit keeps the keyboard focus's response")
	button.release_focus()
	button.mouse_entered.emit()
	button.button_down.emit()
	await settle(0.09)
	check(near_scale(button, 0.98), "Holding a press stays slightly compressed")
	button.button_up.emit()
	await settle(0.14)
	check(near_scale(button, 1.015), "Release returns to the hovered state")
	for index in 60:
		button.mouse_entered.emit()
		button.button_down.emit()
		button.button_up.emit()
		button.mouse_exited.emit()
	await settle()
	check(near_scale(button, 1.0), "Rapid hovers and clicks do not add up")
	check(button.position == position_before and button.size == size_before, "Motion leaves the container layout unchanged")
	button.mouse_entered.emit()
	await settle(0.14)
	button.disabled = true
	# Headless rendering has no draw signal; invoke the same redraw hook.
	motion._check_disabled()
	await settle(0.14)
	check(near_scale(button, 1.0), "A disabled hovered button resets")
	button.button_down.emit()
	await settle(0.1)
	check(near_scale(button, 1.0), "A disabled button ignores press feedback")
	button.disabled = false
	motion._check_disabled()
	button.mouse_exited.emit()

	# A purchase: shown after it is made, with the echo it cost.
	check(main.buy_upgrade(&"sturdy_body"), "A purchase goes through without waiting on motion")
	var cost: int = MetaProgress.find(&"sturdy_body").costs[0]
	check(main.meta.echo == 1000 - cost and hub.echo_label.text == UIFormat.amount(1000 - cost), "Echo and its text change at once")
	check(hub.feedback.text.contains("残響 -%d" % cost), "The note says what it cost")
	await settle(0.08)
	check(hub.echo_label.scale.x > 1.02 and hub.echo_label.scale.x <= 1.081, "The echo pulses within bounds")
	await settle()
	check(near_scale(hub.echo_label, 1.0), "The pulse settles")
	main.meta.echo = 0
	var before: Dictionary = MetaCodec.encode(main.meta)
	check(not main.buy_upgrade(&"double_dash"), "A purchase the echo cannot pay for is refused")
	check(MetaCodec.encode(main.meta) == before, "A refused purchase changes nothing")
	main.meta.echo = 1000
	before = MetaCodec.encode(main.meta)
	main.saving_enabled = true
	main.store.path = "res://.godot/motion-missing-%d/progress.json" % Time.get_ticks_usec()
	check(not main.buy_upgrade(&"double_dash"), "A purchase that cannot be saved is undone")
	check(MetaCodec.encode(main.meta) == before, "An unsaved purchase leaves the progress as it was")
	main.saving_enabled = false

	# Marks slide and rows arrive.
	var host := Control.new()
	hub.add_child(host)
	var mark := UIMotion.of(host)
	var first := Rect2(0, 0, 100, 40)
	var second := Rect2(0, 80, 100, 40)
	check(mark.follow_mark(first) == first, "A first mark is placed at once")
	check(mark.follow_mark(second) == first, "A new place starts from the shown mark")
	await create_timer(UIMotion.SLIDE_TIME * 0.5).timeout
	var halfway := mark.mark()
	check(halfway.position.y > first.position.y and halfway.position.y < second.position.y, "The mark slides between places")
	await settle(UIMotion.SLIDE_TIME)
	check(mark.mark() == second, "The mark settles on its place")
	host.hide()
	host.show()
	check(not mark.has_mark() and mark.follow_mark(first) == first, "Hiding drops the mark so it does not slide in from a stale place")
	host.free()
	check(UIMotion.row_arrival(0.0, 0, 6) == 0.0 and UIMotion.row_arrival(1.0, 5, 6) == 1.0, "Rows arrive from nothing to settled")
	check(UIMotion.row_arrival(0.3, 0, 6) > UIMotion.row_arrival(0.3, 3, 6), "Upper rows arrive first")

	# Rapid navigation settles every page.
	for index in 20:
		hub.show_page("upgrade")
		hub.show_page("codex")
		hub.show_page("settings")
		hub.show_page("home")
	await settle(UIMotion.WINDOW_TIME + 0.2)
	for shown: Control in [hub.home_page, hub.upgrade_page, hub.codex_page, hub.settings_page]:
		check(is_equal_approx(shown.modulate.a, 1.0) and near_scale(shown, 1.0), "Rapid navigation restores %s's alpha and scale" % shown.name)
	# A new account comes into the detail column from the right and settles
	# where the column lays it out, even when asked again mid-way.
	hub.show_page("codex")
	await settle(UIMotion.WINDOW_TIME + 0.2)
	var column: Control = hub.codex_page._info
	var rest := column.position
	hub.codex_page._select(1)
	await process_frame
	await process_frame
	check(column.position.x > rest.x + 1.0 and column.modulate.a < 1.0, "A new account starts to the right, faint")
	hub.codex_page._select(0)
	await settle(UIMotion.DETAIL_SLIDE_TIME + 0.15)
	check(column.position.is_equal_approx(rest) and is_equal_approx(column.modulate.a, 1.0), "It settles in place, whole")
	hub.show_page("home")
	await settle(UIMotion.WINDOW_TIME + 0.2)
	check(not motion.is_processing(), "The helper has no idle per-frame polling")
	await settle(HubAmbience.FOCUS_TIME * 1.5 + 0.05)
	check(get_processed_tweens().is_empty(), "Completed and cancelled UI tweens do not pile up")
	main.free()
	await process_frame
	check(get_processed_tweens().is_empty(), "Freeing the UI releases every bound tween")
	print("UI motion: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
