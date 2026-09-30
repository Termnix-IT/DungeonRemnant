extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func run_tests() -> void:
	check(HudPortrait.SHEET.get_size() == Vector2(96 * 4, 96), "The portrait sheet holds four 96px faces")
	var hud = preload("res://ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	var portrait: HudPortrait = hud.portrait
	var vitals: Control = hud.get_node("BottomLeft")
	check(portrait != null and portrait.get_parent() == vitals, "The portrait shares one plate with the vitals")
	var face_rect := portrait.get_global_rect()
	check(vitals.get_global_rect().encloses(face_rect), "The portrait frame stays inside the plate")
	for node_name in ["HpCaption", "HpValue", "HpBar", "MpCaption", "MpValue", "MpBar", "Level", "ExpValue", "ExpBar", "Meta"]:
		check(not face_rect.intersects((vitals.get_node(node_name) as Control).get_global_rect()), "The portrait leaves %s clear" % node_name)
	check(face_rect.end.x < (vitals.get_node("HpBar") as Control).get_global_rect().position.x, "HP and MP sit beside the face")
	check(portrait.theme_type_variation == &"HudPortraitFrame", "The face uses the HUD portrait frame role")
	var equipment: HudEquipment = hud.equipment_rows
	check(equipment.strip, "The dungeon HUD shows equipment as one compact row")
	check((hud.get_node("BottomRight") as Control).size.y <= 180.0, "The equipment panel leaves the floor above it clear")
	var rows := HudEquipment.new()
	check(not rows.strip, "Other screens keep the captioned equipment rows")
	rows.free()

	for bar_name in ["HpBar", "MpBar"]:
		var bar: ProgressBar = vitals.get_node(bar_name)
		var ticks := vitals.get_node_or_null(bar_name + "Ticks") as VitalTicks
		check(ticks != null and ticks.get_index() == bar.get_index() + 1 and ticks.get_rect() == bar.get_rect(), "%s has quarter notches drawn just above it" % bar_name)
		check(ticks != null and ticks.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Notches never take input")
	var track := (vitals.get_node("HpTrail") as ProgressBar).get_theme_stylebox(&"background") as StyleBoxTexture
	check(track != null and track.expand_margin_top > 0.0, "The HP gauge frame surrounds the bar without moving it")
	hud.show_health(24, 24)
	check(portrait.face == HudPortrait.Face.NORMAL, "Full health shows the calm face")
	hud.show_health(24, 24)
	check(portrait.face == HudPortrait.Face.NORMAL, "An unchanged value is not a hit")
	hud.show_health(18, 24)
	check(portrait.face == HudPortrait.Face.HURT, "A landed hit shows the wince")
	await create_timer(HudPortrait.HURT_TIME + 0.1).timeout
	check(portrait.face == HudPortrait.Face.NORMAL, "The wince passes back to the calm face")
	hud.show_health(24, 24)
	check(portrait.face == HudPortrait.Face.NORMAL, "Recovery is not a hit")
	hud.show_health(7, 24)
	await create_timer(HudPortrait.HURT_TIME + 0.1).timeout
	check(portrait.face == HudPortrait.Face.WEARY, "Danger-range health shows the worn-out face")
	check(portrait.weary() == (7.0 / 24.0 <= DangerVignette.THRESHOLD), "The face agrees with the danger vignette's threshold")
	hud.show_health(0, 24)
	check(portrait.face == HudPortrait.Face.WEARY, "A killing blow keeps the worn-out face rather than a wince")

	hud.reset_log()
	hud.show_health(24, 24)
	var blinked := false
	portrait._blink_clock = HudPortrait.BLINK_INTERVAL - HudPortrait.BLINK_TIME * 0.5
	portrait._update_face()
	blinked = portrait.face == HudPortrait.Face.BLINK
	check(blinked, "The calm face blinks at the end of each interval")
	await create_timer(HudPortrait.BLINK_TIME + 0.05).timeout
	check(portrait.face == HudPortrait.Face.NORMAL, "The blink is brief")
	hud.queue_free()
	await process_frame
	print("HUD portrait: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
