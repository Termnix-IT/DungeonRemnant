class_name RunEndView
extends CanvasLayer

# The end of a real-time run: a painted scene, not a window, and a different
# scene for each way a run ends.
#
#   Won: the last hall's great door stands open on the dawn. Its light comes
#   out over the hall, the word is struck in gold and its seal stamped beside
#   it, she steps in before the door, and the echo she brings home counts up
#   as the moment of the screen (it flares, throws sparks and rings; she
#   smiles).
#   Fallen: her sword stands in a broken floor, in the dark, embers rising
#   round it. The picture comes up slowly out of black; the word is quiet;
#   who felled her looms out of the dark across from the sword, named, with
#   where to study it; what she still brings home is told plainly.
#   Left: the corridor back, its way out far off. Told briefly and at once.
#
# In each the same things are told, in the order they matter there: how it
# ended and where, a record or what the run opened, the echo brought home
# (with the purse's new total), the foes newly recorded, the run's figures,
# the build it took (emblems; the one pointed at or focused told under them)
# and the way the run went (RunJourney). The way on stands at the lower
# right: back to the base when the run came from it, else a new run.
#
# The scene plays by itself and holds nothing back: the result is recorded
# and saved before it is shown. A press while it plays brings all of it in
# at once (settle) instead of leaving, so a press meant for the fight never
# skips the result; the way on takes presses a moment after.

signal again_requested
# The same chapter is to be set out for again, straight from here.
signal retry_requested

const DESIGN := Vector2(1600.0, 900.0)
const SCENE := preload("res://ui/route_map/result_scene.gdshader")
const FOE_LIGHT := preload("res://ui/route_map/result_foe.gdshader")
const PAINTINGS := {
	&"clear": preload("res://art/ui/result/victory.png"),
	&"defeat": preload("res://art/ui/result/defeat.png"),
	&"return": preload("res://art/ui/result/retreat.png"),
}
# Each scene's light (result_scene.gdshader), and how it plays: when each
# part comes in (seconds from the start) and over how long.
const SCENES := {
	&"clear": {"source": Vector2(0.745, 0.34), "spread": 1.0, "glow": 0.42, "glow_reach": 0.32, "glow_colour": Color(1.0, 0.86, 0.56), "motes": 1.0, "embers": 0.0, "lift": 0.0,
		"shade": 0.1, "shade_reach": 0.58, "light": 1.5, "title": [0.1, 0.24], "place": [0.45, 0.3], "figures": [0.9, 0.3], "found": [1.05, 0.3], "build": [1.15, 0.3], "journey": [1.2, 0.35], "button": [1.3, 0.25]},
	&"defeat": {"source": Vector2(0.72, 0.5), "spread": 0.0, "glow": 0.0, "glow_reach": 0.3, "glow_colour": Color(1.0, 0.5, 0.2), "motes": 0.0, "embers": 1.0, "lift": 1.5,
		"shade": 0.0, "shade_reach": 0.5, "light": 2.4, "title": [0.5, 1.0], "seal": [1.2, 0.7], "place": [1.2, 0.6], "foe": [0.9, 1.2], "echo": [1.9, 0.5], "figures": [2.05, 0.4], "found": [2.2, 0.4], "build": [2.3, 0.4], "journey": [2.1, 0.5], "button": [2.6, 0.3]},
	&"return": {"source": Vector2(0.925, 0.35), "spread": 1.0, "glow": 0.5, "glow_reach": 0.2, "glow_colour": Color(0.62, 0.74, 1.0), "motes": 0.3, "embers": 0.0, "lift": 0.0,
		"shade": 0.1, "shade_reach": 0.56, "light": 0.8, "title": [0.05, 0.25], "seal": [0.2, 0.3], "place": [0.2, 0.25], "echo": [0.3, 0.25], "figures": [0.4, 0.25], "found": [0.5, 0.25], "build": [0.55, 0.25], "journey": [0.5, 0.3], "button": [0.7, 0.25]},
}
const EMBER_FROM := Vector2(0.722, 0.75)
# The parts of a scene that come in one after another.
const PARTS: Array[StringName] = [&"title", &"place", &"foe", &"echo", &"figures", &"found", &"build", &"journey", &"button", &"hero"]
# The column the words stand in, and the way on.
const COLUMN_X := 104.0
const COLUMN_WIDTH := 536.0
const BUTTON_RECT := Rect2(1216.0, 808.0, 288.0, 56.0)
# The other way on, beside it: the same chapter again (a run lost or left).
const RETRY_RECT := Rect2(944.0, 814.0, 248.0, 44.0)
const JOURNEY_AT := Vector2(96.0, 778.0)
const JOURNEY_SCALE := 0.58
# The build's emblems: one row of ten while they fit, smaller in more rows
# when the run took more. [the most boons, emblem size, to a row].
const BOON_GRIDS := [[10, 38.0, 10], [20, 38.0, 10], [1000, 33.0, 11]]
const BOON_GAP := 3.0
const NOTE_LINES := 2
const NO_BOONS := "この探索で取得した強化はない"
# The foes newly recorded: this many icons, then how many more.
const FOUND_SHOWN := 8
const FOUND_SIZE := 40.0
# The outcome's seals, and how the win's is stamped.
const SEALS := {
	&"clear": preload("res://art/ui/hud/seal_clear.png"),
	&"defeat": preload("res://art/ui/hud/seal_defeat.png"),
	&"return": preload("res://art/ui/hud/seal_return.png"),
}
const SEAL_SIZE := 132.0
const SEAL_QUIET := 84.0
const SEAL_TURN := -0.21
const STAMP_DELAY := 0.25
const STAMP_TIME := 0.22
# The echo's moment, after the stamp: the number counts up with a tick that
# climbs as it goes (the purse's total beside it with it), then it pulses,
# flashes, throws sparks and rings. A run not won counts quickly and quietly.
const COUNT_DELAY := 0.2
const COUNT_TIME := Vector2(0.6, 1.6)
const QUIET_COUNT := 0.45
const COUNT_TICKS := 14
const TICK_PITCH := Vector2(0.9, 1.5)
const SPARKS := 16
const SPARK_TIME := 0.6
const SPARK_REACH := Vector2(70.0, 150.0)
const QUIET_ECHO := 0.64
# She stands before the door: her feet, her height (of the sheet's), how far
# she steps in from, and the door's light on her.
const HERO_TEXTURE := preload("res://art/characters/mio_lobby.png")
const HERO_FEET := Vector2(866.0, 874.0)
const HERO_HEIGHT := 640.0
const HERO_STEP := 40.0
const HERO_IN := [0.15, 0.8]
const HERO_TINT := Color(0.8, 0.75, 0.74)
const HERO_RIM_DOOR := Color(1.0, 0.8, 0.5, 0.95)
const HERO_RIM_HALL := Color(0.5, 0.62, 1.0, 0.3)
# Who felled her stands over her sword: the room its picture is fitted in
# (it stands on the room's foot, in its middle), how far it rises as it
# comes, and the room its words take in the column.
const FOE_ROOM := Rect2(612.0, 236.0, 452.0, 500.0)
const FOE_RISE := 16.0
const FOE_WORDS := 122.0
# Her shadow before the door.
const HERO_SHADOW := Vector2(190.0, 26.0)
# The way on takes no press for this long after the scene is all in.
const LEAVE_GUARD := 0.35
# The scene starts to play once this many frames of it have been drawn: its
# first frames are long ones (the painting and its light are new to the
# screen), and none of the scene is to go by in them unseen.
const PLAY_AFTER := 3

var journey: RunJourney
var seal: TextureRect
var record_label: Label
var total_label: Label
# She, before the door (a run won only).
var hero: LobbyHero
# &"clear", &"defeat" or &"return".
var outcome: StringName = &"clear"
# The run's figures as [caption, value], in the order they are shown.
var figures: Array = []
# The foes this run recorded for the first time.
var found: Array[FoeData] = []
# Who felled her, when a blow named it.
var felled_by: FoeData
# Whether the echo has finished counting (the moment played out), and
# whether the whole scene is in and the way on takes presses.
var counted := false
var settled := false
var _root: Control
var _art: TextureRect
var _scene: ShaderMaterial
# The sheet the words are laid on: DESIGN px, fitted to the screen.
var _panel: Control
var _ending: Label
var _boons: Control
var _boon_cells: Array[EquipSocket] = []
var _boon_name: Label
var _boon_rank: Label
var _boon_note: Label
var _echo: Label
var _sparks: Control
var _spark_dirs: Array[Vector2] = []
var _spark_phase := 0.0
var _save_note: Label
var _button: Button
var retry_button: Button
var _echo_amount := 0
var _total_before := -1
var _last_tick := -1
var _title := ""
var _parts := {}
var _at := {}
var _staging: Tween
var _stamping: Tween
var _counting: Tween
var _time := 0.0
var _jolt := 0.0
var _button_in := false
var _play_in := -1
var _guard_until := 0
var _foe: TextureRect
var _foe_light: ShaderMaterial
var _caption := ""


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene = ShaderMaterial.new()
	_scene.shader = SCENE
	_art.material = _scene
	_root.add_child(_art)
	_panel = Control.new()
	_panel.name = "Sheet"
	_panel.size = DESIGN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_panel.draw.connect(_draw_sheet)
	_root.add_child(_panel)
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_foe = TextureRect.new()
	_foe.name = "Foe"
	_foe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foe.stretch_mode = TextureRect.STRETCH_SCALE
	_foe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The pictures are turned to the left; it faces her sword, on its right.
	_foe.flip_h = true
	_foe_light = ShaderMaterial.new()
	_foe_light.shader = FOE_LIGHT
	_foe_light.set_shader_parameter(&"toward", Vector2(-1.0, 0.7))
	_foe.material = _foe_light
	_foe.hide()
	_panel.add_child(_foe)
	journey = RunJourney.new()
	journey.scale = Vector2.ONE * JOURNEY_SCALE
	_panel.add_child(journey)
	_ending = _line(&"BodyLabel")
	record_label = _line(&"GoldLabel")
	record_label.hide()
	_echo = _line(&"ResultEcho")
	_sparks = Control.new()
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.draw.connect(_draw_sparks)
	_echo.add_child(_sparks)
	_sparks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	total_label = _line(&"MutedLabel")
	_save_note = _line(&"MutedLabel")
	_save_note.hide()
	_boons = Control.new()
	_boons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_boons)
	_boon_name = _line(&"ItemNameLabel")
	_boon_rank = _line(&"MutedLabel")
	_boon_note = _line(&"DescriptionLabel")
	_boon_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boon_note.max_lines_visible = NOTE_LINES
	_boon_note.size.x = COLUMN_WIDTH
	# The way on, at the lower right.
	_button = HubUI.primary_action(_panel, tr("新しい探索を始める"), func(): again_requested.emit())
	_button.position = BUTTON_RECT.position
	_button.size = BUTTON_RECT.size
	retry_button = HubUI.button(_panel, tr("もう一度挑む"), func(): retry_requested.emit())
	retry_button.position = RETRY_RECT.position
	retry_button.size = RETRY_RECT.size
	retry_button.focus_neighbor_right = _button.get_path()
	retry_button.focus_neighbor_left = retry_button.get_path()
	retry_button.focus_neighbor_bottom = retry_button.get_path()
	retry_button.hide()
	seal = TextureRect.new()
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_panel.add_child(seal)
	seal.hide()
	_root.resized.connect(_fit)
	_fit()
	hide()


func _line(role: StringName) -> Label:
	var label := HubUI.label(_panel, "", role)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# The sheet as large as fits the screen, in its middle; the painting covers
# the screen behind it.
func _fit() -> void:
	if _panel == null:
		return
	var zoom := minf(_root.size.x / DESIGN.x, _root.size.y / DESIGN.y)
	_panel.scale = Vector2.ONE * zoom
	_panel.position = ((_root.size - DESIGN * zoom) * 0.5).round()


func _colour(name: StringName, alpha: float = 1.0) -> Color:
	var colour := _root.get_theme_color(name, &"Verdict")
	return Color(colour.r, colour.g, colour.b, colour.a * alpha)


func _size(name: StringName) -> int:
	return _root.get_theme_font_size(name, &"Verdict")


func _face(name: StringName) -> Font:
	return _root.get_theme_font(name, &"Verdict")


# {cleared, abandoned, record, first_clear, echo_before, layer, layers,
# chapter, chapter_id, step, time, kills, level, build, echo, path,
# fallen_to, moveset, discovered}; `home` names the way on (back to the
# base, or a new run); `retry` offers the same chapter again beside it (the
# base offers it for a run lost or left: it has recorded the run already).
func present(result: Dictionary, home: bool = false, retry: bool = false) -> void:
	var won: bool = result.cleared
	var left: bool = result.get("abandoned", false)
	outcome = &"clear" if won else (&"return" if left else &"defeat")
	_title = tr("踏破") if won else (tr("中断") if left else tr("敗北"))
	var place: String = result.chapter if int(result.get("step", 0)) == 0 else tr("%s（段階%d）") % [result.chapter, int(result.step)]
	_ending.text = "%s　%s" % [place, tr("ボスを撃破した") if won else (tr("第%d層で中断した") if left else tr("第%d層で倒れた")) % (int(result.layer) + 1)]
	_button.text = tr("拠点へ戻る") if home else tr("新しい探索を始める")
	retry_button.visible = retry
	_button.focus_neighbor_left = retry_button.get_path() if retry else _button.get_path()
	_button.focus_neighbor_right = _button.get_path()
	var reached := tr("ボス") if won else tr("第%d層") % (int(result.layer) + 1)
	figures = [[tr("到達"), reached], [tr("戦った時間"), "%d:%02d" % [floori(float(result.time) / 60.0), floori(float(result.time)) % 60]],
		[tr("撃破"), tr("%d体") % result.kills], [tr("レベル"), "Lv %d" % result.level]]
	found.clear()
	var ids: Array = result.get("discovered", [])
	for foe in FoeCatalog.FOES:
		if ids.has(foe.id) or ids.has(String(foe.id)):
			found.append(foe)
	felled_by = result.get("fallen_to") if outcome == &"defeat" else null
	_foe.texture = EnemySprites.codex_portrait(felled_by.visual_id) if felled_by != null else null
	_foe.visible = _foe.texture != null
	_foe.self_modulate = felled_by.tint if felled_by != null else Color.WHITE
	journey.show_run(result)
	# Its line is told on the sheet, at a size that reads.
	journey.caption.hide()
	_caption = journey.caption.text
	_show_build(result.get("build", []))
	_echo_amount = int(result.echo)
	_total_before = int(result.get("echo_before", -1))
	counted = false
	settled = false
	_button_in = false
	_last_tick = -1
	# Saved already; only the numbers count up.
	_echo.text = UIFormat.amount(0)
	_echo.scale = Vector2.ONE * (1.0 if won else QUIET_ECHO)
	total_label.text = _total_text(0)
	total_label.visible = _total_before >= 0
	seal.texture = SEALS[outcome]
	record_label.text = tr("初めての踏破") if result.get("first_clear", false) else (tr("最深到達を更新") if result.get("record", false) else "")
	record_label.hide()
	_stand_hero(won)
	_light_scene()
	show()
	_lay()
	UIMotion.bind_buttons(_panel)
	# Dark and empty until it plays.
	for part: StringName in PARTS:
		_set_part(0.0, part)
	seal.hide()
	_kill_staging()
	_play_in = PLAY_AFTER


# The painting and its light for this outcome, dark before it plays.
func _light_scene() -> void:
	var scene: Dictionary = SCENES[outcome]
	_art.texture = PAINTINGS[outcome]
	for key: String in ["source", "spread", "glow", "glow_reach", "glow_colour", "motes", "embers", "lift", "shade", "shade_reach"]:
		_scene.set_shader_parameter(key, scene[key])
	_scene.set_shader_parameter(&"ember_from", EMBER_FROM)
	_scene.set_shader_parameter(&"light", 0.0)
	_scene.set_shader_parameter(&"flare", 0.0)


# She stands before the door when the run is won, and only then.
func _stand_hero(won: bool) -> void:
	if not won:
		if hero != null:
			hero.queue_free()
			hero = null
		return
	if hero == null:
		hero = LobbyHero.new()
		hero.name = "Hero"
		hero.texture = HERO_TEXTURE
		hero.modulate = HERO_TINT
		hero.rim_right = HERO_RIM_DOOR
		hero.rim_left = HERO_RIM_HALL
		_panel.add_child(hero)
		_panel.move_child(hero, 0)
	var extent := Vector2(HERO_TEXTURE.get_size().aspect(), 1.0) * HERO_HEIGHT
	hero.size = extent
	hero.position = HERO_FEET - Vector2(extent.x * 0.5, extent.y)


# Where everything stands on the sheet, for this outcome and what there is
# to tell. The words' column flows downward: what is not there takes no room.
func _lay() -> void:
	var x := COLUMN_X
	var quiet := outcome != &"clear"
	var title_size := _size(&"title_size" if quiet else &"crown_size")
	var title_face := _face(&"title_font")
	var spacing := title_size * 0.14
	var title_width := 0.0
	for index in _title.length():
		title_width += title_face.get_string_size(_title[index], HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x + (spacing if index < _title.length() - 1 else 0.0)
	var base := 132.0 if quiet else 158.0
	_at = {"title": Vector2(x, base), "title_width": title_width, "title_spacing": spacing}
	var seal_side := SEAL_QUIET if quiet else SEAL_SIZE
	seal.size = Vector2.ONE * seal_side
	seal.pivot_offset = seal.size * 0.5
	seal.position = Vector2(x + title_width + (26.0 if quiet else 40.0), base - title_size * 0.42 - seal_side * 0.5)
	var y := base + 26.0
	_ending.position = Vector2(x + 2.0, y)
	y += 32.0
	if not record_label.text.is_empty():
		record_label.position = Vector2(x + 2.0, y)
		y += 34.0
	y += 14.0
	# Who felled her: named in the column, standing before the sword.
	_at.erase("foe")
	if _foe.texture != null:
		var picture := _foe.texture.get_size()
		var fit := minf(FOE_ROOM.size.x / picture.x, FOE_ROOM.size.y / picture.y)
		var shown := picture * fit
		_at["foe"] = Rect2(Vector2(FOE_ROOM.get_center().x - shown.x * 0.5, FOE_ROOM.end.y - shown.y), shown)
		_foe.size = shown
		_foe.position = (_at.foe as Rect2).position
		_at["foe_words"] = Vector2(x, y)
		y += FOE_WORDS
	_at["rule"] = Vector2(x, y)
	y += 22.0
	# The echo brought home, the purse's new total beside it.
	_at["echo_caption"] = Vector2(x + 2.0, y + 14.0)
	var echo_scale := _echo.scale.x
	var echo_font := _echo.get_theme_font(&"font")
	var echo_size := _echo.get_theme_font_size(&"font_size")
	var echo_high := echo_font.get_height(echo_size) * echo_scale
	_echo.position = Vector2(x, y + 18.0)
	var number_width := echo_font.get_string_size(UIFormat.amount(_echo_amount), HORIZONTAL_ALIGNMENT_LEFT, -1, echo_size).x * echo_scale
	_echo.size = Vector2(number_width / echo_scale + 8.0, echo_font.get_height(echo_size))
	_echo.pivot_offset = Vector2.ZERO
	total_label.position = Vector2(x + number_width + 26.0, y + 18.0 + echo_high - total_label.get_minimum_size().y - echo_high * 0.2)
	_save_note.position = Vector2(x + 2.0, y + 18.0 + echo_high)
	y += 18.0 + echo_high + (26.0 if _save_note.visible else 4.0)
	# The run's figures in a row.
	_at["figures"] = Vector2(x + 2.0, y)
	y += 70.0
	# The foes newly recorded.
	_at.erase("found")
	if not found.is_empty():
		_at["found"] = Vector2(x + 2.0, y)
		y += 76.0
	# The build: its emblems, and the one told under them.
	_at["build"] = Vector2(x + 2.0, y + 14.0)
	_boons.position = Vector2(x - 4.0, y + 22.0)
	var rows := _lay_boons()
	y += 22.0 + rows
	var name_room := _boon_name.get_minimum_size()
	_boon_name.position = Vector2(x + 2.0, y + 2.0)
	_boon_rank.position = Vector2(x + 2.0 + name_room.x + 12.0, y + 2.0 + (name_room.y - _boon_rank.get_minimum_size().y) * 0.5)
	_boon_note.position = Vector2(x + 2.0, y + 2.0 + (name_room.y + 2.0 if _boon_name.visible else 0.0))
	_boon_note.size = Vector2(COLUMN_WIDTH, 0.0)
	journey.position = JOURNEY_AT
	_panel.queue_redraw()


# The emblems in rows; how high they stand.
func _lay_boons() -> float:
	if _boon_cells.is_empty():
		return 0.0
	var grid: Array = BOON_GRIDS[-1]
	for candidate: Array in BOON_GRIDS:
		if _boon_cells.size() <= int(candidate[0]):
			grid = candidate
			break
	var columns: int = grid[2]
	var cell := _boon_cells[0].custom_minimum_size
	for index in _boon_cells.size():
		_boon_cells[index].position = Vector2(index % columns, index / columns) * (cell + Vector2.ONE * BOON_GAP)
		_boon_cells[index].size = cell
	var rows := (_boon_cells.size() - 1) / columns + 1
	return rows * (cell.y + BOON_GAP)


func _total_text(counted_so_far: int) -> String:
	return tr("所持 残響 %s") % UIFormat.amount(_total_before + counted_so_far)


# The scene plays: each part comes in at its time; the win's seal is
# stamped, the others' drawn in quietly; the echo counts once it is in.
func _play() -> void:
	var scene: Dictionary = SCENES[outcome]
	_play_in = -1
	_time = 0.0
	_kill_staging()
	_staging = create_tween().set_parallel(true).set_ignore_time_scale(true)
	_staging.tween_method(_set_light, 0.0, 1.0, float(scene.light)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if outcome != &"defeat" else Tween.EASE_IN_OUT)
	for part: StringName in [&"title", &"place", &"foe", &"echo", &"figures", &"found", &"build", &"journey", &"button"]:
		if scene.has(String(part)):
			var times: Array = scene[String(part)]
			_staging.tween_method(_set_part.bind(part), 0.0, 1.0, float(times[1])).set_delay(float(times[0])).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var last: Array = scene.button
	_staging.tween_callback(_on_button_in).set_delay(float(last[0]) + float(last[1]))
	match outcome:
		&"clear":
			GameAudio.play(self, &"result_dawn", -9.0)
			_staging.tween_method(_set_part.bind(&"hero"), 0.0, 1.0, float(HERO_IN[1])).set_delay(float(HERO_IN[0])).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_stamp()
		&"defeat":
			GameAudio.play(self, &"result_fall", -8.0)
			_draw_in_seal(scene.seal)
			_staging.tween_callback(_count).set_delay(float(scene.echo[0]))
		_:
			GameAudio.play(self, &"result_return", -10.0)
			_draw_in_seal(scene.seal)
			_staging.tween_callback(_count).set_delay(float(scene.echo[0]))


func _kill_staging() -> void:
	for playing: Tween in [_staging, _stamping, _counting]:
		if playing != null:
			playing.kill()
	_staging = null
	_stamping = null
	_counting = null


func _set_light(value: float) -> void:
	_scene.set_shader_parameter(&"light", value)


# How far a part of the scene is in (0 to 1): the words drawn on the sheet
# read it as they are drawn, and the controls of the part follow it.
func _set_part(value: float, part: StringName) -> void:
	_parts[part] = value
	match part:
		&"place":
			_ending.modulate.a = value
		&"echo":
			_echo.modulate.a = value
			total_label.modulate.a = value
			_save_note.modulate.a = value
		&"build":
			_boons.modulate.a = value
			_boon_name.modulate.a = value
			_boon_rank.modulate.a = value
			_boon_note.modulate.a = value
		&"journey":
			journey.modulate.a = value
		&"foe":
			_foe_light.set_shader_parameter(&"shown", value)
			if _at.has("foe"):
				_foe.position.y = (_at.foe as Rect2).position.y + FOE_RISE * (1.0 - value)
		&"button":
			_button.modulate.a = value
			retry_button.modulate.a = value
		&"hero":
			if hero != null:
				hero.modulate.a = value
				hero.position.x = HERO_FEET.x - hero.size.x * 0.5 + HERO_STEP * (1.0 - value)
	_panel.queue_redraw()


func _part(part: StringName) -> float:
	return _parts.get(part, 1.0)


# The win's seal drops beside the word, then the record, if any.
func _stamp() -> void:
	seal.scale = Vector2.ONE * 2.4
	seal.rotation = SEAL_TURN * 2.0
	seal.modulate.a = 0.0
	seal.show()
	_stamping = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_ignore_time_scale(true)
	_stamping.tween_property(seal, "scale", Vector2.ONE, STAMP_TIME).set_delay(STAMP_DELAY)
	_stamping.tween_property(seal, "rotation", SEAL_TURN, STAMP_TIME).set_delay(STAMP_DELAY)
	_stamping.tween_property(seal, "modulate:a", 1.0, STAMP_TIME * 0.5).set_delay(STAMP_DELAY)
	_stamping.chain().tween_callback(_landed)


# A run not won: its seal is not struck, only drawn in beside the word.
func _draw_in_seal(times: Array) -> void:
	seal.scale = Vector2.ONE
	seal.rotation = SEAL_TURN
	seal.modulate.a = 0.0
	seal.show()
	_stamping = create_tween().set_ignore_time_scale(true)
	_stamping.tween_property(seal, "modulate:a", 0.86, float(times[1])).set_delay(float(times[0]))
	_stamping.tween_callback(_tell_record)


func _landed() -> void:
	GameAudio.play(self, &"heavy", -14.0)
	# The word takes the blow.
	create_tween().set_ignore_time_scale(true).tween_method(_set_jolt, 1.0, 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_set_part(1.0, &"echo")
	_tell_record()
	_count()


func _set_jolt(value: float) -> void:
	_jolt = value
	_panel.queue_redraw()


# What the run reached or opened, told in gold.
func _tell_record() -> void:
	if record_label.text.is_empty() or record_label.visible:
		return
	record_label.modulate.a = 1.0
	record_label.show()
	UIMotion.of(record_label).appear(0.0, UIMotion.WINDOW_TIME)
	# The flash once it is in: a flash keeps the alpha it starts from.
	create_tween().tween_callback(func(): UIMotion.of(record_label).flash(1.4, UIMotion.GOLD_TIME)).set_delay(UIMotion.WINDOW_TIME)


# How long the echo counts: longer for more, within COUNT_TIME; a run not
# won counts quickly.
func count_time() -> float:
	if outcome != &"clear":
		return QUIET_COUNT
	return clampf(COUNT_TIME.x + _echo_amount / 250.0, COUNT_TIME.x, COUNT_TIME.y)


func _count() -> void:
	if counted:
		return
	if _echo_amount <= 0:
		_counted()
		return
	_counting = create_tween().set_ignore_time_scale(true)
	_counting.tween_interval(COUNT_DELAY)
	_counting.tween_method(_count_to, 0.0, 1.0, count_time()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_counting.tween_callback(_counted)


func _count_to(progress: float) -> void:
	var value := roundi(_echo_amount * progress)
	_echo.text = UIFormat.amount(value)
	total_label.text = _total_text(value)
	# A tick at each step of the way, climbing as it goes.
	var tick := floori(progress * COUNT_TICKS)
	if tick != _last_tick and progress < 1.0:
		_last_tick = tick
		if outcome == &"clear":
			GameAudio.play(self, &"pickup", -24.0, lerpf(TICK_PITCH.x, TICK_PITCH.y, progress))
		elif tick % 3 == 0:
			GameAudio.play(self, &"result_tally", -22.0)


# The count is done. A run won: the number pulses and flashes, sparks fly,
# the door's light flares, a chime, and she smiles.
func _counted(quietly: bool = false) -> void:
	var first := not counted
	counted = true
	_echo.text = UIFormat.amount(_echo_amount)
	total_label.text = _total_text(_echo_amount)
	if first and not quietly and outcome == &"clear" and _echo_amount > 0:
		_echo.pivot_offset = _echo.size * 0.5
		UIMotion.of(_echo).pulse(1.05, UIMotion.GOLD_TIME * 2.0)
		UIMotion.of(_echo).flash(1.5, UIMotion.GOLD_TIME * 2.0)
		GameAudio.play(self, &"level_up", -16.0)
		_spark_dirs.clear()
		for index in SPARKS:
			var angle := TAU * index / SPARKS + randf_range(-0.15, 0.15)
			_spark_dirs.append(Vector2.from_angle(angle) * randf_range(SPARK_REACH.x, SPARK_REACH.y))
		create_tween().tween_method(_spark, 0.0, 1.0, SPARK_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		create_tween().tween_method(func(value: float): _scene.set_shader_parameter(&"flare", value), 0.7, 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if hero != null:
			hero.react()
	_arrive()


func _on_button_in() -> void:
	_button_in = true
	_arrive()


# The whole scene is in (its last part, and the echo counted): the way on
# takes presses from a moment after.
func _arrive() -> void:
	if settled or not _button_in or not counted or not visible:
		return
	settled = true
	_guard_until = Time.get_ticks_msec() + roundi(LEAVE_GUARD * 1000.0)
	_button.grab_focus()


# All of the scene at once: what a press does while it is still playing.
func settle() -> void:
	if settled or not visible:
		return
	_play_in = -1
	_kill_staging()
	for part: StringName in PARTS:
		_set_part(1.0, part)
	_set_light(1.0)
	_set_jolt(0.0)
	seal.scale = Vector2.ONE
	seal.rotation = SEAL_TURN
	seal.modulate.a = 1.0 if outcome == &"clear" else 0.86
	seal.show()
	_tell_record()
	_counted(true)
	_button_in = true
	_arrive()


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


func _process(delta: float) -> void:
	if not visible:
		return
	if _play_in > 0:
		_play_in -= 1
		if _play_in == 0:
			_play()
		return
	_time += delta
	_scene.set_shader_parameter(&"time", _time)
	if _foe.visible:
		_foe_light.set_shader_parameter(&"breath", 0.5 + 0.5 * sin(_time * 2.3))


func _words(at: Vector2, text: String, face: StringName, size: StringName, colour: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	_panel.draw_string(_face(face), at, text, align, width, _size(size), colour)


# What is drawn on the sheet itself: the word, the captions, the figures,
# the foes newly recorded, and who felled her.
func _draw_sheet() -> void:
	if _at.is_empty():
		return
	# Her shadow on the hall's floor, under her feet.
	if hero != null:
		_panel.draw_set_transform(HERO_FEET + Vector2(8.0, -10.0), 0.0, Vector2(1.0, HERO_SHADOW.y / HERO_SHADOW.x))
		for ring in 6:
			_panel.draw_circle(Vector2.ZERO, HERO_SHADOW.x * (0.45 + 0.11 * ring), _colour(&"shade", 0.13 * _part(&"hero")))
		_panel.draw_set_transform(Vector2.ZERO)
	_draw_title()
	if _at.has("foe_words"):
		_draw_foe()
	# The way the run went: its line, under the stage it ended on.
	var walked := _part(&"journey")
	if not _caption.is_empty() and not journey.spots.is_empty():
		var face := _face(&"font")
		var room := face.get_string_size(_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, _size(&"cap_size")).x
		var middle := JOURNEY_AT.x + journey.spots[journey.ended_at].x * JOURNEY_SCALE
		var left := clampf(middle - room * 0.5, JOURNEY_AT.x, JOURNEY_AT.x + RunJourney.WIDTH * JOURNEY_SCALE - room)
		_words(Vector2(left, JOURNEY_AT.y + RunJourney.HEIGHT * JOURNEY_SCALE + 2.0), _caption, &"font", &"cap_size", _colour(&"pale", walked))
	var plain := _part(&"echo")
	var caption := _colour(&"ash" if outcome == &"defeat" else &"dim")
	# A hairline over what is brought home, fading to the right.
	var rule: Vector2 = _at.rule
	_panel.draw_polyline_colors(PackedVector2Array([rule, rule + Vector2(COLUMN_WIDTH * 0.5, 0.0), rule + Vector2(COLUMN_WIDTH, 0.0)]),
		PackedColorArray([_colour(_accent(), 0.7 * plain), _colour(_accent(), 0.4 * plain), _colour(_accent(), 0.0)]), 1.5, true)
	HubUI.mark(_panel, rule, 4.0, _colour(_accent(), plain))
	_words(_at.echo_caption, tr("持ち帰った残響"), &"font", &"label_size", Color(caption, caption.a * plain))
	# The figures: a small caption over each value.
	var shown := _part(&"figures")
	var from: Vector2 = _at.figures
	var step := COLUMN_WIDTH / figures.size()
	for index in figures.size():
		var rise := (1.0 - clampf(shown * 1.6 - index * 0.2, 0.0, 1.0))
		var at := from + Vector2(step * index, 8.0 * rise)
		var alpha := 1.0 - rise
		_words(at + Vector2(0.0, 14.0), figures[index][0], &"font", &"cap_size", Color(caption, caption.a * alpha))
		_words(at + Vector2(0.0, 46.0), figures[index][1], &"lead_font", &"value_size", _colour(&"pale", alpha))
	# The foes newly recorded: their icons, and how many.
	if _at.has("found"):
		var told := _part(&"found")
		var at: Vector2 = _at.found
		_words(at + Vector2(0.0, 14.0), tr("新たに記録した魔物"), &"font", &"cap_size", _colour(&"gold", told))
		var icon_x := at.x
		for index in mini(found.size(), FOUND_SHOWN):
			var icon := FoeIcon.of(found[index].visual_id, true, found[index].tint)
			var come := clampf(told * 1.8 - index * 0.12, 0.0, 1.0)
			if icon != null:
				_panel.draw_texture_rect(icon, Rect2(icon_x, at.y + 24.0 + 6.0 * (1.0 - come), FOUND_SIZE, FOUND_SIZE), false, Color(1.0, 1.0, 1.0, come))
			_panel.draw_arc(Vector2(icon_x + FOUND_SIZE * 0.5, at.y + 24.0 + FOUND_SIZE * 0.5 + 6.0 * (1.0 - come)), FOUND_SIZE * 0.5 + 1.0, 0.0, TAU, 40, _colour(&"gold", 0.55 * come), 1.5, true)
			icon_x += FOUND_SIZE + 8.0
		var count := tr("%d体") % found.size() if found.size() <= FOUND_SHOWN else tr("ほか%d体") % (found.size() - FOUND_SHOWN)
		_words(Vector2(icon_x + 6.0, at.y + 24.0 + FOUND_SIZE * 0.5 + 6.0), count, &"font", &"note_size", _colour(&"pale", told))
	_words(_at.build, tr("取得した強化"), &"font", &"cap_size", Color(caption, caption.a * _part(&"build")))


func _accent() -> StringName:
	match outcome:
		&"defeat":
			return &"ember"
		&"return":
			return &"steel"
	return &"gold"


# The word: struck in at once when the run is won (it comes down onto the
# sheet, and takes the seal's blow), drawn in slowly when it is not.
func _draw_title() -> void:
	var shown := _part(&"title")
	if shown <= 0.0:
		return
	var quiet := outcome != &"clear"
	var size := _size(&"title_size" if quiet else &"crown_size")
	var face := _face(&"title_font")
	var at: Vector2 = _at.title
	var width: float = _at.title_width
	var spacing: float = _at.title_spacing
	var colour := _colour(_accent(), shown)
	var middle := at + Vector2(width * 0.5, -size * 0.38)
	var grown := 1.0 if quiet else lerpf(1.22, 1.0, shown)
	# A word not won settles in from a little apart.
	var apart := (1.0 - shown) * size * 0.16 if quiet else 0.0
	_panel.draw_set_transform(middle + Vector2(0.0, _jolt * 5.0), 0.0, Vector2.ONE * grown)
	var x := -width * 0.5 - apart * (_title.length() - 1) * 0.5
	for index in _title.length():
		var letter := _title[index]
		# A dark under it, so it stands off the painting.
		_panel.draw_string(face, Vector2(x + 2.0, size * 0.38 + 3.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _colour(&"shade", 0.6 * shown))
		_panel.draw_string(face, Vector2(x, size * 0.38), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
		x += face.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing + apart
	_panel.draw_set_transform(Vector2.ZERO)
	# A line under it, out from its start.
	var under := at + Vector2(0.0, 12.0)
	var reach := (width + 30.0) * clampf(shown * 1.4, 0.0, 1.0)
	_panel.draw_polyline_colors(PackedVector2Array([under, under + Vector2(reach * 0.6, 0.0), under + Vector2(reach, 0.0)]),
		PackedColorArray([_colour(_accent(), 0.9 * shown), _colour(_accent(), 0.6 * shown), _colour(_accent(), 0.0)]), 2.0, true)


# Who felled her (its picture stands over her sword, lit by the embers):
# its shadow on the floor, and in the column its name, its kind, and where
# its ways can be studied.
func _draw_foe() -> void:
	var shown := _part(&"foe")
	if shown <= 0.0 or felled_by == null:
		return
	if _at.has("foe"):
		var rect: Rect2 = _at.foe
		var foot := Vector2(rect.get_center().x, rect.end.y - 6.0)
		_panel.draw_set_transform(foot, 0.0, Vector2(1.0, 0.14))
		for ring in 6:
			_panel.draw_circle(Vector2.ZERO, rect.size.x * (0.26 + 0.06 * ring), _colour(&"shade", 0.2 * shown))
		_panel.draw_set_transform(Vector2.ZERO)
	var words: Vector2 = _at.foe_words
	var told := clampf(shown * 1.5 - 0.5, 0.0, 1.0)
	_words(words + Vector2(2.0, 14.0), tr("倒された相手"), &"font", &"cap_size", _colour(&"ash", told))
	_words(words + Vector2(0.0, 52.0), tr(felled_by.display_name), &"title_font", &"name_size", _colour(&"pale", told))
	var kind := FoeCatalog.kind_name(felled_by)
	_words(words + Vector2(2.0, 78.0), kind, &"font", &"label_size", _colour(&"dim", told))
	_words(words + Vector2(2.0, 102.0), tr("図鑑の「観察」で、動きと攻撃を確かめられます。"), &"font", &"label_size", _colour(&"faint", told))


# The build: each boon an emblem in a socket, its rank at the lower right as
# the HUD's row shows it; pointing at one or focusing it tells it under the
# emblems. Up from the way on goes into them, down from their last row back.
func _show_build(build: Array) -> void:
	for child in _boons.get_children():
		child.free()
	_boon_cells.clear()
	_button.focus_neighbor_top = NodePath()
	_boons.visible = not build.is_empty()
	_boon_name.visible = not build.is_empty()
	_boon_rank.visible = not build.is_empty()
	_boon_name.text = ""
	_boon_rank.text = ""
	_boon_note.text = tr(NO_BOONS)
	var grid: Array = BOON_GRIDS[-1]
	for candidate: Array in BOON_GRIDS:
		if build.size() <= int(candidate[0]):
			grid = candidate
			break
	var columns: int = grid[2]
	for entry: Array in build:
		var boon: BoonData = entry[0]
		var rank: int = entry[1]
		var cell := EquipSocket.new(float(grid[1]))
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
		var column := index % columns
		cell.focus_neighbor_left = _boon_cells[index - 1].get_path() if column > 0 else cell.get_path()
		cell.focus_neighbor_right = _boon_cells[index + 1].get_path() if column < columns - 1 and index < last else cell.get_path()
		cell.focus_neighbor_top = _boon_cells[index - columns].get_path() if index >= columns else cell.get_path()
		var below := index + columns
		if below > last and index / columns < last / columns:
			below = last
		cell.focus_neighbor_bottom = _boon_cells[below].get_path() if below <= last else _button.get_path()
	if not build.is_empty():
		_button.focus_neighbor_top = _boon_cells[0].get_path()
		_tell_boon(build[0][0], build[0][1], _boon_cells[0])


# The boon's name, rank and what it does, under the emblems; its socket
# keeps a quiet gold ring, and the way up from the button returns to it.
func _tell_boon(boon: BoonData, rank: int, cell: EquipSocket) -> void:
	for other in _boon_cells:
		other.lit = other == cell
	_boon_name.text = tr(boon.display_name)
	_boon_rank.text = "" if boon.max_level == 1 else "Lv %d / %d" % [rank, boon.max_level]
	_boon_note.text = boon.effect_description(rank)
	_button.focus_neighbor_top = cell.get_path()
	# The rank stands after the name, however long the name is.
	if not _at.is_empty():
		var name_room := _boon_name.get_minimum_size()
		_boon_name.size = name_room
		_boon_rank.position = Vector2(_boon_name.position.x + name_room.x + 12.0, _boon_name.position.y + (name_room.y - _boon_rank.get_minimum_size().y) * 0.5)


# What the recorded run opened (a difficulty step), told in gold with the
# record. Called as the scene starts.
func tell_opened(text: String) -> void:
	record_label.text = text if record_label.text.is_empty() else "%s　%s" % [record_label.text, text]
	if visible:
		_lay()
		if settled:
			_tell_record()


# Whether the result was saved; shown only when there is something to say.
func show_save_status(text: String, alert: bool) -> void:
	_save_note.text = text
	_save_note.visible = alert
	if visible:
		_lay()


# A press of the way on's kind: Enter, the pad's button, a click.
func _is_go(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey and event.echo:
		return false
	return event.is_action_pressed(&"ui_accept") or (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER])


# While the scene plays, a press brings all of it in; just after, it does
# nothing, so two quick presses do not leave the result unread.
func _input(event: InputEvent) -> void:
	if not visible or not _is_go(event):
		return
	if not settled:
		get_viewport().set_input_as_handled()
		settle()
	elif Time.get_ticks_msec() < _guard_until:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not settled:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		again_requested.emit()
