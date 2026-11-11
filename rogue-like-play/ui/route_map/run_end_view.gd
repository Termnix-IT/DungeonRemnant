class_name RunEndView
extends CanvasLayer

# The end of a real-time run, as roguelites report a run: over the chapter's
# illustration, darkened, a quiet window with the outcome (won, fallen or
# left) and where it ended, its seal stamped on the window's corner and, for
# a new deepest layer or a first clear, a gold line saying so; under it the
# way the run went, drawn as the route map draws it (RunJourney), ending on
# who felled her, or her; then two columns, all in view at once: on the left
# the echo brought home, made the moment of the screen, and the run's
# figures as tiles (how far, how long, the foes felled, the level); on the
# right the build it took, as the run's menu shows it (a grid of emblems,
# the one pointed at or focused told under it); and at the foot the one way
# on. Enter (or the button) goes on: back to the base when the run came from
# it, else a new run (a run played on its own).

signal again_requested

const BACKDROP := Color(0.02, 0.025, 0.035, 0.84)
const WIDTH := 1180.0
# The build's grid: as the run's menu draws it, ten to a row (all the boons fit in four).
const EMBLEM_SIZE := 48.0
const BOON_COLUMNS := 10
const NOTE_LINES := 2
const NO_BOONS := "この探索で取得した強化はない"
# The outcome's seals, and how the stamp drops.
const SEALS := {
	&"clear": preload("res://art/ui/hud/seal_clear.png"),
	&"defeat": preload("res://art/ui/hud/seal_defeat.png"),
	&"return": preload("res://art/ui/hud/seal_return.png"),
}
const SEAL_SIZE := 150.0
const SEAL_TURN := -0.21
const STAMP_DELAY := 0.25
const STAMP_TIME := 0.22
# The echo's moment, after the stamp: the number counts up with a tick that
# climbs as it goes (the purse's total beside it with it), then it pulses,
# flashes, throws sparks and rings.
const COUNT_DELAY := 0.2
const COUNT_TIME := Vector2(0.6, 1.6)
const COUNT_TICKS := 14
const TICK_PITCH := Vector2(0.9, 1.5)
const SPARKS := 16
const SPARK_TIME := 0.6
const SPARK_REACH := Vector2(70.0, 150.0)

var journey: RunJourney
var seal: TextureRect
var record_label: Label
var total_label: Label
# Whether the echo has finished counting (the moment played out).
var counted := false
var _art: TextureRect
var _title: Label
var _ending: Label
var _tiles: GridContainer
var _boons: GridContainer
var _boon_cells: Array[EquipSocket] = []
var _boon_name: Label
var _boon_rank: Label
var _boon_note: Label
var _echo: Label
var _sparks: Control
var _spark_dirs: Array[Vector2] = []
var _spark_phase := 0.0
var _save_note: Label
var _panel: PanelContainer
var _button: Button
var _echo_amount := 0
var _total_before := -1
var _last_tick := -1


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_art)
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"QuietWindow"
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_title = _centered(stack, &"VictoryTitle")
	_ending = _centered(stack, &"BodyLabel")
	record_label = _centered(stack, &"GoldLabel")
	record_label.hide()
	# The way the run went, ending where it ended.
	journey = RunJourney.new()
	journey.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(journey)
	HubUI.rule(stack)
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ListRow"
	stack.add_child(columns)
	# Left: the echo brought home, large, with the purse's new total under
	# it, then the run's figures.
	var left := VBoxContainer.new()
	left.theme_type_variation = &"DetailStack"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	_centered(left, &"MutedLabel").text = tr("持ち帰った残響")
	_echo = _centered(left, &"ResultEcho")
	_sparks = Control.new()
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.draw.connect(_draw_sparks)
	_echo.add_child(_sparks)
	_sparks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	total_label = _centered(left, &"MutedLabel")
	_save_note = _centered(left, &"MutedLabel")
	_save_note.hide()
	_tiles = GridContainer.new()
	_tiles.theme_type_variation = &"CodexGrid"
	_tiles.columns = 2
	left.add_child(_tiles)
	HubUI.column_rule(columns, 16.0)
	# Right: the build, its heading and grid on the column's centre, the
	# boon's account under them, running text, to the left.
	var right := VBoxContainer.new()
	right.theme_type_variation = &"DetailStack"
	columns.add_child(right)
	_centered(right, &"HeadingLabel").text = tr("取得した強化")
	_boons = GridContainer.new()
	_boons.theme_type_variation = &"CodexGrid"
	_boons.columns = BOON_COLUMNS
	_boons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(_boons)
	var cell := EMBLEM_SIZE + 2.0 * (EquipSocket.RING_GAP + EquipSocket.RING_WIDTH)
	right.custom_minimum_size.x = BOON_COLUMNS * cell + (BOON_COLUMNS - 1) * _boons.get_theme_constant(&"h_separation")
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"HudTallyRow"
	right.add_child(heading)
	_boon_name = HubUI.label(heading, "", &"ItemNameLabel")
	_boon_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_boon_rank = HubUI.label(heading, "", &"MutedLabel")
	_boon_rank.autowrap_mode = TextServer.AUTOWRAP_OFF
	_boon_rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_boon_note = HubUI.label(right, "", &"DescriptionLabel")
	_boon_note.custom_minimum_size.y = NOTE_LINES * _boon_note.get_theme_font(&"font").get_height(_boon_note.get_theme_font_size(&"font_size"))
	HubUI.space(stack)
	# The way on, at the foot.
	_button = HubUI.primary_action(stack, tr("新しい探索を始める"), func(): again_requested.emit())
	seal = TextureRect.new()
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.size = Vector2.ONE * SEAL_SIZE
	seal.pivot_offset = seal.size * 0.5
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Above the panel, not laid out by it.
	root.add_child(seal)
	seal.hide()
	_panel.item_rect_changed.connect(_place_seal)
	hide()


func _centered(parent: Node, role: StringName) -> Label:
	var label := HubUI.label(parent, "", role)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


# {cleared, abandoned, record, first_clear, echo_before, layer, layers,
# chapter, chapter_id, step, time, kills, level, build, echo, path,
# fallen_to, moveset}; `home` names the way on
# (back to the base, or a new run);
# `art` (the chapter's illustration) lies darkened behind the window.
func present(result: Dictionary, home: bool = false, art: Texture2D = null) -> void:
	var won: bool = result.cleared
	var left: bool = result.get("abandoned", false)
	_art.texture = art
	_title.text = tr("踏破") if won else (tr("中断") if left else tr("敗北"))
	_title.theme_type_variation = &"VictoryTitle" if won else &"DefeatTitle"
	var place: String = result.chapter if int(result.get("step", 0)) == 0 else tr("%s（段階%d）") % [result.chapter, int(result.step)]
	_ending.text = "%s　%s" % [place, tr("ボスを撃破した") if won else (tr("第%d層で中断した") if left else tr("第%d層で倒れた")) % (int(result.layer) + 1)]
	_button.text = tr("拠点へ戻る") if home else tr("新しい探索を始める")
	for child in _tiles.get_children():
		child.free()
	var reached := tr("ボス") if won else tr("第%d層") % (int(result.layer) + 1)
	for pair: Array in [[tr("到達"), reached], [tr("戦った時間"), "%d:%02d" % [floori(float(result.time) / 60.0), floori(float(result.time)) % 60]],
			[tr("撃破"), tr("%d体") % result.kills], [tr("レベル"), "Lv %d" % result.level]]:
		_tile(pair[0], pair[1])
	journey.show_run(result)
	_show_build(result.get("build", []))
	_echo_amount = int(result.echo)
	_total_before = int(result.get("echo_before", -1))
	counted = false
	_last_tick = -1
	# Saved already; only the numbers count up.
	_echo.text = UIFormat.amount(0)
	total_label.text = _total_text(0)
	total_label.visible = _total_before >= 0
	seal.texture = SEALS[&"clear" if won else (&"return" if left else &"defeat")]
	record_label.text = tr("初めての踏破") if result.get("first_clear", false) else (tr("最深到達を更新") if result.get("record", false) else "")
	record_label.hide()
	show()
	_button.grab_focus()
	UIMotion.bind_buttons(_panel)
	_stamp.call_deferred()


func _total_text(counted_so_far: int) -> String:
	return tr("所持 残響 %s") % UIFormat.amount(_total_before + counted_so_far)


# The seal drops onto the panel's top corner, then the record, if any.
func _stamp() -> void:
	_place_seal()
	seal.scale = Vector2.ONE * 2.4
	seal.rotation = SEAL_TURN * 2.0
	seal.modulate.a = 0.0
	seal.show()
	var drop := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(seal, "scale", Vector2.ONE, STAMP_TIME).set_delay(STAMP_DELAY)
	drop.tween_property(seal, "rotation", SEAL_TURN, STAMP_TIME).set_delay(STAMP_DELAY)
	drop.tween_property(seal, "modulate:a", 1.0, STAMP_TIME * 0.5).set_delay(STAMP_DELAY)
	drop.chain().tween_callback(_landed)


# On the panel's top right corner, wherever the panel's contents have laid
# it (it is placed again whenever the panel moves or grows).
func _place_seal() -> void:
	var corner := _panel.get_global_rect()
	seal.position = Vector2(corner.end.x - SEAL_SIZE * 0.72, corner.position.y - SEAL_SIZE * 0.28)


func _landed() -> void:
	GameAudio.play(self, &"heavy", -14.0)
	UIMotion.of(_panel).pulse(1.02, UIMotion.SELECT_TIME)
	if not record_label.text.is_empty():
		record_label.show()
		UIMotion.of(record_label).appear(0.0, UIMotion.WINDOW_TIME)
		# The flash once it is in: a flash keeps the alpha it starts from.
		create_tween().tween_callback(func(): UIMotion.of(record_label).flash(1.4, UIMotion.GOLD_TIME)).set_delay(UIMotion.WINDOW_TIME)
	_count()


# How long the echo counts: longer for more, within COUNT_TIME.
func count_time() -> float:
	return clampf(COUNT_TIME.x + _echo_amount / 250.0, COUNT_TIME.x, COUNT_TIME.y)


func _count() -> void:
	if _echo_amount <= 0:
		_counted()
		return
	var counting := create_tween()
	counting.tween_interval(COUNT_DELAY)
	counting.tween_method(_count_to, 0.0, 1.0, count_time()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	counting.tween_callback(_counted)


func _count_to(progress: float) -> void:
	var value := roundi(_echo_amount * progress)
	_echo.text = UIFormat.amount(value)
	total_label.text = _total_text(value)
	# A tick at each step of the way, climbing as it goes.
	var tick := floori(progress * COUNT_TICKS)
	if tick != _last_tick and progress < 1.0:
		_last_tick = tick
		GameAudio.play(self, &"pickup", -24.0, lerpf(TICK_PITCH.x, TICK_PITCH.y, progress))


# The count is done: the number pulses and flashes, sparks fly, a chime.
func _counted() -> void:
	counted = true
	_echo.text = UIFormat.amount(_echo_amount)
	total_label.text = _total_text(_echo_amount)
	if _echo_amount <= 0:
		return
	_echo.pivot_offset = _echo.size * 0.5
	UIMotion.of(_echo).pulse(1.05, UIMotion.GOLD_TIME * 2.0)
	UIMotion.of(_echo).flash(1.5, UIMotion.GOLD_TIME * 2.0)
	GameAudio.play(self, &"level_up", -16.0)
	_spark_dirs.clear()
	for index in SPARKS:
		var angle := TAU * index / SPARKS + randf_range(-0.15, 0.15)
		_spark_dirs.append(Vector2.from_angle(angle) * randf_range(SPARK_REACH.x, SPARK_REACH.y))
	create_tween().tween_method(_spark, 0.0, 1.0, SPARK_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _spark(phase: float) -> void:
	_spark_phase = phase
	_sparks.queue_redraw()


# Gold diamonds flung out from the number, fading as they go.
func _draw_sparks() -> void:
	if _spark_dirs.is_empty() or _spark_phase >= 1.0:
		return
	var color := _echo.get_theme_color(&"font_color")
	var middle := _sparks.size * 0.5
	for direction in _spark_dirs:
		var at := middle + direction * _spark_phase
		var size := 5.0 * (1.0 - _spark_phase) + 1.0
		_sparks.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -size * 1.4), at + Vector2(size, 0), at + Vector2(0, size * 1.4), at + Vector2(-size, 0)]), Color(color, 1.0 - _spark_phase))


# A figure of the run: a small caption over a large value, on an inset tile.
func _tile(caption: String, value: String) -> void:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"CardSurface"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tiles.add_child(tile)
	var lines := VBoxContainer.new()
	tile.add_child(lines)
	_centered(lines, &"MutedLabel").text = caption
	_centered(lines, &"ValueLabel").text = value


# The build: each boon an emblem in a socket, its rank at the lower right as
# the HUD's row shows it; pointing at one or focusing it tells it under the
# grid. Up from the way on goes into the grid, down from its last row back.
func _show_build(build: Array) -> void:
	for child in _boons.get_children():
		child.free()
	_boon_cells.clear()
	_button.focus_neighbor_top = NodePath()
	_boons.visible = not build.is_empty()
	_boon_name.get_parent().visible = not build.is_empty()
	_boon_note.text = tr(NO_BOONS)
	_boon_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if build.is_empty() else HORIZONTAL_ALIGNMENT_LEFT
	for entry: Array in build:
		var boon: BoonData = entry[0]
		var rank: int = entry[1]
		var cell := EquipSocket.new(EMBLEM_SIZE, false, true)
		cell.emblem = EmblemIcons.texture(boon.emblem)
		cell.tooltip_text = tr(boon.display_name)
		_boons.add_child(cell)
		if boon.max_level > 1:
			var digit := HubUI.label(cell, str(rank), &"HudCaption")
			digit.autowrap_mode = TextServer.AUTOWRAP_OFF
			digit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			digit.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			digit.grow_vertical = Control.GROW_DIRECTION_BEGIN
		cell.focus_entered.connect(_tell_boon.bind(boon, rank, cell))
		cell.mouse_entered.connect(_tell_boon.bind(boon, rank, cell))
		_boon_cells.append(cell)
	var last := _boon_cells.size() - 1
	for index in _boon_cells.size():
		var cell := _boon_cells[index]
		var column := index % BOON_COLUMNS
		cell.focus_neighbor_left = _boon_cells[index - 1].get_path() if column > 0 else cell.get_path()
		cell.focus_neighbor_right = _boon_cells[index + 1].get_path() if column < BOON_COLUMNS - 1 and index < last else cell.get_path()
		cell.focus_neighbor_top = _boon_cells[index - BOON_COLUMNS].get_path() if index >= BOON_COLUMNS else cell.get_path()
		var below := index + BOON_COLUMNS
		if below > last and index / BOON_COLUMNS < last / BOON_COLUMNS:
			below = last
		cell.focus_neighbor_bottom = _boon_cells[below].get_path() if below <= last else _button.get_path()
	if not build.is_empty():
		_button.focus_neighbor_top = _boon_cells[0].get_path()
		_tell_boon(build[0][0], build[0][1], _boon_cells[0])


# The boon's name, rank and what it does, under the grid; its socket keeps a
# quiet gold ring, and the way up from the button returns to it.
func _tell_boon(boon: BoonData, rank: int, cell: EquipSocket) -> void:
	for other in _boon_cells:
		other.lit = other == cell
	_boon_name.text = tr(boon.display_name)
	_boon_rank.text = "" if boon.max_level == 1 else "Lv %d / %d" % [rank, boon.max_level]
	_boon_note.text = boon.effect_description(rank)
	_button.focus_neighbor_top = cell.get_path()


# What the recorded run opened (a difficulty step), told in gold with the
# record once the seal lands. Called before the seal lands.
func tell_opened(text: String) -> void:
	record_label.text = text if record_label.text.is_empty() else "%s　%s" % [record_label.text, text]


# Whether the result was saved; shown only when there is something to say.
func show_save_status(text: String, alert: bool) -> void:
	_save_note.text = text
	_save_note.visible = alert


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		again_requested.emit()
