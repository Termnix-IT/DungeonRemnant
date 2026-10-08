class_name HubLobby
extends Control

# The hub's home, laid out like a game lobby rather than a page of cards:
# a decorated menu on the left, the chosen entry's short information floating
# over the floor, and the heroine standing in the hall on the right. The hall
# painting runs behind all three so they read as one scene.
#
# Choosing and entering are separate. Keyboard and gamepad focus chooses, and
# confirming the focused entry enters it. A click chooses an entry; clicking
# the chosen entry again, or the panel's button, enters it.

signal selection_changed(id: StringName)
signal activated(id: StringName)

# id, menu label, NavigationIcon kind
const ENTRIES := [
	[&"departure", "出撃", "出撃"],
	[&"equipment", "装備", "装備"],
	[&"storage", "倉庫", "倉庫"],
	[&"shop", "ショップ", "ショップ"],
	[&"upgrade", "強化", "永久強化"],
	[&"settings", "設定", "設定"],
]
const ACTIONS := {
	&"departure": "行き先を選ぶ",
	&"equipment": "装備を整える",
	&"storage": "倉庫を開く",
	&"shop": "ショップに入る",
	&"upgrade": "強化を選ぶ",
	&"settings": "設定を開く",
}
const DESCRIPTIONS := {
	&"equipment": "武具を5つの枠に装備し、杖に魔法を込める。",
	&"storage": "持ち込みと倉庫の間で品を移す。倉庫の品は冒険で失わない。",
	&"shop": "Goldで薬や武具を買い、要らない品を売る。",
	&"upgrade": "Goldで能力を永久に強化し、開始階を解放する。",
	&"settings": "音量と画面モードを変え、遊び方を確認する。",
}
# Each panel shows the illustration of what it opens.
const ART := {
	&"equipment": preload("res://art/hub/cards/weapons.png"),
	&"storage": preload("res://art/hub/cards/chests.png"),
	&"shop": preload("res://art/hub/cards/shop.png"),
	&"upgrade": preload("res://art/hub/cards/books.png"),
	&"settings": preload("res://art/hub/cards/settings.png"),
}
const HERO_TEXTURE := preload("res://art/characters/mio_lobby.png")
# Where her face and the middle of her soles sit in the texture, as fractions.
const FACE := Vector2(0.38, 0.165)
const FEET := Vector2(0.52, 0.985)
# The soles: her right foot stands on the floor, the left a step behind it.
const SOLES := [Vector2(0.61, 0.985), Vector2(0.42, 0.93)]
const SPEECH := ["準備ができたら、出発しよう。", "装備の確認は済んだ？", "次は、どこへ潜ろうか。", "倉庫の整理も忘れずにね。"]
const SPEECH_TIME := 4.0
# Room between the line and the end studs, and from the tail's tip to her face.
const SPEECH_GAP := 22.0
const SPEECH_REACH := 46.0
# Layout in the 1600×900 base viewport. The menu keeps about a fifth of the
# width; the heroine stands about two thirds of the height tall.
const MENU_WIDTH := 300.0
const MENU_TOP := 168.0
const ROW_HEIGHT := 80.0
const BAND_INSET := 14.0
# The panel centres in the floor between the menu and the heroine.
# How long the pointer must rest on an entry before it is chosen, so one
# crossed on the way to the panel's button is not.
const HOVER_INTENT := 0.1
const PANEL_CENTER_X := 0.465
const PANEL_WIDTH := 660.0
# Low enough that the altar and the foot of the stairs stay in view, its
# bottom edge on the heroine's floor line.
const PANEL_BOTTOM := 64.0
# Every entry shows the same panel: one size, the name and line at the top,
# the facts and the button at the bottom, so switching entries moves nothing.
const PANEL_HEIGHT := 256.0
const STRIP_HEIGHT := 60.0
# Room for the main weapon's name beside its glyph in half the strip.
const WEAPON_NAME_WIDTH := 240.0
# The texture keeps clear margins for swaying hair, so the figure itself
# stands about 78% of the screen tall.
const HERO_HEIGHT := 0.8
const HERO_CENTER_X := 0.835
const HERO_FEET_Y := 0.965

var buttons: Array[Button] = []
var selected := 0
var decide_button: Button
var title_label: Label
var description_label: Label
var hero: LobbyHero
var speech_label: Label
var _speech_index := 0
# The entry under the pointer, or -1.
var _hover_index := -1
var _speech_token := 0
var _shadow_texture: GradientTexture2D
var hero_button: Button
var hero_speech: Panel
var equipment_label: Label
var main_glyph: Control
var carried_label: Label
var stored_label: Label
var gold_value: Label
var carried_room: Label
var upgrade_value: Label
var upgrade_ready: Label
var worn_value: Label
var title_icon: NavigationIcon
var floors_value: Label
var difficulty_value: Label
var volume_value: Label
var display_value: Label
var settings: GameSettings
var panel: PanelContainer
var _art: TextureRect
var _details := {}
var _state: RunCarryover
var _stage: StageData
var _band_y := 0.0
var _band_tween: Tween


func _init() -> void:
	name = "Lobby"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hero()
	_build_menu()
	_build_panel()
	# The speech bubble draws over the panel.
	move_child(hero_speech, get_child_count() - 1)
	resized.connect(_place_hero)
	_place_hero()
	_band_y = _row_rect(selected).position.y
	_show_entry()


func _build_menu() -> void:
	var previous: Button
	for index in ENTRIES.size():
		var entry: Array = ENTRIES[index]
		var button := Button.new()
		button.name = String(entry[0]).capitalize().replace(" ", "") + "Entry"
		button.text = entry[1]
		button.theme_type_variation = &"LobbyMenuButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(button)
		var row := _row_rect(index)
		button.position = row.position
		button.size = row.size
		var icon := NavigationIcon.new()
		icon.name = "Icon"
		icon.kind = entry[2]
		button.add_child(icon)
		icon.position = Vector2(30, (row.size.y - 48) * 0.5)
		icon.size = Vector2(48, 48)
		button.pressed.connect(_pressed.bind(index))
		button.focus_entered.connect(_focused.bind(index))
		button.mouse_entered.connect(_hovered.bind(index))
		button.mouse_exited.connect(_unhovered.bind(index))
		if previous != null:
			previous.focus_neighbor_bottom = button.get_path()
			button.focus_neighbor_top = previous.get_path()
		previous = button
		buttons.append(button)
	buttons[0].focus_neighbor_top = buttons[0].get_path()
	buttons[-1].focus_neighbor_bottom = buttons[-1].get_path()


func _row_rect(index: int) -> Rect2:
	return Rect2(Vector2(16, MENU_TOP + index * ROW_HEIGHT), Vector2(MENU_WIDTH - 16, ROW_HEIGHT))


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "InfoPanel"
	panel.theme_type_variation = &"LobbyInfoPanel"
	add_child(panel)
	# A fixed size on the floor, the same for every entry.
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_left = PANEL_CENTER_X
	panel.anchor_right = PANEL_CENTER_X
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	panel.offset_bottom = -PANEL_BOTTOM
	panel.offset_top = -PANEL_BOTTOM - PANEL_HEIGHT
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.modulate = get_theme_color(&"art_tint", &"HubLobby")
	panel.add_child(_art)
	# The art fades out towards the text on the left.
	var fade := Gradient.new()
	var ground := get_theme_stylebox(&"panel", &"LobbyInfoPanel").get(&"bg_color") as Color
	fade.set_color(0, Color(ground, 1.0))
	fade.set_color(1, Color(ground, 0.15))
	fade.add_point(0.45, Color(ground, 0.82))
	var veil_texture := GradientTexture2D.new()
	veil_texture.gradient = fade
	veil_texture.fill_from = Vector2(0, 0.5)
	veil_texture.fill_to = Vector2(1, 0.5)
	var veil := TextureRect.new()
	veil.texture = veil_texture
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(veil)
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"LobbyInfoMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"LobbyInfoStack"
	margin.add_child(stack)
	# The entry's mark from the menu beside its name ties the two together.
	var heading := HBoxContainer.new()
	heading.theme_type_variation = &"CompactRow"
	stack.add_child(heading)
	title_icon = NavigationIcon.new()
	heading.add_child(title_icon)
	title_label = HubUI.label(heading, "", &"LobbyTitle")
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# One line: a longer description is cut short, whole in a tooltip that
	# appears only then.
	description_label = HubUI.label(stack, "", &"DescriptionLabel")
	description_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description_label.mouse_filter = Control.MOUSE_FILTER_PASS
	# The line takes any spare height, so the facts and the button keep their
	# place at the bottom.
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var route: HBoxContainer = _strip(stack)
	_details[&"departure"] = route
	floors_value = _fact(route, "階層")
	_divider(route)
	difficulty_value = _fact(route, "難易度")
	var gear: HBoxContainer = _strip(stack)
	_details[&"equipment"] = gear
	# The main weapon's value is its glyph and name side by side.
	var weapon := _cell(gear, "主武器")
	var named := HBoxContainer.new()
	named.theme_type_variation = &"CompactRow"
	named.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon.add_child(named)
	main_glyph = Control.new()
	main_glyph.custom_minimum_size = Vector2(26, 26)
	main_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_glyph.draw.connect(_draw_main_glyph)
	named.add_child(main_glyph)
	equipment_label = HubUI.label(named, "", &"ValueLabel")
	equipment_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	equipment_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	equipment_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_divider(gear)
	worn_value = _fact(gear, "装備枠")
	var room: HBoxContainer = _strip(stack)
	_details[&"storage"] = room
	carried_label = _fact(room, "持ち込み")
	_divider(room)
	stored_label = _fact(room, "倉庫")
	var purse: HBoxContainer = _strip(stack)
	_details[&"shop"] = purse
	# Money keeps its gold, at the same size as every other value.
	gold_value = _fact(purse, "所持金", &"MoneyValueLabel")
	_divider(purse)
	carried_room = _fact(purse, "持ち込み空き")
	var growth: HBoxContainer = _strip(stack)
	_details[&"upgrade"] = growth
	upgrade_value = _fact(growth, "習得した強化")
	_divider(growth)
	upgrade_ready = _fact(growth, "強化できる")
	var current: HBoxContainer = _strip(stack)
	_details[&"settings"] = current
	volume_value = _fact(current, "音量")
	_divider(current)
	display_value = _fact(current, "画面")
	decide_button = HubUI.primary_action(stack, "", func(): activated.emit(selected_id()))
	decide_button.name = "Decide"
	var frame := Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_panel_frame.bind(frame))
	panel.add_child(frame)


# The facts lie on a dark band whose ends melt into the panel, between faint
# gilt hairlines, instead of in a sunken box: laid on the panel, not fenced.
func _strip(parent: Node) -> HBoxContainer:
	var band := Control.new()
	band.custom_minimum_size.y = STRIP_HEIGHT
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.draw.connect(_draw_band.bind(band))
	parent.add_child(band)
	var row := HBoxContainer.new()
	row.theme_type_variation = &"LobbyFactRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return row


# A fact reads as a small kicker above its value, both centred.
func _cell(row: HBoxContainer, caption: String) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.theme_type_variation = &"LobbyFact"
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cell)
	var kicker := HubUI.label(cell, caption, &"LobbyFactCaption")
	kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return cell


func _fact(row: HBoxContainer, caption: String, role: StringName = &"ValueLabel") -> Label:
	var value := HubUI.label(_cell(row, caption), "", role)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return value


# A gilt diamond between the facts, with hairlines fading above and below.
func _divider(row: HBoxContainer) -> void:
	var mark := Control.new()
	mark.custom_minimum_size.x = 24
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func():
		var rail := get_theme_color(&"rail", &"HubLobby")
		var middle := mark.size * 0.5
		mark.draw_polyline_colors(PackedVector2Array([middle + Vector2(0, -22), middle + Vector2(0, -8)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.6)]), 1.0, true)
		mark.draw_polyline_colors(PackedVector2Array([middle + Vector2(0, 8), middle + Vector2(0, 22)]), PackedColorArray([Color(rail, 0.6), Color(rail, 0.0)]), 1.0, true)
		_diamond_on(mark, middle, 5.0, Color(rail, 0.9)))
	row.add_child(mark)


func _draw_band(band: Control) -> void:
	var rail := get_theme_color(&"rail", &"HubLobby")
	var dark := get_theme_color(&"fact_band", &"HubLobby")
	var clear := Color(dark, 0.0)
	var w := band.size.x
	var h := band.size.y
	band.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5, h), Vector2(0, h)]), PackedColorArray([clear, dark, dark, clear]))
	band.draw_polygon(PackedVector2Array([Vector2(w * 0.5, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.5, h)]), PackedColorArray([dark, clear, clear, dark]))
	for y in [0.5, h - 0.5]:
		band.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(w * 0.5, y), Vector2(w, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.45), Color(rail, 0.0)]), 1.0, true)


func _diamond_on(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


func _build_hero() -> void:
	hero = LobbyHero.new()
	hero.name = "Hero"
	hero.texture = HERO_TEXTURE
	# Settle the bright illustration into the lantern light of the hall.
	hero.modulate = get_theme_color(&"hero_tint", &"HubLobby")
	add_child(hero)
	hero_button = InkTooltip.HintButton.new()
	hero_button.name = "HeroButton"
	hero_button.theme_type_variation = &"CharacterButton"
	hero_button.tooltip_text = "話しかける"
	hero_button.focus_mode = Control.FOCUS_NONE
	hero_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hero_button.pressed.connect(talk)
	add_child(hero_button)
	hero_speech = Panel.new()
	hero_speech.name = "HeroSpeech"
	hero_speech.theme_type_variation = &"SpeechPanel"
	hero_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero_speech)
	# The backing is an ink-wash strip whose brush-stroke tail points at her
	# face; its ends keep their size and the plain middle fits the line.
	speech_label = Label.new()
	speech_label.theme_type_variation = &"ItemNameLabel"
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_speech.add_child(speech_label)
	speech_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backing := hero_speech.get_theme_stylebox(&"panel") as StyleBoxTexture
	# The text keeps clear of the end studs and the tail.
	speech_label.offset_left = backing.texture_margin_left
	speech_label.offset_right = -backing.texture_margin_right
	hero_speech.hide()
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.4, Color(1, 1, 1, 0.75))
	_shadow_texture = GradientTexture2D.new()
	_shadow_texture.gradient = fade
	_shadow_texture.fill = GradientTexture2D.FILL_RADIAL
	_shadow_texture.fill_from = Vector2(0.5, 0.5)
	_shadow_texture.fill_to = Vector2(1.0, 0.5)
	# The gradient renders a frame later; draw the shadow again once it has.
	_shadow_texture.changed.connect(queue_redraw)


# A click on her: she reacts and says the next line, which fades after a while.
func talk() -> void:
	hero.react()
	speech_label.text = SPEECH[_speech_index % SPEECH.size()]
	_speech_index += 1
	_fit_speech()
	hero_speech.show()
	UIMotion.of(hero_speech).reveal(UIMotion.SELECT_TIME)
	_speech_token += 1
	var token := _speech_token
	get_tree().create_timer(SPEECH_TIME).timeout.connect(func():
		if token == _speech_token:
			hero_speech.hide())


func _place_hero() -> void:
	var extent := Vector2(HERO_TEXTURE.get_size().aspect(), 1.0) * size.y * HERO_HEIGHT
	var feet := Vector2(size.x * HERO_CENTER_X, size.y * HERO_FEET_Y)
	hero.size = extent
	hero.position = feet - Vector2(extent.x * 0.5, extent.y)
	hero.pivot_offset = Vector2(extent.x * 0.5, extent.y)
	# Only her figure answers the pointer, not the empty corners of the art.
	hero_button.position = hero.position + Vector2(extent.x * 0.24, extent.y * 0.05)
	hero_button.size = Vector2(extent.x * 0.52, extent.y * 0.9)
	_fit_speech()
	queue_redraw()


# The bubble is as wide as its line plus the gap on each side and the two
# ends, and stands beside her face with the tail's tip just short of it.
func _fit_speech() -> void:
	var backing := hero_speech.get_theme_stylebox(&"panel") as StyleBoxTexture
	var font := speech_label.get_theme_font(&"font")
	var line := font.get_string_size(speech_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, speech_label.get_theme_font_size(&"font_size")).x
	hero_speech.size = Vector2(ceilf(line) + SPEECH_GAP * 2.0 + backing.texture_margin_left + backing.texture_margin_right, backing.texture.get_height())
	var face := hero.position + hero.size * FACE
	hero_speech.position = Vector2(maxf(0.0, face.x - SPEECH_REACH - hero_speech.size.x), face.y - hero_speech.size.y * 0.5)


func refresh(state: RunCarryover, stage: StageData) -> void:
	_state = state
	_stage = stage
	equipment_label.text = state.equipment.slots[Equipment.Slot.MAIN].display_name
	# A trimming label has no width of its own: give it the name's width, up
	# to what its half of the strip holds; longer names end in "…" and stay
	# whole in the tooltip.
	var font := equipment_label.get_theme_font(&"font")
	var name_width := font.get_string_size(equipment_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, equipment_label.get_theme_font_size(&"font_size")).x
	equipment_label.custom_minimum_size.x = minf(ceilf(name_width) + 2.0, WEAPON_NAME_WIDTH)
	equipment_label.tooltip_text = equipment_label.text if name_width + 2.0 > WEAPON_NAME_WIDTH else ""
	equipment_label.mouse_filter = Control.MOUSE_FILTER_PASS
	main_glyph.queue_redraw()
	carried_label.text = "%d / %d 枠" % [state.inventory.entries.size(), state.inventory.max_entries]
	stored_label.text = "%d / %d 枠" % [state.storage.entries.size(), state.storage.max_entries]
	gold_value.text = "%s G" % UIFormat.amount(state.gold)
	carried_room.text = "%d 枠" % (state.inventory.max_entries - state.inventory.entries.size())
	var worn := 0
	for item in state.equipment.slots:
		if item != null:
			worn += 1
	worn_value.text = "%d / %d" % [worn, state.equipment.slots.size()]
	# What the current Gold can buy now, by the same rules the tree uses.
	var ready := 1 if state.upgrade.price(state.hp_upgrade_level) >= 0 and state.gold >= state.upgrade.price(state.hp_upgrade_level) else 0
	for node in SkillCatalog.NODES:
		if state.can_purchase_skill(node.id):
			ready += 1
	upgrade_ready.text = "%d 件" % ready
	var ranks := state.hp_upgrade_level
	for id in state.skill_levels:
		ranks += int(state.skill_levels[id])
	upgrade_value.text = "%d 段階" % ranks
	if stage != null:
		floors_value.text = "全%d階" % stage.floor_count
		difficulty_value.text = stage.difficulty
	if settings != null:
		volume_value.text = "%d%%" % settings.volume_percent()
		display_value.text = GameSettings.DISPLAY_NAMES[1 if settings.fullscreen else 0]
	_show_entry()


func selected_id() -> StringName:
	return ENTRIES[selected][0]


func select(index: int) -> void:
	if index == selected:
		return
	selected = index
	hero_speech.hide()
	_show_entry()
	if _band_tween != null:
		_band_tween.kill()
	_band_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_band_tween.tween_method(_move_band, _band_y, _row_rect(index).position.y, UIMotion.SELECT_TIME)
	UIMotion.of(panel).reveal(UIMotion.SELECT_TIME)
	selection_changed.emit(selected_id())


func focus_selected() -> void:
	buttons[selected].grab_focus()


func _move_band(value: float) -> void:
	_band_y = value
	queue_redraw()


# Keys and the gamepad choose by moving focus and press to enter; the pointer
# chooses by resting on an entry, so one click enters.
func _pressed(index: int) -> void:
	if not is_visible_in_tree():
		return
	select(index)
	activated.emit(selected_id())


# Resting on an entry chooses it, and focus follows so keys go on from there.
func _hovered(index: int) -> void:
	_hover_index = index
	await get_tree().create_timer(HOVER_INTENT).timeout
	if _hover_index == index and is_visible_in_tree():
		select(index)
		buttons[index].grab_focus()


func _unhovered(index: int) -> void:
	if _hover_index == index:
		_hover_index = -1


# A click gives focus on mouse down; the click itself chooses on release, so
# only focus that keys or the gamepad moved chooses here.
func _focused(index: int) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		select(index)


func _show_entry() -> void:
	var id := selected_id()
	for index in buttons.size():
		var chosen := index == selected
		buttons[index].theme_type_variation = &"LobbyMenuButtonSelected" if chosen else &"LobbyMenuButton"
		buttons[index].get_node("Icon").modulate = Color.WHITE if chosen else get_theme_color(&"icon_rest", &"HubLobby")
	for key in _details:
		var detail: Control = _details[key]
		# Strips sit inside an inset panel and margin; show the outer one.
		# Each strip's row sits in its band.
		detail.get_parent().visible = key == id
	if id == &"departure" and _stage != null:
		title_label.text = _stage.display_name
		description_label.text = _stage.description
		_art.texture = _stage.illustration
	else:
		title_label.text = ENTRIES[selected][1]
		description_label.text = DESCRIPTIONS.get(id, "")
		_art.texture = ART.get(id)
	# Only a line cut short needs its whole text on hover.
	var line_font := description_label.get_theme_font(&"font")
	var line_width := line_font.get_string_size(description_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, description_label.get_theme_font_size(&"font_size")).x
	description_label.tooltip_text = description_label.text if line_width > PANEL_WIDTH - 60.0 else ""
	title_icon.kind = ENTRIES[selected][2]
	title_icon.queue_redraw()
	decide_button.visible = ACTIONS.has(id)
	decide_button.text = ACTIONS.get(id, "")
	# Right from the menu reaches the panel's button.
	for button in buttons:
		button.focus_neighbor_right = decide_button.get_path()
	decide_button.focus_neighbor_left = buttons[selected].get_path()
	queue_redraw()


func _draw_main_glyph() -> void:
	if _state != null and _state.equipment.slots[Equipment.Slot.MAIN] != null:
		ItemGlyph.paint(main_glyph, Rect2(Vector2.ZERO, main_glyph.size), _state.equipment.slots[Equipment.Slot.MAIN], main_glyph.get_theme_color(&"font_color", &"GoldLabel"))


func _draw() -> void:
	_draw_menu_slab()
	_draw_selection()
	# A soft pool of shade, and a darker contact shadow right under her boots,
	# ground the heroine on the floor.
	var feet := hero.position + hero.size * FEET
	var shadow := get_theme_color(&"shadow", &"HubLobby")
	draw_texture_rect(_shadow_texture, Rect2(feet - Vector2(200, 32), Vector2(400, 64)), false, Color(shadow, shadow.a * 0.7))
	for sole: Vector2 in SOLES:
		var at := hero.position + hero.size * sole
		draw_texture_rect(_shadow_texture, Rect2(at - Vector2(62, 11), Vector2(124, 22)), false, shadow)


func _draw_menu_slab() -> void:
	var slab := get_theme_color(&"slab", &"HubLobby")
	var rail := get_theme_color(&"rail", &"HubLobby")
	# Dark stone slab that fades into the hall instead of ending in a box edge.
	var colors := PackedColorArray([slab, slab, Color(slab, slab.a * 0.82), Color(slab, 0.0)])
	var right := MENU_WIDTH + 70.0
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(MENU_WIDTH - 8, 0), Vector2(MENU_WIDTH - 8, size.y), Vector2(0, size.y)]), PackedColorArray([slab, Color(slab, slab.a * 0.82), Color(slab, slab.a * 0.82), slab]))
	draw_polygon(PackedVector2Array([Vector2(MENU_WIDTH - 8, 0), Vector2(right, 0), Vector2(right, size.y), Vector2(MENU_WIDTH - 8, size.y)]), PackedColorArray([colors[2], colors[3], colors[3], colors[2]]))
	# Double gilt rail with diamond studs along the slab's edge.
	var x := MENU_WIDTH - 6.0
	draw_line(Vector2(x, 36), Vector2(x, size.y - 36), Color(rail, 0.75), 2.0, true)
	draw_line(Vector2(x - 7, 60), Vector2(x - 7, size.y - 60), Color(rail, 0.3), 1.0, true)
	for y in [36.0, size.y * 0.5, size.y - 36.0]:
		_diamond(Vector2(x, y), 7.0, rail)
	# Crest above the entries: a compass star in a ring.
	var crest := Vector2(MENU_WIDTH * 0.5, MENU_TOP - 64)
	draw_arc(crest, 30, 0, TAU, 48, Color(rail, 0.55), 1.5, true)
	draw_arc(crest, 24, 0, TAU, 48, Color(rail, 0.25), 1.0, true)
	for step in 8:
		var length := 40.0 if step % 2 == 0 else 22.0
		var angle := step * TAU / 8.0 - PI * 0.5
		var tip := crest + Vector2.from_angle(angle) * length
		var side := Vector2.from_angle(angle + PI * 0.5) * (5.0 if step % 2 == 0 else 3.5)
		draw_colored_polygon(PackedVector2Array([crest + side, tip, crest - side]), Color(rail, 0.85 if step % 2 == 0 else 0.5))
	draw_circle(crest, 3.0, rail)
	_ornament_line(MENU_TOP - 14)
	_ornament_line(MENU_TOP + ENTRIES.size() * ROW_HEIGHT + 14)
	# Hairlines between the entries, faded at both ends.
	for index in range(1, ENTRIES.size()):
		var y := MENU_TOP + index * ROW_HEIGHT
		var hair := Color(rail, 0.22)
		draw_polyline_colors(PackedVector2Array([Vector2(40, y), Vector2(150, y), Vector2(262, y)]), PackedColorArray([Color(hair, 0.0), hair, Color(hair, 0.0)]), 1.0, true)


func _ornament_line(y: float) -> void:
	var rail := get_theme_color(&"rail", &"HubLobby")
	var middle := MENU_WIDTH * 0.5
	draw_polyline_colors(PackedVector2Array([Vector2(28, y), Vector2(middle - 14, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.7)]), 1.0, true)
	draw_polyline_colors(PackedVector2Array([Vector2(middle + 14, y), Vector2(MENU_WIDTH - 28, y)]), PackedColorArray([Color(rail, 0.7), Color(rail, 0.0)]), 1.0, true)
	_diamond(Vector2(middle, y), 6.0, rail)


func _draw_selection() -> void:
	var gold := get_theme_color(&"band", &"HubLobby")
	var rail := get_theme_color(&"rail", &"HubLobby")
	# The gold text, the point and the edge line say which entry is chosen;
	# the fill and the halo only warm it, kept low so the heroine leads.
	var top := _band_y + BAND_INSET
	var bottom := _band_y + ROW_HEIGHT - BAND_INSET
	var middle := (top + bottom) * 0.5
	var tip := MENU_WIDTH + 22.0
	# Warm light across the chosen row, ending in a point past the rail.
	var shape := PackedVector2Array([Vector2(16, top), Vector2(tip - 22, top), Vector2(tip, middle), Vector2(tip - 22, bottom), Vector2(16, bottom)])
	draw_polygon(shape, PackedColorArray([Color(gold, gold.a * 0.35), Color(gold, gold.a), Color(gold, gold.a * 1.1), Color(gold, gold.a), Color(gold, gold.a * 0.35)]))
	draw_polyline_colors(PackedVector2Array([Vector2(16, top), Vector2(tip - 22, top), Vector2(tip, middle), Vector2(tip - 22, bottom), Vector2(16, bottom)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.9), rail, Color(rail, 0.9), Color(rail, 0.0)]), 1.5, true)
	_diamond(Vector2(tip, middle), 5.0, rail)
	# Halo behind the chosen icon.
	var halo := Vector2(16 + 54, middle)
	for ring in 4:
		draw_circle(halo, 26.0 - ring * 5.0, Color(gold, gold.a * 0.3))


func _draw_panel_frame(frame: Control) -> void:
	var rail := get_theme_color(&"rail", &"HubLobby")
	var rect := Rect2(Vector2.ZERO, frame.size)
	frame.draw_rect(rect.grow(-1), Color(rail, 0.55), false, 1.0)
	frame.draw_rect(rect.grow(-6), Color(rail, 0.18), false, 1.0)
	var arm := 26.0
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var inward := Vector2(signf(rect.get_center().x - corner.x), signf(rect.get_center().y - corner.y))
		var at: Vector2 = corner + inward * 3.0
		frame.draw_polyline(PackedVector2Array([at + Vector2(inward.x * arm, 0), at, at + Vector2(0, inward.y * arm)]), rail, 2.0, true)
	for center in [Vector2(rect.get_center().x, 1), Vector2(rect.get_center().x, rect.end.y - 1)]:
		frame.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -6), center + Vector2(6, 0), center + Vector2(0, 6), center + Vector2(-6, 0)]), rail)


func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)
