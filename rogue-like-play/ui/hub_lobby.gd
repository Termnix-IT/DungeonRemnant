class_name HubLobby
extends Control

# The hub's home, laid out like a game lobby rather than a page of cards:
# the menu on the left, the chosen entry's short information on a plate over
# the floor, and the heroine standing in the hall on the right. The hall
# (HubHall) runs behind all three so they read as one scene.
#
# The menu is written on a near stone pier (menu_pillar.png) that stands at
# the screen's left edge in front of the hall, the game's emblem in the ring
# at its head. Each entry is a bronze medallion and its name; the chosen one
# is the one in the light: a warm light lies across its row, its medallion
# kindles and stands a little larger, its name turns gold, and the thing in
# the hall it belongs to lights up (HubHall.focus()). The others stay dim
# bronze.
#
# Choosing and entering are separate. Keyboard and gamepad focus chooses, and
# confirming the focused entry enters it. A click chooses an entry; clicking
# the chosen entry again, or the panel's button, enters it.
#
# The upgrades' entry carries a small mark beside its name while the echo
# held can buy a rank of anything, so that shows without choosing the entry.
# The bestiary's entry carries the same mark while a foe newly met has not
# been looked up there (MetaProgress.is_new), and tells how many when chosen.
#
# Its things can be held back and brought in (hold(), present()): the pier
# slides in from the left, the heroine steps in from the right and the plate
# rises, after the game's opening and on the way back from the departure;
# leave() sends them off the same ways as the view goes up to the gate.

signal selection_changed(id: StringName)
signal activated(id: StringName)

# id, menu label, NavigationIcon kind
const ENTRIES := [
	[&"departure", "出撃", &"departure"],
	[&"upgrade", "強化", &"upgrade"],
	[&"status", "ステータス", &"equip"],
	[&"codex", "図鑑", &"codex"],
	[&"settings", "設定", &"settings"],
]
# Translated in the context "lobby": the controls guide's "強化を選ぶ" is a
# level-up boon, these the base's upgrades.
const ACTIONS := {
	&"departure": "出撃先を選ぶ", # context: lobby
	&"upgrade": "強化を選ぶ", # context: lobby
	&"status": "ステータスを開く", # context: lobby
	&"codex": "図鑑を開く", # context: lobby
	&"settings": "設定を開く", # context: lobby
}
const DESCRIPTIONS := {
	&"upgrade": "探索で得た残響で、次の探索からずっと続く強化を手に入れる。",
	&"status": "強化で育った数値を確かめ、スキルを付け替える。",
	&"codex": "これまでに戦場で出会った敵を見返す。",
	&"settings": "音量と画面モードを変え、遊び方を確認する。",
}
# Each panel shows the illustration of what it opens; the departure, its
# chapter's.
const ART := {
	&"upgrade": preload("res://art/hub/cards/books.png"),
	&"status": preload("res://art/hub/cards/status.png"),
	&"codex": preload("res://art/hub/cards/codex.png"),
	&"settings": preload("res://art/hub/cards/settings.png"),
}
const HERO_TEXTURE := preload("res://art/characters/mio_lobby.png")
const PILLAR: Texture2D = preload("res://art/hub/lobby/menu_pillar.png")
const EMBLEM: Texture2D = preload("res://art/hub/title/emblem.png")
# The medallion of each entry.
const ICONS := {
	&"departure": preload("res://art/hub/lobby/icon_departure.png"),
	&"upgrade": preload("res://art/hub/lobby/icon_upgrade.png"),
	&"status": preload("res://art/hub/lobby/icon_status.png"),
	&"codex": preload("res://art/hub/lobby/icon_codex.png"),
	&"settings": preload("res://art/hub/lobby/icon_settings.png"),
}
# The pier: how wide it stands on the 1600x900 base, and where in its
# picture (as shares of it: tools/build_start_art.py --measure) its panel
# and the middle of its ring are, and how wide the ring is. The plain
# masonry at its foot (this share of its height) is mirrored on downward
# past the picture's end, on a screen taller than it.
const PILLAR_WIDTH := 378.0
const PILLAR_PANEL := Rect2(0.0952, 0.1921, 0.8149, 0.4928)
const PILLAR_RING := Vector2(0.4749, 0.1074)
const PILLAR_RING_ACROSS := 0.2857
const PILLAR_FOOT := 0.24
# How far the pier's shadow reaches over the hall beside it.
const PILLAR_SHADE := 110.0
# How far in from its outer edge the lamps' light reaches, and how far that
# light stays inside the edge's chipped outline.
const PILLAR_RIM := 64.0
const PILLAR_RIM_INSET := 5.0
# The emblem in the ring, as a share of the ring's width.
const EMBLEM_SHARE := 0.74
# Where her face and the middle of her soles sit in the texture, as fractions.
const FACE := Vector2(0.38, 0.165)
const FEET := Vector2(0.52, 0.985)
# The soles: her right foot stands on the floor, the left a step behind it.
const SOLES := [Vector2(0.61, 0.985), Vector2(0.42, 0.93)]
# Her lines, by how far the journey has come: before the first chapter's
# clear, after each chapter's (the last one's is the ending), each set
# turning to the chapter ahead. lines_for() picks the set.
const SPEECHES := [
	["準備ができたら、出発しよう。", "残響が貯まったら、強化を忘れずに。", "次は、どこまで行けるかな。", "回廊の奥の、あの気配……今度こそ。"],
	["風の吠える樹海……狼の声が聞こえる。", "強化の組み合わせ、もう少し試してみよう。", "遺跡王の残響が、まだ手に残ってる。"],
	["地下の霊廟から、誰かが呼んでる。", "骨の兵は、振りかぶりをよく見てから。", "残響が、少しずつ重くなっていく。"],
	["残響が流れていく先……深淵へ。", "倒してきた王たちの気配が、まだ残ってる。", "ここまで来たら、最後まで行こう。"],
	["もう、あの声は聞こえない。", "残響は、静かに眠ってる。", "それでも、もう少し深く潜ってみようか。", "段階を上げても、私は負けない。"],
]
const SPEECH_TIME := 4.0
# Room between the line and the end studs, and from the tail's tip to her face.
const SPEECH_GAP := 22.0
const SPEECH_REACH := 46.0
# Layout in the 1600×900 base viewport. The menu's rows stand in the pier's
# panel; the heroine stands about two thirds of the height tall.
const MENU_LEFT := 46.0
const MENU_WIDTH := 290.0
const MENU_TOP := 157.0
const ROW_HEIGHT := 72.0
# An entry's medallion: its size at rest, where it stands in its row, and
# how much larger the chosen one stands.
const ICON_SIZE := 54.0
const ICON_LEFT := 8.0
const ICON_CHOSEN := 1.14
const ICON_POP := 1.3
# The light over the chosen row reaches this far past the row's ends, and
# the glow behind its medallion is this wide.
const LIGHT_REACH := Vector2(26.0, 10.0)
const HALO := 104.0
# The panel centres in the floor between the menu and the heroine.
# How long the pointer must rest on an entry before it is chosen, so one
# crossed on the way to the panel's button is not.
const HOVER_INTENT := 0.1
const PANEL_CENTER_X := 0.474
const PANEL_WIDTH := 640.0
# Low enough that the altar and the foot of the stairs stay in view, its
# bottom edge on the heroine's floor line.
const PANEL_BOTTOM := 64.0
# Every entry shows the same panel: one size, the name and line at the top,
# the facts and the button at the bottom, so switching entries moves nothing.
const PANEL_HEIGHT := 270.0
const STRIP_HEIGHT := 60.0
# The texture keeps clear margins for swaying hair, so the figure itself
# stands about 78% of the screen tall.
const HERO_HEIGHT := 0.8
const HERO_CENTER_X := 0.835
const HERO_FEET_Y := 0.965
# How strongly the hall's light catches her edges: the gate's, the lamps'.
const RIM_COLD := 0.5
const RIM_WARM := 0.3
# The mark beside the upgrades' name: its room past the word, and its size.
const MARK_GAP := 16.0
const MARK_RADIUS := 6.0
# Bringing the lobby's things in and sending them off: how long the pier,
# the heroine and the plate take, how far each travels, and how much shorter
# all of it is on the way back from the departure.
const PILLAR_IN := 0.55
const HERO_IN := 0.7
const HERO_STEP := 46.0
const PANEL_IN := 0.4
const PANEL_WAIT := 0.42
const PANEL_RISE := 22.0
const QUICK := 0.6
const LEAVE_TIME := 0.24

var buttons: Array[Button] = []
var selected := 0
var decide_button: Button
# The mark on the upgrades' entry, shown while something can be bought, and
# the one on the bestiary's, shown while a new record waits to be looked up.
var upgrade_mark: Control
var codex_mark: Control
var title_label: Label
var description_label: Label
var hero: LobbyHero
var speech_label: Label
var _speech_index := 0
# The set of lines she speaks from now (SPEECHES).
var _lines: Array = SPEECHES[0]
# The entry under the pointer, or -1.
var _hover_index := -1
var _speech_token := 0
var _shadow_texture: GradientTexture2D
var hero_button: Button
var hero_speech: Panel
var upgrade_value: Label
var upgrade_ready: Label
var status_skills: Label
var status_hp: Label
var codex_met: Label
var codex_new: Label
var codex_runs: Label
var title_icon: TextureRect
# The pier and the menu's rows on it.
var menu: Control
# Her things are leaving for the departure: nothing here answers the pointer.
var leaving := false
var route_value: Label
var best_value: Label
var volume_value: Label
var display_value: Label
var settings: GameSettings
var panel: PanelContainer
var _art: TextureRect
var _details := {}
var _meta: MetaProgress
var _chapter: ChapterData
var _band_y := 0.0
var _band_tween: Tween
var _icons: Array[TextureRect] = []
var _light_texture: GradientTexture2D
var _shade_texture: GradientTexture2D
# How much of her is there (0 to 1), and how far to the right of her place
# she stands, as she steps in.
var _hero_share := 1.0
var _hero_slide := 0.0
var _stage: Tween
var _pops := {}


func _init() -> void:
	name = "Lobby"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_lights()
	_build_hero()
	_build_menu()
	_build_panel()
	# The speech bubble draws over the panel.
	move_child(hero_speech, get_child_count() - 1)
	resized.connect(_place_hero)
	_place_hero()
	_band_y = _row_rect(selected).position.y
	_show_entry()


# The soft lights the menu is drawn with: a round glow (the light over the
# chosen row, the halo behind its medallion) and the pier's shadow.
func _build_lights() -> void:
	var glow := Gradient.new()
	glow.set_color(0, Color.WHITE)
	glow.set_color(1, Color(1, 1, 1, 0))
	glow.add_point(0.45, Color(1, 1, 1, 0.42))
	_light_texture = GradientTexture2D.new()
	_light_texture.gradient = glow
	_light_texture.fill = GradientTexture2D.FILL_RADIAL
	_light_texture.fill_from = Vector2(0.5, 0.5)
	_light_texture.fill_to = Vector2(1.0, 0.5)
	var fall := Gradient.new()
	fall.set_color(0, Color.WHITE)
	fall.set_color(1, Color(1, 1, 1, 0))
	fall.add_point(0.3, Color(1, 1, 1, 0.5))
	_shade_texture = GradientTexture2D.new()
	_shade_texture.gradient = fall
	_shade_texture.fill_from = Vector2(0, 0.5)
	_shade_texture.fill_to = Vector2(1, 0.5)


func _build_menu() -> void:
	menu = Control.new()
	menu.name = "Menu"
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.draw.connect(_draw_menu)
	var previous: Button
	for index in ENTRIES.size():
		var entry: Array = ENTRIES[index]
		var button := Button.new()
		button.name = String(entry[0]).capitalize().replace(" ", "") + "Entry"
		button.text = tr(entry[1])
		button.theme_type_variation = &"LobbyMenuButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		menu.add_child(button)
		var row := _row_rect(index)
		button.position = row.position
		button.size = row.size
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = ICONS[entry[0]]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		icon.position = Vector2(ICON_LEFT, (row.size.y - ICON_SIZE) * 0.5)
		icon.size = Vector2.ONE * ICON_SIZE
		icon.pivot_offset = icon.size * 0.5
		_icons.append(icon)
		button.pressed.connect(_pressed.bind(index))
		button.focus_entered.connect(_focused.bind(index))
		button.mouse_entered.connect(_hovered.bind(index))
		button.mouse_exited.connect(_unhovered.bind(index))
		if previous != null:
			previous.focus_neighbor_bottom = button.get_path()
			button.focus_neighbor_top = previous.get_path()
		previous = button
		buttons.append(button)
		if entry[0] == &"upgrade":
			upgrade_mark = _build_mark(button)
		elif entry[0] == &"codex":
			codex_mark = _build_mark(button)
	buttons[0].focus_neighbor_top = buttons[0].get_path()
	buttons[-1].focus_neighbor_bottom = buttons[-1].get_path()


# The mark stands past the entry's name, level with the top of its letters.
func _build_mark(button: Button) -> Control:
	var mark := Control.new()
	mark.name = "Waiting"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(mark)
	var font := button.get_theme_font(&"font")
	var font_size := button.get_theme_font_size(&"font_size")
	var left := button.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT)
	var wide := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	mark.size = Vector2.ONE * MARK_RADIUS * 2.0
	mark.position = Vector2(left + wide + MARK_GAP, (button.size.y - font.get_height(font_size)) * 0.5 + MARK_RADIUS)
	mark.draw.connect(func():
		var colour := get_theme_color(&"waiting", &"HubLobby")
		mark.draw_circle(Vector2.ONE * MARK_RADIUS, MARK_RADIUS, colour)
		mark.draw_circle(Vector2.ONE * MARK_RADIUS, MARK_RADIUS * 0.4, get_theme_color(&"waiting_core", &"HubLobby")))
	mark.hide()
	return mark


func _row_rect(index: int) -> Rect2:
	return Rect2(Vector2(MENU_LEFT, MENU_TOP + index * ROW_HEIGHT), Vector2(MENU_WIDTH, ROW_HEIGHT))


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
	var ground := get_theme_color(&"plate", &"HubLobby")
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
	title_icon = TextureRect.new()
	title_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_icon.custom_minimum_size = Vector2(44, 44)
	title_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var route: HBoxContainer = HubUI.fact_strip(stack, STRIP_HEIGHT)
	_details[&"departure"] = route
	route_value = HubUI.strip_fact(route, tr("道のり"))
	HubUI.strip_divider(route)
	best_value = HubUI.strip_fact(route, tr("記録"))
	var growth: HBoxContainer = HubUI.fact_strip(stack, STRIP_HEIGHT)
	_details[&"upgrade"] = growth
	upgrade_value = HubUI.strip_fact(growth, tr("習得した段階"))
	HubUI.strip_divider(growth)
	upgrade_ready = HubUI.strip_fact(growth, tr("強化できる"))
	var loadout: HBoxContainer = HubUI.fact_strip(stack, STRIP_HEIGHT)
	_details[&"status"] = loadout
	status_skills = HubUI.strip_fact(loadout, tr("装備中のスキル"))
	HubUI.strip_divider(loadout)
	status_hp = HubUI.strip_fact(loadout, tr("最大HP"))
	var records: HBoxContainer = HubUI.fact_strip(stack, STRIP_HEIGHT)
	_details[&"codex"] = records
	codex_met = HubUI.strip_fact(records, tr("出会った敵"))
	HubUI.strip_divider(records)
	codex_new = HubUI.strip_fact(records, tr("新しい記録"))
	HubUI.strip_divider(records)
	codex_runs = HubUI.strip_fact(records, tr("探索の回数"))
	var current: HBoxContainer = HubUI.fact_strip(stack, STRIP_HEIGHT)
	_details[&"settings"] = current
	volume_value = HubUI.strip_fact(current, tr("音量"))
	HubUI.strip_divider(current)
	display_value = HubUI.strip_fact(current, tr("画面"))
	decide_button = HubUI.primary_action(stack, "", func(): activated.emit(selected_id()))
	# The lobby keeps its painted plate; the pages' actions are quiet.
	decide_button.theme_type_variation = &"LobbyAction"
	decide_button.name = "Decide"


func _build_hero() -> void:
	hero = LobbyHero.new()
	hero.name = "Hero"
	hero.texture = HERO_TEXTURE
	# Settle the bright illustration into the lantern light of the hall.
	hero.modulate = get_theme_color(&"hero_tint", &"HubLobby")
	# The gate's light is on her left, the stall's lamps on her right.
	hero.rim_left = Color(HubHall.GATE_COLOUR, RIM_COLD)
	hero.rim_right = Color(HubHall.LAMP_COLOUR, RIM_WARM)
	add_child(hero)
	hero_button = InkTooltip.HintButton.new()
	hero_button.name = "HeroButton"
	hero_button.theme_type_variation = &"CharacterButton"
	hero_button.tooltip_text = tr("話しかける")
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
	speech_label.text = tr(_lines[_speech_index % _lines.size()])
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
	hero.position = feet - Vector2(extent.x * 0.5, extent.y) + Vector2(_hero_slide, 0.0)
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


# Her lines for how far the journey has come: the chapters cleared in
# order, one set each, and the last set once the ending has been seen.
static func lines_for(meta: MetaProgress) -> Array:
	if meta.ending_seen():
		return SPEECHES.back()
	var cleared := 0
	for chapter in Chapters.ALL:
		if meta.clears_of(chapter.id) == 0:
			break
		cleared += 1
	return SPEECHES[mini(cleared, SPEECHES.size() - 2)]


func refresh(meta: MetaProgress, chapter: ChapterData) -> void:
	_meta = meta
	_chapter = chapter
	var lines := lines_for(meta)
	if lines != _lines:
		_lines = lines
		_speech_index = 0
	if chapter != null:
		route_value.text = tr("%d層とボス") % chapter.layers
		best_value.text = Chapters.record(meta, chapter)
	var ranks := 0
	var ready := 0
	for upgrade in MetaProgress.UPGRADES:
		ranks += meta.rank(upgrade.id)
		if meta.can_buy(upgrade.id):
			ready += 1
	upgrade_value.text = tr("%d 段階") % ranks
	upgrade_ready.text = tr("%d 件") % ready
	upgrade_mark.visible = ready > 0
	status_skills.text = "%d / %d" % [meta.loadout.filter(func(id: StringName): return not id.is_empty()).size(), MetaProgress.SKILL_SLOTS]
	status_hp.text = str(meta.tuning(load("res://data/hero/mio.tres")).max_hp)
	codex_met.text = "%d / %d" % [FoeCatalog.FOES.filter(func(foe: FoeData): return meta.has_met(foe.id)).size(), FoeCatalog.FOES.size()]
	var fresh := FoeCatalog.FOES.filter(func(foe: FoeData): return meta.is_new(foe.id)).size()
	codex_new.text = tr("%d 件") % fresh
	codex_mark.visible = fresh > 0
	codex_runs.text = tr("%d 回") % meta.runs
	if settings != null:
		volume_value.text = "%d%%" % settings.volume_percent()
		display_value.text = tr(GameSettings.DISPLAY_NAMES[1 if settings.fullscreen else 0])
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
	_pop(index)
	UIMotion.of(panel).reveal(UIMotion.SELECT_TIME)
	selection_changed.emit(selected_id())


func focus_selected() -> void:
	buttons[selected].grab_focus()


func _move_band(value: float) -> void:
	_band_y = value
	menu.queue_redraw()


# The medallion just chosen swells past its size and settles a little
# larger than the rest; the one let go goes back.
func _pop(index: int) -> void:
	for each in _icons.size():
		var icon := _icons[each]
		if _pops.has(each) and (_pops[each] as Tween).is_valid():
			(_pops[each] as Tween).kill()
		var tween := icon.create_tween()
		_pops[each] = tween
		if each == index:
			icon.scale = Vector2.ONE * ICON_POP
			tween.tween_property(icon, "scale", Vector2.ONE * ICON_CHOSEN, UIMotion.GOLD_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tween.tween_property(icon, "scale", Vector2.ONE, UIMotion.SELECT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# Keys and the gamepad choose by moving focus and press to enter; the pointer
# chooses by resting on an entry, so one click enters.
func _pressed(index: int) -> void:
	if not is_visible_in_tree() or leaving:
		return
	select(index)
	activated.emit(selected_id())


# Resting on an entry chooses it, and focus follows so keys go on from there.
func _hovered(index: int) -> void:
	_hover_index = index
	await get_tree().create_timer(HOVER_INTENT).timeout
	if _hover_index == index and is_visible_in_tree() and not leaving:
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
		_icons[index].modulate = get_theme_color(&"icon_lit" if chosen else &"icon_rest", &"HubLobby")
		if not _pops.has(index) or not (_pops[index] as Tween).is_running():
			_icons[index].scale = Vector2.ONE * (ICON_CHOSEN if chosen else 1.0)
	for key in _details:
		var detail: Control = _details[key]
		# Strips sit inside an inset panel and margin; show the outer one.
		# Each strip's row sits in its band.
		detail.get_parent().visible = key == id
	# The departure tells the chapter it opens on; the choosing is its page's.
	var departure := id == &"departure" and _chapter != null
	if departure:
		title_label.text = tr(_chapter.display_name)
		description_label.text = tr(_chapter.description)
		_art.texture = _chapter.illustration
	else:
		title_label.text = tr(ENTRIES[selected][1])
		description_label.text = tr(DESCRIPTIONS.get(id, ""))
		_art.texture = ART.get(id)
	# Only a line cut short needs its whole text on hover.
	var line_font := description_label.get_theme_font(&"font")
	var line_width := line_font.get_string_size(description_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, description_label.get_theme_font_size(&"font_size")).x
	description_label.tooltip_text = description_label.text if line_width > PANEL_WIDTH - 60.0 else ""
	title_icon.texture = ICONS[id]
	decide_button.visible = ACTIONS.has(id)
	decide_button.text = tr(ACTIONS.get(id, ""), "lobby")
	# Right from the menu reaches the panel's button.
	for button in buttons:
		button.focus_neighbor_right = decide_button.get_path()
	decide_button.focus_neighbor_left = buttons[selected].get_path()
	queue_redraw()
	if menu != null:
		menu.queue_redraw()


func _draw() -> void:
	# A soft pool of shade, and a darker contact shadow right under her boots,
	# ground the heroine on the floor.
	var feet := hero.position + hero.size * FEET
	var shadow := get_theme_color(&"shadow", &"HubLobby")
	shadow.a *= _hero_share
	draw_texture_rect(_shadow_texture, Rect2(feet - Vector2(200, 32), Vector2(400, 64)), false, Color(shadow, shadow.a * 0.7))
	for sole: Vector2 in SOLES:
		var at := hero.position + hero.size * sole
		draw_texture_rect(_shadow_texture, Rect2(at - Vector2(62, 11), Vector2(124, 22)), false, shadow)


# The pier with the game's emblem in its ring, its shadow on the hall beside
# it, and the light on the chosen row.
func _draw_menu() -> void:
	var scale := PILLAR_WIDTH / PILLAR.get_width()
	var tall := PILLAR.get_height() * scale
	menu.draw_texture_rect(_shade_texture, Rect2(PILLAR_WIDTH - 4.0, 0.0, PILLAR_SHADE, size.y), false, get_theme_color(&"pier_shade", &"HubLobby"))
	var stone := get_theme_color(&"pier_tint", &"HubLobby")
	menu.draw_texture_rect(PILLAR, Rect2(0.0, 0.0, PILLAR_WIDTH, tall), false, stone)
	# Past the picture's end the masonry of its foot carries on, mirrored
	# each time so the courses meet.
	var foot := PILLAR.get_height() * PILLAR_FOOT
	var part := Rect2(0.0, PILLAR.get_height() - foot, PILLAR.get_width(), foot)
	var y := tall
	var flipped := true
	while y < size.y:
		if flipped:
			menu.draw_set_transform(Vector2(0.0, y + foot * scale), 0.0, Vector2(1.0, -1.0))
			menu.draw_texture_rect_region(PILLAR, Rect2(0.0, 0.0, PILLAR_WIDTH, foot * scale), part, stone)
			menu.draw_set_transform(Vector2.ZERO)
		else:
			menu.draw_texture_rect_region(PILLAR, Rect2(0.0, y, PILLAR_WIDTH, foot * scale), part, stone)
		y += foot * scale
		flipped = not flipped
	# It stands in the hall's light: dark toward the screen's edge, and its
	# outer edge warm from the lamps beyond it.
	menu.draw_texture_rect(_shade_texture, Rect2(0.0, 0.0, PILLAR_WIDTH * 0.8, size.y), false, get_theme_color(&"pier_shade", &"HubLobby"))
	menu.draw_set_transform(Vector2(PILLAR_WIDTH - PILLAR_RIM_INSET, 0.0), 0.0, Vector2(-1.0, 1.0))
	menu.draw_texture_rect(_shade_texture, Rect2(0.0, 0.0, PILLAR_RIM, size.y), false, get_theme_color(&"pier_rim", &"HubLobby"))
	menu.draw_set_transform(Vector2.ZERO)
	var ring := Vector2(PILLAR_RING.x * PILLAR_WIDTH, PILLAR_RING.y * tall)
	var across := PILLAR_RING_ACROSS * PILLAR_WIDTH * EMBLEM_SHARE
	menu.draw_texture_rect(_light_texture, Rect2(ring - Vector2.ONE * across * 0.8, Vector2.ONE * across * 1.6), false, get_theme_color(&"emblem_glow", &"HubLobby"))
	menu.draw_texture_rect(EMBLEM, Rect2(ring - Vector2.ONE * across * 0.5, Vector2.ONE * across), false)
	# The chosen row: a warm light lying across it, strongest behind its
	# medallion, and a star where the row ends.
	var row := Rect2(Vector2(MENU_LEFT, _band_y), Vector2(MENU_WIDTH, ROW_HEIGHT))
	menu.draw_texture_rect(_light_texture, row.grow_individual(LIGHT_REACH.x, LIGHT_REACH.y, LIGHT_REACH.x, LIGHT_REACH.y), false, get_theme_color(&"band", &"HubLobby"))
	var medal := row.position + Vector2(ICON_LEFT + ICON_SIZE * 0.5, ROW_HEIGHT * 0.5)
	menu.draw_texture_rect(_light_texture, Rect2(medal - Vector2.ONE * HALO * 0.5, Vector2.ONE * HALO), false, get_theme_color(&"halo", &"HubLobby"))
	HubUI.mark(menu, Vector2(row.end.x - 10.0, row.get_center().y), 5.0, get_theme_color(&"rail", &"HubLobby"))


# --- Coming in and going off ---

# Everything in its place, nothing moving: as the lobby stands at rest.
func settle() -> void:
	if _stage != null:
		_stage.kill()
	leaving = false
	menu.position.x = 0.0
	menu.modulate.a = 1.0
	_set_hero(1.0, 0.0)
	UIMotion.of(panel).reset()


# Held back, out of sight, before present() brings them in.
func hold() -> void:
	if _stage != null:
		_stage.kill()
	leaving = false
	menu.position.x = -PILLAR_WIDTH - PILLAR_SHADE
	_set_hero(0.0, HERO_STEP)
	UIMotion.of(panel).reset()
	panel.modulate.a = 0.0


# The pier slides in from the left, she steps in from the right, and the
# plate rises after them. `quick` on the way back from the departure.
func present(quick: bool) -> void:
	hold()
	var pace := QUICK if quick else 1.0
	_stage = create_tween().set_parallel()
	_stage.tween_property(menu, "position:x", 0.0, PILLAR_IN * pace).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_stage.tween_method(_step_in, 0.0, 1.0, HERO_IN * pace).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	UIMotion.of(panel).enter(PANEL_WAIT * pace, Vector2(0.0, PANEL_RISE), PANEL_IN * pace)


# Off the ways they came, as the view goes up to the gate; then the lobby is
# hidden.
func leave() -> void:
	if _stage != null:
		_stage.kill()
	leaving = true
	hero_speech.hide()
	_stage = create_tween().set_parallel()
	_stage.tween_property(menu, "position:x", -PILLAR_WIDTH - PILLAR_SHADE, LEAVE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_stage.tween_method(_step_in, 1.0, 0.0, LEAVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	UIMotion.of(panel).fade_out(0.0, LEAVE_TIME * 0.6)
	_stage.chain().tween_callback(func():
		hide()
		settle())


func _step_in(share: float) -> void:
	_set_hero(share, HERO_STEP * (1.0 - share))


func _set_hero(share: float, slide: float) -> void:
	_hero_share = share
	_hero_slide = slide
	hero.modulate = Color(get_theme_color(&"hero_tint", &"HubLobby"), share)
	_place_hero()
