extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func pulsing(label: Control) -> bool:
	var tween := UIMotion.of(label).scale_tween
	return tween != null and tween.is_running()


func run_tests() -> void:
	var hud = preload("res://ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	await create_timer(0.05).timeout
	var trail: ProgressBar = hud.get_node("BottomLeft/HpTrail")
	var mana_trail: ProgressBar = hud.get_node("BottomLeft/MpTrail")
	hud.refresh(24, 24, 0, 0, "", 1, "Room")
	hud.show_mana(20, 20)
	check(trail.value == 24 and mana_trail.value == 20, "Initial values snap without damage feedback")
	check(get_processed_tweens().is_empty(), "Initial refresh starts no animation")
	hud.refresh(14, 24, 1, 1, "被ダメージ", 1, "Room")
	hud.show_mana(12, 20)
	check(hud.hp_bar.value == 14 and hud.hp_value.text == "14 / 24", "HP is immediately authoritative")
	check(hud.mp_bar.value == 12 and hud.mp_value.text == "12 / 20", "MP is immediately authoritative")
	check(trail.value == 24 and mana_trail.value == 20, "Loss remains visible on trailing bars")
	# Check the running pulse, not a mid-animation sample: a long first frame
	# in headless runs can finish a 220ms pulse before a timed sample.
	check(pulsing(hud.hp_value) and pulsing(hud.mp_value), "Changed values pulse")
	await create_timer(0.08).timeout
	var active := UIMotion.of(trail).vital_tween
	hud.refresh(14, 24, 1, 1, "", 1, "Room")
	check(UIMotion.of(trail).vital_tween == active, "Unchanged refresh does not restart animation")
	hud.refresh(8, 24, 2, 1, "", 1, "Room")
	check(not active.is_valid() and trail.value >= 14, "Rapid damage replaces tween and preserves remaining trail")
	await create_timer(0.5).timeout
	check(trail.value == 8 and mana_trail.value == 12, "Both trails settle at current values")
	check(hud.hp_value.scale.is_equal_approx(Vector2.ONE), "Pulse returns to baseline")
	hud.refresh(3, 24, 3, 1, "", 1, "Room")
	hud.refresh(18, 24, 4, 1, "回復", 1, "Room")
	check(trail.value == 18 and hud.hp_bar.value == 18, "Healing cancels outstanding damage trail")
	check(pulsing(hud.hp_value), "Healing pulses current value")
	await create_timer(0.08).timeout
	hud.refresh(10, 30, 5, 1, "", 1, "Room")
	check(trail.value == 10 and trail.max_value == 30 and hud.hp_value.scale == Vector2.ONE, "Maximum change snaps without misleading damage")
	hud.refresh(0, 30, 6, 1, "", 1, "Room")
	check(hud.hp_bar.value == 0 and trail.value == 10, "Death updates immediately while trail remains visible")
	hud.hide()
	await process_frame
	check(trail.value == 0 and hud.hp_value.scale == Vector2.ONE, "Hiding CanvasLayer resets motion")
	hud.refresh(20, 30, 0, 0, "", 1, "Room")
	hud.show()
	hud.refresh(30, 30, 0, 0, "", 1, "Room")
	check(trail.value == 30 and hud.hp_value.scale == Vector2.ONE, "Hidden refresh and redisplay establish fresh baseline")
	hud.show_mana(0, 0)
	check(mana_trail.max_value == 1 and mana_trail.value == 0, "Zero maximum is safe")
	hud.refresh(20, 30, 1, 0, "", 1, "Room")
	hud.reset_log()
	hud.refresh(30, 30, 0, 0, "", 1, "Room")
	check(trail.value == 30 and hud.hp_value.scale == Vector2.ONE, "Run reset clears feedback baseline")
	hud.refresh(10, 30, 1, 0, "", 1, "Room")
	hud.free()
	await process_frame
	check(get_processed_tweens().is_empty(), "Freeing active HUD releases all tweens")
	print("HUD motion: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
