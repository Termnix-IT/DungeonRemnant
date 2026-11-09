class_name HubCodex
extends Control

# The encyclopedia of foes (FoeCatalog): on the slab from the left edge, the
# kind tabs (all, the crowd, elites, bosses), how many have been met, and,
# as bestiaries commonly lay them out, a close grid of small round sockets
# (EquipSocket, as the status page's shelf), each the foe's picture without
# its name (dimmed to a shade for one not met, so the foes met stand out),
# scrolling once there are more rows than the slab holds; in the column on
# the right, inside the ornate frame of the upgrade and status pages, the
# focused foe's picture, large, its name, kind, figures and how it fights. A
# foe counts as met once it has come into an area in a run
# (MetaProgress.met); the others show as shades named "？？？", their kind
# alone told. Nothing here changes the progress.

const PORTRAIT_SIZE := 240.0
const TILE_DIAMETER := 80.0
# A standing figure's square inside the round disc.
const TILE_INSET := 0.9
const COLUMNS := 8
const STAT_MARKER := 14.0
const UNKNOWN_NAME := "？？？"
const UNKNOWN_NOTE := "まだ出会っていない敵。探索で戦場に現れると記録される。"
const SHADOW := Color(0.0, 0.0, 0.0, 0.85)

var meta: MetaProgress
var kind_tabs: CategoryTabs
var count_label: Label
var cards: Array[EquipSocket] = []
var rows: Array[FoeData] = []
var picture: Control
var name_label: Label
var kind_label: Label
# The met foe's figures, a row each (empty for one not met).
var stats: GridContainer
var description_label: Label
var selected := 0
var _list: GridContainer
var _catalog: VBoxContainer
var _info: VBoxContainer
var _picture := {}
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
	# The right column stands in its own ornate frame, so no hairline parts
	# the two columns (SlabSolidOpen).
	_catalog = HubUI.open_column(columns, 2.1, &"SlabSolidOpen")
	kind_tabs = CategoryTabs.new()
	_catalog.add_child(kind_tabs)
	kind_tabs.setup(FoeCatalog.KINDS)
	kind_tabs.changed.connect(func(_index: int):
		_show_rows()
		focus_first())
	count_label = HubUI.label(_catalog, "", &"NoteLabel")
	# More rows than the slab holds scroll within it, and the tile the focus
	# lands on is drawn into view.
	var scroll := ScrollContainer.new()
	scroll.name = "Tiles"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_catalog.add_child(scroll)
	# Room inside the scroll for the focused socket's glow.
	var room := MarginContainer.new()
	room.theme_type_variation = &"CodexGridMargin"
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(room)
	_list = GridContainer.new()
	_list.theme_type_variation = &"CodexGrid"
	_list.columns = COLUMNS
	_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	room.add_child(_list)
	_info = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	# The account stands inside the ornate frame laid over the column, as on
	# the upgrade and status pages, and slides in from the right edge, kept
	# inside its column.
	var info_panel := _info.get_parent() as Control
	info_panel.clip_contents = true
	var info_margin := MarginContainer.new()
	info_margin.theme_type_variation = &"CodexInfoMargin"
	info_panel.remove_child(_info)
	info_panel.add_child(info_margin)
	info_margin.add_child(_info)
	_info.theme_type_variation = &"DetailStack"
	picture = Control.new()
	picture.custom_minimum_size = Vector2.ONE * PORTRAIT_SIZE
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.draw.connect(_draw_picture)
	_info.add_child(picture)
	name_label = HubUI.label(_info, "", &"HeadingLabel")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_label = HubUI.label(_info, "", &"MutedLabel")
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HubUI.rule(_info)
	stats = GridContainer.new()
	stats.theme_type_variation = &"CodexStats"
	stats.columns = 3
	stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_info.add_child(stats)
	# A breath between the figures and the account.
	var breath := Control.new()
	breath.custom_minimum_size.y = 6
	_info.add_child(breath)
	description_label = HubUI.label(_info, "", &"DescriptionLabel")
	HubUI.space(_info)
	HubUI.ornate_frame(info_panel)


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
	var met := 0
	for foe in FoeCatalog.FOES:
		var known := meta.has_met(foe.id)
		if known:
			met += 1
		if kind_tabs.selected > 0 and FoeCatalog.kind_of(foe) != kind_tabs.selected:
			continue
		rows.append(foe)
		cards.append(_card(foe, known))
	count_label.text = "出会った敵  %d / %d" % [met, FoeCatalog.FOES.size()]
	UIMotion.bind_buttons(_list)
	if not rows.is_empty():
		_select(0, false)


func _card(foe: FoeData, known: bool) -> EquipSocket:
	var card := EquipSocket.new(TILE_DIAMETER, false, true)
	card.inset = TILE_INSET
	card.tooltip_text = foe.display_name if known else UNKNOWN_NOTE
	# The foe's picture; one not met, dimmed to a shade as the upgrade tree's
	# nodes not open yet.
	card.emblem = tile_picture(foe.visual_id, true, foe.tint)
	card.unknown = not known
	var index := cards.size()
	card.pressed.connect(_select.bind(index))
	card.focus_entered.connect(_select.bind(index))
	_list.add_child(card)
	return card


# The foe's picture for its tile, or its dark silhouette: always a square
# the figure fills, standing on its bottom edge, so every tile lays its picture
# and its name out alike whatever the figure's shape. A foe drawn in a tint
# of its own (a kin sharing another's rig) is shown in it. The departure's
# foes are drawn with it too.
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
	var foe := rows[place]
	if animate and foe == _shown:
		return
	_shown = foe
	_unknown = not meta.has_met(foe.id)
	_picture = EnemySprites.portrait(foe.visual_id)
	picture.queue_redraw()
	kind_label.text = FoeCatalog.kind_name(foe)
	for child in stats.get_children():
		child.free()
	if _unknown:
		name_label.text = UNKNOWN_NAME
		description_label.text = UNKNOWN_NOTE
	else:
		name_label.text = foe.display_name
		for row: Array in [["HP", str(foe.max_hp)], ["ぶつかる力", str(foe.contact_damage)], ["速さ", str(roundi(foe.speed))]]:
			_stat_row(row[0], row[1])
		description_label.text = foe.description
	if animate:
		UIMotion.of(_info).slide_in()


# One of the foe's figures: a small gilt diamond, its name, its value.
func _stat_row(title: String, value: String) -> void:
	var marker := Control.new()
	marker.custom_minimum_size = Vector2(STAT_MARKER, STAT_MARKER)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(func(): HubUI.diamond(marker, marker.size * 0.5, 4.0, marker.get_theme_color(&"rail", &"HubLobby")))
	stats.add_child(marker)
	var name := HubUI.label(stats, title, &"BodyLabel")
	var figure := HubUI.label(stats, value, &"BodyLabel")
	figure.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label: Label in [name, figure]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF


func _draw_picture() -> void:
	if _picture.is_empty():
		return
	var region: Rect2 = _picture.region
	var extent := minf(picture.size.x, picture.size.y)
	var fit := extent / maxf(region.size.x, region.size.y)
	var drawn := region.size * fit
	var area := Rect2(Vector2((picture.size.x - drawn.x) * 0.5, picture.size.y - drawn.y), drawn)
	picture.draw_texture_rect_region(_picture.texture, area, region, SHADOW if _unknown else _shown.tint)


func focus_first() -> void:
	if not cards.is_empty():
		cards[0].grab_focus()


# Opening the page: the list first, the column a beat later.
func play_entrance() -> void:
	UIMotion.of(_catalog).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(_info).appear(UIMotion.STAGGER_TIME)


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
