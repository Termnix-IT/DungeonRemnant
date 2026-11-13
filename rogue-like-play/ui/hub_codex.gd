class_name HubCodex
extends Control

# The encyclopedia of foes (FoeCatalog), laid out as many games' bestiaries
# are: on the left, the kind tabs (all, the crowd, elites, bosses), how many
# have been met, and a list to scroll, a row for each foe with its round
# face icon and its name (FoeRow, FoeIcon); on the right, the foe chosen,
# its account in a column (name, kind, how it fights, its figures) beside a
# stage where the foe itself stands large, its painted portrait breathing
# (its rig braced where none is painted), facing the account. A foe counts as met once it has come into an area in
# a run (MetaProgress.met); the others show as shades named "？？？", their
# kind alone told. Nothing here changes the progress.

const UNKNOWN_NAME := "？？？"
const UNKNOWN_NOTE := "まだ出会っていない敵。探索で戦場に現れると記録される。"
const SHADOW := Color(0.0, 0.0, 0.0, 0.85)
const ROW_HEIGHT := 68.0
const STAT_MARKER := 14.0
const STAT_ROW_HEIGHT := 44.0
# The icon at the head of each figure's row, this many px square.
const STAT_ICON := 26.0
const STAT_ICON_PATH := "res://art/ui/stat_%s.png"
# How tall a foe stands on the stage, as a share of its height, by kind (the
# crowd, elites, bosses): a boss looms over a rat, as in the fight.
const FIGURE_SHARE: Array[float] = [0.7, 0.62, 0.74, 0.86]
# No figure is wider than this share of the stage.
const FIGURE_WIDTH := 0.9
# The ground the figure stands on, this far above the stage's foot.
const FLOOR_INSET := 56.0
# A painted portrait breathes: at the top of a breath it is this much
# narrower and taller (from its feet), a breath lasting BREATH_TIME seconds.
const BREATH := Vector2(0.996, 1.012)
const BREATH_TIME := 3.2

var meta: MetaProgress
var kind_tabs: CategoryTabs
var count_label: Label
var cards: Array[FoeRow] = []
var rows: Array[FoeData] = []
var stage: Control
var name_label: Label
var kind_label: Label
# The met foe's figures, a row each (empty for one not met).
var stats: VBoxContainer
var description_label: Label
var selected := 0
var _list: VBoxContainer
var _scroll: ScrollContainer
var _catalog: VBoxContainer
var _info: VBoxContainer
var _stats_heading: Control
var _figure: Node2D
var _breath: Tween
var _unknown := false
# The foe the column tells now: choosing it again (a click lands as a focus
# and a press) neither redraws nor slides the column.
var _shown: FoeData
# Tile pictures (and silhouettes of the foes not met), made once.
static var _tiles: Dictionary = {}


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catalog = HubUI.open_column(columns, 1.0, &"SlabSolid")
	kind_tabs = CategoryTabs.new()
	_catalog.add_child(kind_tabs)
	kind_tabs.setup(FoeCatalog.KINDS)
	kind_tabs.changed.connect(func(_index: int):
		_show_rows()
		UIMotion.of(_list).appear(0.0, UIMotion.WINDOW_TIME)
		focus_first())
	count_label = HubUI.label(_catalog, "", &"NoteLabel")
	# More rows than the column holds scroll within it, and the row the focus
	# lands on is drawn into view.
	_scroll = ScrollContainer.new()
	_scroll.name = "Rows"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_catalog.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.theme_type_variation = &"CodexList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	# The right column: the account beside the stage.
	var right := HubUI.open_column(columns, 2.1, &"SlabSolidEnd")
	var right_panel := right.get_parent() as Control
	right_panel.clip_contents = true
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"CodexInfoMargin"
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(margin)
	var split := HBoxContainer.new()
	split.theme_type_variation = &"CodexSplit"
	margin.add_child(split)
	_info = VBoxContainer.new()
	_info.theme_type_variation = &"CodexAccount"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_stretch_ratio = 1.0
	split.add_child(_info)
	name_label = HubUI.label(_info, "", &"CodexName")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var kind_row := HBoxContainer.new()
	kind_row.theme_type_variation = &"CodexLine"
	_info.add_child(kind_row)
	_marker(kind_row)
	_line_label(kind_row, tr("分類"), &"NoteLabel")
	kind_label = _line_label(kind_row, "", &"BodyLabel")
	HubUI.rule(_info)
	description_label = HubUI.label(_info, "", &"DescriptionLabel")
	# The figures stand at the column's foot whatever the account's length, so
	# they keep their place from foe to foe; their last line runs level with
	# the ground the foe stands on.
	HubUI.space(_info)
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"CodexLine"
	_info.add_child(heading)
	_marker(heading)
	_line_label(heading, tr("基本情報"), &"CodexSection")
	_stats_heading = heading
	stats = VBoxContainer.new()
	stats.theme_type_variation = &"CodexStats"
	_info.add_child(stats)
	var foot := Control.new()
	foot.custom_minimum_size.y = maxf(0.0, FLOOR_INSET - _info.get_theme_constant(&"separation"))
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(foot)
	stage = Control.new()
	stage.name = "Stage"
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = 1.15
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = true
	stage.draw.connect(_draw_stage)
	stage.resized.connect(_place_figure)
	split.add_child(stage)
	visibility_changed.connect(_still_when_hidden)


func refresh(current: MetaProgress) -> void:
	meta = current
	_show_rows()


func _show_rows() -> void:
	if meta == null:
		return
	for card in cards:
		card.free()
	cards.clear()
	rows.clear()
	_shown = null
	var met := 0
	for foe in FoeCatalog.FOES:
		var known := meta.has_met(foe.id)
		if known:
			met += 1
		if kind_tabs.selected > 0 and FoeCatalog.kind_of(foe) != kind_tabs.selected:
			continue
		rows.append(foe)
		cards.append(_card(foe, known))
	count_label.text = tr("出会った敵  %d / %d") % [met, FoeCatalog.FOES.size()]
	_scroll.scroll_vertical = 0
	if not rows.is_empty():
		_select(0, false)


func _card(foe: FoeData, known: bool) -> FoeRow:
	var card := FoeRow.new()
	card.custom_minimum_size.y = ROW_HEIGHT
	card.text = tr(foe.display_name) if known else tr(UNKNOWN_NAME)
	card.unknown = not known
	card.icon_texture = FoeIcon.of(foe.visual_id, known, foe.tint)
	var index := cards.size()
	card.pressed.connect(_select.bind(index))
	card.focus_entered.connect(_select.bind(index))
	# Left and right lead nowhere from the list.
	card.focus_neighbor_left = card.get_path_to(card)
	card.focus_neighbor_right = card.get_path_to(card)
	_list.add_child(card)
	return card


# The foe's picture for its tile, or its dark silhouette: always a square
# the figure fills, standing on its bottom edge, so every tile lays its picture
# and its name out alike whatever the figure's shape. A foe drawn in a tint
# of its own (a kin sharing another's rig) is shown in it. The departure's
# foes and the route map's are drawn with it.
static func tile_picture(visual_id: String, known: bool, tint: Color = Color.WHITE) -> Texture2D:
	var key := "%s:%s:%s" % [visual_id, known, tint.to_html()]
	if _tiles.has(key):
		return _tiles[key]
	var shown := EnemySprites.portrait(visual_id)
	if shown.is_empty():
		return null
	var image := (shown.texture as Texture2D).get_image()
	if image == null:
		return null
	image.decompress()
	image = image.get_region(Rect2i(shown.region))
	image.convert(Image.FORMAT_RGBA8)
	# Trimmed to the figure, so a small foe fills its tile as a large one does.
	var used := image.get_used_rect()
	if used.has_area():
		image = image.get_region(used)
	if not known:
		for y in image.get_height():
			for x in image.get_width():
				var alpha := image.get_pixel(x, y).a
				image.set_pixel(x, y, Color(SHADOW, alpha * SHADOW.a))
	elif tint != Color.WHITE:
		for y in image.get_height():
			for x in image.get_width():
				image.set_pixel(x, y, image.get_pixel(x, y) * tint)
	var side := maxi(image.get_width(), image.get_height())
	var square := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	square.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((side - image.get_width()) / 2, side - image.get_height()))
	_tiles[key] = ImageTexture.create_from_image(square)
	return _tiles[key]


func _select(place: int, animate: bool = true) -> void:
	if place < 0 or place >= rows.size():
		return
	selected = place
	for index in cards.size():
		cards[index].chosen = index == place
	var foe := rows[place]
	if animate and foe == _shown:
		return
	_shown = foe
	_unknown = not meta.has_met(foe.id)
	kind_label.text = FoeCatalog.kind_name(foe)
	for child in stats.get_children():
		child.free()
	_stats_heading.visible = not _unknown
	if _unknown:
		name_label.text = tr(UNKNOWN_NAME)
		description_label.text = tr(UNKNOWN_NOTE)
	else:
		name_label.text = tr(foe.display_name)
		for row: Array in [["hp", "HP", str(foe.max_hp)], ["contact", tr("ぶつかる力"), str(foe.contact_damage)], ["speed", tr("速さ"), str(roundi(foe.speed))]]:
			_stat_row(row[0], row[1], row[2])
		description_label.text = tr(foe.description)
	_stand(foe)
	if animate:
		UIMotion.of(_info).slide_in()
		UIMotion.of(stage).appear(0.0, UIMotion.WINDOW_TIME)


# One of the foe's figures: its icon (art/ui/stat_<icon>.png, cut by
# tools/build_stat_icons.py), its name, its value at the right, and a
# hairline under it.
func _stat_row(icon: String, title: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"CodexLine"
	row.custom_minimum_size.y = STAT_ROW_HEIGHT
	row.draw.connect(func():
		var line := row.get_theme_color(&"separator", &"CodexRow")
		row.draw_line(Vector2(0, row.size.y - 0.5), Vector2(row.size.x, row.size.y - 0.5), line, -1.0))
	stats.add_child(row)
	var mark := TextureRect.new()
	mark.name = "Icon"
	mark.texture = load(STAT_ICON_PATH % icon)
	mark.custom_minimum_size = Vector2(STAT_ICON, STAT_ICON)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	var name := HubUI.label(row, title, &"BodyLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var figure := HubUI.label(row, value, &"ValueLabel")
	figure.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label: Label in [name, figure]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# A short label in a line of its own: it keeps to one line.
func _line_label(parent: Node, text: String, role: StringName) -> Label:
	var label := HubUI.label(parent, text, role)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _marker(parent: Node) -> void:
	var marker := Control.new()
	marker.custom_minimum_size = Vector2(STAT_MARKER, STAT_MARKER)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(func(): HubUI.diamond(marker, marker.size * 0.5, 4.0, marker.get_theme_color(&"rail", &"HubLobby")))
	parent.add_child(marker)


# The foe on the stage: its rig braced and facing the account, as tall as
# its kind stands (FIGURE_SHARE) and no wider than the stage; a shade for one
# not met. Its picture where it has no rig.
func _stand(foe: FoeData) -> void:
	if _figure != null:
		_figure.free()
		_figure = null
	_figure = Node2D.new()
	_figure.name = "Figure"
	_figure.scale = Vector2(-1.0, 1.0)
	stage.add_child(_figure)
	var path := EnemySprites.rig_path(foe.visual_id)
	var portrait := EnemySprites.codex_portrait(foe.visual_id)
	if portrait != null:
		# Painted already facing the account; it breathes, rising a little
		# from its feet.
		_figure.scale = Vector2.ONE
		var sprite := Sprite2D.new()
		sprite.name = "Portrait"
		sprite.texture = portrait
		sprite.centered = false
		sprite.offset = Vector2(-portrait.get_width() * 0.5, -portrait.get_height())
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.modulate = foe.tint
		_figure.add_child(sprite)
	elif ResourceLoader.exists(path):
		var rig: CharacterRig = (load(path) as PackedScene).instantiate()
		rig.modulate = foe.tint
		_figure.add_child(rig)
		if rig.is_node_ready():
			rig.braced = true
		else:
			rig.ready.connect(func(): rig.braced = true, CONNECT_ONE_SHOT)
	else:
		var picture := HubCodex.tile_picture(foe.visual_id, true, foe.tint)
		if picture != null:
			var sprite := Sprite2D.new()
			sprite.texture = picture
			sprite.centered = false
			sprite.offset = Vector2(-picture.get_width() * 0.5, -picture.get_height())
			_figure.add_child(sprite)
	_figure.modulate = SHADOW if _unknown else Color.WHITE
	_still_when_hidden()
	_place_figure()


func _place_figure() -> void:
	if _figure == null or _shown == null or stage.size.y <= 0.0:
		return
	var tall := (stage.size.y - FLOOR_INSET) * FIGURE_SHARE[FoeCatalog.kind_of(_shown)]
	var portrait := EnemySprites.codex_portrait(_shown.visual_id)
	var shown := EnemySprites.illustration(_shown.visual_id)
	var region := Rect2()
	if portrait != null:
		region = Rect2(Vector2.ZERO, portrait.get_size())
	elif not shown.is_empty():
		region = shown.region
	if region.has_area():
		var aspect := region.size.x / maxf(1.0, region.size.y)
		tall = minf(tall, stage.size.x * FIGURE_WIDTH / maxf(0.01, aspect))
	_figure.position = Vector2(stage.size.x * 0.5, stage.size.y - FLOOR_INSET)
	var rig := _figure.get_child(0) if _figure.get_child_count() > 0 else null
	if rig is CharacterRig:
		(rig as CharacterRig).world_height = tall
	elif rig is Sprite2D:
		var sprite := rig as Sprite2D
		sprite.scale = Vector2.ONE * tall / maxf(1.0, sprite.texture.get_height())
	stage.queue_redraw()


# The stage: a soft warm light behind where the foe stands, and its shadow
# on the ground.
func _draw_stage() -> void:
	var ground := Vector2(stage.size.x * 0.5, stage.size.y - FLOOR_INSET)
	var reach := minf(stage.size.x, stage.size.y) * 0.55
	var light := _soft_disc(stage.get_theme_color(&"glow", &"CodexStage"))
	stage.draw_texture_rect(light, Rect2(ground - Vector2(reach, reach * 1.85), Vector2(reach, reach) * 2.0), false)
	var shade := _soft_disc(stage.get_theme_color(&"floor", &"CodexStage"))
	var floor_size := Vector2(reach * 1.3, reach * 0.26)
	stage.draw_texture_rect(shade, Rect2(ground - floor_size * 0.5, floor_size), false)


# A disc of `color` fading smoothly to nothing at its rim, made once per
# colour.
static var _discs: Dictionary = {}


static func _soft_disc(color: Color) -> Texture2D:
	var key := color.to_html()
	if not _discs.has(key):
		var gradient := Gradient.new()
		gradient.set_color(0, color)
		gradient.set_color(1, Color(color, 0.0))
		gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
		var disc := GradientTexture2D.new()
		disc.gradient = gradient
		disc.fill = GradientTexture2D.FILL_RADIAL
		disc.fill_from = Vector2(0.5, 0.5)
		disc.fill_to = Vector2(1.0, 0.5)
		disc.width = 256
		disc.height = 256
		_discs[key] = disc
	return _discs[key]


# The foe on the stage stands still while the page is hidden.
# A portrait's breath ends there and starts again when the page is shown.
# The breath is the page's tween, not the figure's: a tween bound to a node
# that cannot process is never cleared, even once killed.
func _still_when_hidden() -> void:
	if _breath != null:
		_breath.kill()
		_breath = null
	if _figure == null:
		return
	var shown := is_visible_in_tree()
	_figure.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	if _figure.has_node(^"Portrait"):
		_figure.scale = Vector2.ONE
		if shown:
			_breath = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_breath.tween_property(_figure, ^"scale", BREATH, BREATH_TIME * 0.5)
			_breath.tween_property(_figure, ^"scale", Vector2.ONE, BREATH_TIME * 0.5)


func focus_first() -> void:
	if not cards.is_empty():
		cards[clampi(selected, 0, cards.size() - 1)].grab_focus()


# Opening the page: the list first, the column a beat later.
func play_entrance() -> void:
	UIMotion.of(_catalog).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(_info).appear(UIMotion.STAGGER_TIME)
	UIMotion.of(stage).appear(UIMotion.STAGGER_TIME * 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var pad := event is InputEventJoypadButton
	if pad or event is InputEventKey:
		kind_tabs.use_pad(pad)
	var back: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q) or (pad and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER)
	var next: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E) or (pad and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER)
	if back or next:
		kind_tabs.step(-1 if back else 1)
		get_viewport().set_input_as_handled()
