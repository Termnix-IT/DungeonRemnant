extends SceneTree

# The one theme (ui/theme/dungeon_theme.tres) and the base's screens built on
# it, held to what any look must keep: the theme is what its tokens make, no
# screen styles itself, the upgrades page's actions fit and say when they
# cannot be pressed, every state of an action is told apart (focus, chosen,
# disabled), buttons keep their margins in every state, text is large enough
# and reads against its page, a page that draws itself does so in colours
# whose readability is measured, words over the fight stand on an opaque
# plate, and every face ships with the game beside its licence. How things
# look beyond that (frames, plates, surfaces, which face, which page shares
# which type) is a choice described in docs/画面とUI.md and judged on the
# captures (tools/compare_captures.py), not checked here. A look held on
# purpose says why where it is checked.

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func inspect_styles(node: Node) -> void:
	# A key cap's hint widens its own left padding to fit its cap (KeyGuide._fit):
	# a layout measure of the cap, not a style chosen per screen.
	if node is Control and (node as Control).theme_type_variation == &"KeyGuideButton":
		return
	if node is Control:
		var overrides: Array[String] = []
		for property in node.get_property_list():
			if str(property.name).begins_with("theme_override_") and node.get(property.name) != null:
				overrides.append(property.name)
		check(overrides.is_empty(), "%s inherits theme without overrides: %s" % [node.name, overrides])
	for child in node.get_children():
		inspect_styles(child)


# Every colour and font size in the theme is bound to a token and is what the
# token makes (tools/build_theme.gd was run after the last change), and
# turning a family moves its colours everywhere and nothing else.
func check_tokens(theme: Theme) -> void:
	var tokens := ThemeTokens.current()
	var bindings := ThemeBindings.current()
	var problems := ThemeBuild.problems(theme, tokens, bindings)
	check(problems.is_empty(), "The theme is what its tokens make: %s" % "; ".join(problems.slice(0, 5)))
	var gold_place := ""
	var other_place := ""
	for place: String in bindings.colors:
		var family := ThemeTokens.family_of(ThemeBindings.parse_color(bindings.colors[place])[0])
		if family == &"gold" and gold_place.is_empty():
			gold_place = place
		elif family == &"neutral" and other_place.is_empty():
			other_place = place
	var copy := theme.duplicate(true) as Theme
	var turned := tokens.duplicate(true) as ThemeTokens
	turned.families[&"gold"] = Vector3(-12.0, 0.8, 1.0)
	var written := ThemeBuild.apply(copy, turned, bindings)
	check(written.has(gold_place) and not written.has(other_place), "Turning the gold family rewrites the golds and leaves the others")
	check(not (ThemeBuild.read(copy, gold_place) as Color).is_equal_approx(ThemeBuild.read(theme, gold_place)), "A turned gold differs from the shipped one")


# Each screen's mood (ui/theme/moods/) turns only tokens there are, is the
# one theme with those tokens written and nothing else, and keeps its words
# readable.
func check_moods(theme: Theme) -> void:
	var tokens := ThemeTokens.current()
	var bindings := ThemeBindings.current()
	if not DirAccess.dir_exists_absolute(ThemeMood.FOLDER):
		return
	for file in DirAccess.get_files_at(ThemeMood.FOLDER):
		if not file.ends_with(".tres"):
			continue
		var page := StringName(file.get_basename())
		var mood := ThemeMood.of(page)
		for family: StringName in mood.families:
			check(tokens.families.has(family), "The %s mood turns a family there is (%s)" % [page, family])
		for token: StringName in mood.colors:
			check(tokens.colors.has(token), "The %s mood recolours a token there is (%s)" % [page, token])
		var built := mood.build(theme, tokens, bindings)
		var problems := ThemeBuild.problems(built, mood.turn(tokens), bindings)
		check(problems.is_empty(), "The %s mood is the one theme in its tokens: %s" % [page, "; ".join(problems.slice(0, 3))])
		check_contrast(built, "The %s mood" % page)


func run_tests() -> void:
	var theme := preload("res://ui/theme/dungeon_theme.tres")
	check_fonts(theme)
	check_tokens(theme)
	check_moods(theme)
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
	main.show_opening = false
	main.saving_enabled = false
	main.meta.echo = 100
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	for page in ["sortie", "upgrade", "status", "codex", "settings", "home"]:
		hub.show_page(page)
		for frame in 3:
			await process_frame
	inspect_styles(hub.get_node("Content"))
	# A page with a mood of its own wears it; the header above keeps the one theme.
	for page: String in ["sortie", "upgrade", "status", "codex", "settings"]:
		var mood_theme := ThemeMood.theme_of(StringName(page), theme)
		if mood_theme != null:
			check(hub.get(page + "_page").theme == mood_theme, "The %s page wears its mood" % page)
	check(hub.echo_label.get_theme_color(&"font_color") == theme.get_color(&"font_color", &"GoldLabel"), "The header keeps the one theme's colours")
	for drawn: Control in [hub.sortie_page, hub.upgrade_page, hub.status_page, hub.codex_page, hub.settings_page, hub.settings_page.help_view]:
		check_drawn_page(drawn, theme)
	hub.show_page("upgrade")
	for frame in 3:
		await process_frame
	var upgrades: MetaUpgradePage = hub.upgrade_page
	var cheap: Button = upgrades.buy_button
	upgrades.choose(MetaProgress.ROOT)
	check(not cheap.disabled and cheap.tooltip_text.is_empty(), "An upgrade the echo pays for can be bought")
	upgrades.choose(&"sturdy_body")
	check(cheap.disabled and cheap.tooltip_text.contains("残響の灯"), "One whose root is not held is off and says what it waits for")
	main.meta.ranks[String(MetaProgress.ROOT)] = 1
	hub.refresh(main.meta)
	upgrades.choose(&"double_dash")
	check(cheap.disabled and cheap.tooltip_text.contains("鍛えた体"), "So does one further along")
	upgrades.choose(&"sturdy_body")
	main.meta.echo = 10
	hub.refresh(main.meta)
	check(cheap.disabled and cheap.tooltip_text.contains("足りない"), "One the echo cannot pay for says how much is missing")
	main.meta.echo = 100
	main.meta.ranks.clear()
	hub.refresh(main.meta)
	upgrades.choose(MetaProgress.ROOT)
	check(upgrades.get_global_rect().grow(1).encloses(cheap.get_global_rect()), "%s fits the page" % cheap.text)
	# The upgrade's buy button is a crest, drawing its own states; its styles
	# only make room for the crest, the same in every state so it never moves.
	# The other screens' primary action keeps a style for each state.
	for state in ["hover", "pressed", "disabled", "focus"]:
		check(theme_style(theme, state, &"CrestAction") == theme_style(theme, "normal", &"CrestAction"), "The crest keeps one room for its words when " + state)
	var normal := theme_style(theme, "normal", &"PrimaryAction")
	for state in ["hover", "pressed", "disabled", "focus"]:
		check(theme_style(theme, state, &"PrimaryAction") != normal, "The primary action has a distinct " + state)
	var focus := theme_style(theme, "focus", &"PrimaryAction") as StyleBoxFlat
	check(focus != null and not focus.draw_center and widest_edge(focus) >= 2, "Focus overlays a visible outline without hiding state")
	check(cheap.get_theme_color("font_disabled_color") != cheap.get_theme_color("font_color"), "Disabled text is distinct")
	check(theme_style(theme, "focus", &"PrimaryAction") == hub.back_button.get_theme_stylebox("focus"), "Buttons share one focus resource")
	var original := theme.get_color("font_color", "GoldLabel")
	var probe := Color(0.7, 0.8, 0.9)
	theme.set_color("font_color", "GoldLabel", probe)
	check(hub.echo_label.get_theme_color("font_color") == probe and hub.feedback.get_theme_color("font_color") == probe, "One theme edit reaches the header's echo and the notes in gold")
	theme.set_color("font_color", "GoldLabel", original)
	main.free()
	var frame := theme.get_stylebox("panel", "MainPanel") as StyleBoxTexture
	check(frame != null and frame.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT and frame.axis_stretch_vertical == StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT, "Panel grain tiles at one scale instead of stretching")
	check_steady_buttons(theme)
	check_readable_floor(theme)
	check_contrast(theme)
	check_book(theme)
	check_chart(theme)
	check_vista(theme)
	check_gates(theme)
	check_stage(theme)
	check(HubUI.STAR_WAIST_SMALL > HubUI.STAR_WAIST and HubUI.STAR_SCALE > 1.0, "A small star keeps a fuller waist than a large one, so it does not read as a plus sign")
	# A secondary action that can be pressed must never look like one that
	# cannot.
	for state in [&"normal", &"hover", &"focus", &"pressed", &"hover_pressed", &"disabled"]:
		check(theme.has_stylebox(state, &"SecondaryButton"), "SecondaryButton has its own %s look" % state)
	check(theme.get_color(&"font_color", &"SecondaryButton") != theme.get_color(&"font_disabled_color", &"SecondaryButton"), "A secondary action looks different when it cannot be pressed")
	# A question's chosen answer is told apart from the others, and one that
	# cannot be undone is drawn in red.
	check(theme.get_color(&"lit_edge", &"BandButton") != theme.get_color(&"edge", &"BandButton"), "The chosen answer's edge turns gold")
	check(theme.get_type_variation_base(&"BandDangerButton") == &"BandButton" and theme.get_color(&"lit_edge", &"BandDangerButton").r > theme.get_color(&"lit_edge", &"BandDangerButton").g + 0.2, "An answer that cannot be undone is drawn in red")
	check(looks_apart(theme_style(theme, "focus", &"PrimaryButton"), theme_style(theme, "normal", &"PrimaryButton")), "A focused primary action is told apart from one at rest")
	# Kept on purpose: the user chose the lobby's look on 2026-11-20 and asked
	# to be asked before it changes (CLAUDE.md), so its painted plate is held.
	check(theme.get_stylebox(&"normal", &"LobbyAction") is StyleBoxTexture, "The lobby keeps its painted plate")
	# A chosen item card and a focused one are each told apart from one at
	# rest and from each other, so a gamepad tells where it is from what it
	# took. How each is drawn is a choice.
	var card_rest := theme_style(theme, "normal", &"CardButton")
	var card_chosen := theme_style(theme, "pressed", &"CardButton")
	var card_focus := theme_style(theme, "focus", &"CardButton")
	check(looks_apart(card_chosen, card_rest) and looks_apart(card_focus, card_rest) and looks_apart(card_focus, card_chosen), "A chosen card, a focused card and one at rest are told apart")
	# A level-up card floats over the fight, so its words need a plate that
	# hides the floor behind them.
	var plate := theme.get_stylebox(&"plate", &"AbilityCard") as StyleBoxFlat
	check(plate != null and plate.bg_color.a > 0.9, "A level-up card stands on an opaque plate of its own")
	# The fight's HUD reads on any floor: its edges are shaded and its words outlined.
	check(theme.get_color(&"shade", &"HudEdge").a > 0.3 and theme.get_constant(&"outline_size", &"HpCaption") > 0, "The HUD's edges are shaded and its health caption outlined")
	check(theme.get_color(&"font_color", &"SecondaryButton").get_luminance() - theme.get_color(&"font_disabled_color", &"SecondaryButton").get_luminance() > 0.3, "Its words dim when it cannot be pressed")
	# The fight's dialogs hide the floor behind their words.
	var dialog := theme.get_stylebox(&"panel", &"MainPanel") as StyleBoxTexture
	var middle := dialog.texture.get_image().get_pixel(dialog.texture.get_width() / 2, dialog.texture.get_height() / 2)
	check(middle.a > 0.9, "The dialogs' plate is nearly opaque")
	print("UI theme: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


# The base's smallest text, key caps included: 16px at 1600x900 is about
# 19px at 1080p, above the 18px floor of Xbox Accessibility Guideline 101
# for PC. The fight's HUD (Hud*) keeps its own sizes.
func check_readable_floor(theme: Theme) -> void:
	for pair: Array in [[&"font_size", &"NoteLabel"], [&"font_size", &"MutedLabel"], [&"font_size", &"LobbyFactCaption"], [&"cap_font_size", &"KeyGuideButton"], [&"font_size", &"KeyGuideButton"], [&"font_size", &"CategoryCap"], [&"font_size", &"HintMark"], [&"label_size", &"SettingsStage"], [&"font_size", &"SecondaryButton"]]:
		check(theme.get_font_size(pair[0], pair[1]) >= 16, "%s %s stays at 16px or more" % [pair[1], pair[0]])
	# Notes share the muted size, so they step down by tone instead.
	check(theme.get_color(&"font_color", &"NoteLabel") != theme.get_color(&"font_color", &"MutedLabel"), "Notes stay a step quieter than muted text")


# A button whose state style has other margins than its rest style would
# move its neighbours, or cut its own text, on hover or when disabled.
func check_steady_buttons(theme: Theme) -> void:
	for type in theme.get_type_list():
		if not theme_reaches(theme, type, &"Button"):
			continue
		var rest := theme_style(theme, "normal", type)
		if rest == null:
			continue
		for state in ["hover", "pressed", "hover_pressed", "disabled"]:
			var style := theme_style(theme, state, type)
			if style == null:
				continue
			var same := true
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				same = same and is_equal_approx(style.get_margin(side), rest.get_margin(side))
			check(same, "%s keeps its margins when %s" % [type, state])


# Every face the theme sets ships with the game, so the words look the same
# on any PC, and its licence lies beside it (the SIL Open Font License asks
# for its whole text to travel with the font). Which faces are used is a
# choice and not checked.
const LICENCE_FILES := ["OFL.txt", "LICENSE.txt", "LICENSE"]


func check_fonts(theme: Theme) -> void:
	var fonts: Array[Font] = [theme.default_font]
	for type in theme.get_font_type_list():
		for item in theme.get_font_list(type):
			fonts.append(theme.get_font(item, type))
	var folders := {}
	for font in fonts:
		var file := bundled_file(font)
		check(file != null and file.resource_path.begins_with("res://"), "Every face the theme sets is a font file bundled with the game (%s)" % font)
		if file != null:
			folders[file.resource_path.get_base_dir()] = true
	for folder: String in folders:
		var licensed := false
		for licence: String in LICENCE_FILES:
			licensed = licensed or FileAccess.file_exists(folder.path_join(licence))
		check(licensed, "The fonts in %s have their licence beside them" % folder)


# The font file a face is drawn from: itself, or the one a variation is cut
# from. A system font has none, and would look different on another PC.
func bundled_file(font: Font) -> FontFile:
	if font is FontFile:
		return font
	if font is FontVariation:
		return bundled_file((font as FontVariation).base_font) if (font as FontVariation).base_font != null else null
	return null


# The types whose words are measured against their grounds below
# (check_book and the others). A page that draws itself must take its
# colours from one of them, so a change of those colours is checked for
# readability. Which page shares which type is a choice and not checked.
const MEASURED_TYPES := [&"StarChart", &"Bestiary", &"Vista", &"SettingsStage", &"Gates"]


func check_drawn_page(page: Control, theme: Theme) -> void:
	var type := page.theme_type_variation
	check(type in MEASURED_TYPES, "%s draws itself in a type whose words are measured (%s)" % [page.name, type])
	var items := colour_items(theme, type)
	var own: Theme = page.theme if page.theme != null else theme
	check(not items.is_empty() and page.get_theme_color(items[0]) == theme_color(own, items[0], type), "%s reads its colours from the theme" % page.name)


func colour_items(theme: Theme, type: StringName) -> Array[StringName]:
	var items: Array[StringName] = []
	while type != &"":
		for item in theme.get_color_list(type):
			if not items.has(StringName(item)):
				items.append(StringName(item))
		type = theme.get_type_variation_base(type)
	return items


func font_size_items(theme: Theme, type: StringName) -> Array[StringName]:
	var items: Array[StringName] = []
	while type != &"":
		for item in theme.get_font_size_list(type):
			if not items.has(StringName(item)):
				items.append(StringName(item))
		type = theme.get_type_variation_base(type)
	return items


func theme_size(theme: Theme, item: StringName, type: StringName) -> int:
	while type != &"":
		if theme.has_font_size(item, type):
			return theme.get_font_size(item, type)
		type = theme.get_type_variation_base(type)
	return 0


# Two states look apart when one draws something the other does not: a face,
# another colour, another edge. A state that draws nothing looks like none.
func looks_apart(a: StyleBox, b: StyleBox) -> bool:
	if a == null or a is StyleBoxEmpty:
		return false
	if b == null or b is StyleBoxEmpty:
		return true
	if a is StyleBoxFlat and b is StyleBoxFlat:
		var x := a as StyleBoxFlat
		var y := b as StyleBoxFlat
		if x.draw_center != y.draw_center or (x.draw_center and not x.bg_color.is_equal_approx(y.bg_color)):
			return true
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			if x.get_border_width(side) != y.get_border_width(side):
				return true
		return widest_edge(x) > 0 and not x.border_color.is_equal_approx(y.border_color)
	return a != b


func widest_edge(style: StyleBoxFlat) -> int:
	return maxi(maxi(style.border_width_left, style.border_width_right), maxi(style.border_width_top, style.border_width_bottom))


func theme_reaches(theme: Theme, type: StringName, base: StringName) -> bool:
	while type != &"":
		if type == base:
			return true
		type = theme.get_type_variation_base(type)
	return false


func theme_style(theme: Theme, state: String, type: StringName) -> StyleBox:
	while type != &"":
		if theme.has_stylebox(state, type):
			return theme.get_stylebox(state, type)
		type = theme.get_type_variation_base(type)
	return null


# Words read against the page they stand on: the base's text roles keep the
# 4.5:1 of WCAG 2.2 AA (SC 1.4.3) against a page's panel laid over the darkest
# background, and on an item card's face over it; words that cannot be pressed
# stay at 3:1, dim but legible. The colours are measured, not the pixels, so a
# role's colour changed in the tokens is checked here.
const READABLE_ROLES := [
	[&"font_color", &"BodyLabel"], [&"font_color", &"DescriptionLabel"], [&"font_color", &"ItemNameLabel"],
	[&"font_color", &"ValueLabel"], [&"font_color", &"MutedLabel"], [&"font_color", &"NoteLabel"],
	[&"font_color", &"GoldLabel"], [&"font_color", &"StatUp"], [&"font_color", &"StatDown"],
	[&"font_color", &"TitleLabel"], [&"font_color", &"HeadingLabel"], [&"font_color", &"PrimaryButton"],
	[&"font_color", &"SecondaryButton"], [&"font_color", &"KeyGuideButton"],
]
const DIM_ROLES := [[&"font_disabled_color", &"SecondaryButton"]]
const DARKEST_BACKGROUND := Color(0.008, 0.012, 0.02)


func check_contrast(theme: Theme, label := "The theme") -> void:
	var slab := theme.get_stylebox(&"panel", &"SlabSolid") as QuietWindowStyle
	var page := DARKEST_BACKGROUND.lerp(Color(slab.fill, 1.0), slab.fill.a)
	var card_face := theme_style(theme, "normal", &"CardButton") as StyleBoxFlat
	var card := page.lerp(Color(card_face.bg_color, 1.0), card_face.bg_color.a)
	for role: Array in READABLE_ROLES:
		var colour := theme_color(theme, role[0], role[1])
		check(contrast(colour, page) >= 4.5 and contrast(colour, card) >= 4.5, "%s: %s %s reads at 4.5:1 or more (%.1f on a page)" % [label, role[1], role[0], contrast(colour, page)])
	for role: Array in DIM_ROLES:
		var colour := theme_color(theme, role[0], role[1])
		check(contrast(colour, page) >= 3.0, "%s: %s %s stays legible at 3:1 or more (%.1f)" % [label, role[1], role[0], contrast(colour, page)])


# The bestiary's folio is ink on parchment: its words keep 4.5:1 against
# the darkest the paper gets, its faded words (things not learned) 3:1, the
# words on its ribbons and its tray read on them, and no text is smaller
# than 14px. The colours are read as the folio resolves them, through
# whatever type it is built on.
func check_book(theme: Theme) -> void:
	var folio := &"Bestiary"
	var paper := theme_color(theme, &"page_dark", folio)
	for item: StringName in [&"ink", &"sepia", &"seal", &"note"]:
		var colour := theme_color(theme, item, folio)
		check(contrast(colour, paper) >= 4.5, "The folio's %s reads on its paper at 4.5:1 or more (%.1f)" % [item, contrast(colour, paper)])
	check(contrast(theme_color(theme, &"faint", folio), paper) >= 3.0, "The folio's faded words stay legible at 3:1 or more (%.1f)" % contrast(theme_color(theme, &"faint", folio), paper))
	check(contrast(theme_color(theme, &"seal_light", folio), theme_color(theme, &"seal", folio)) >= 4.5, "The letter pressed in the wax reads on it")
	for item in font_size_items(theme, folio):
		check(theme_size(theme, item, folio) >= 14, "The folio's %s stays at 14px or more" % item)
	var pale := theme_color(theme, &"seal_light", folio)
	for item: StringName in [&"ribbon_0", &"ribbon_1", &"ribbon_2", &"ribbon_3", &"tray"]:
		check(contrast(pale, theme_color(theme, item, folio)) >= 4.5, "The folio's words read on its %s (%.1f)" % [item, contrast(pale, theme_color(theme, item, folio))])


# The upgrades page's star chart: its words read on the night they are
# written on (the card's panel, the plates behind the stars' names and the
# sky itself), and none is smaller than 14px.
func check_chart(theme: Theme) -> void:
	for ground: StringName in [&"panel", &"void", &"sky_light"]:
		var night := theme.get_color(ground, &"StarChart")
		for item: StringName in [&"pale", &"dim", &"gold", &"blue", &"warn"]:
			var colour := theme.get_color(item, &"StarChart")
			check(contrast(colour, night) >= 4.5, "The chart's %s reads on its %s at 4.5:1 or more (%.1f)" % [item, ground, contrast(colour, night)])
		check(contrast(theme.get_color(&"faint", &"StarChart"), night) >= 3.0, "The chart's faded names stay legible on its %s at 3:1 or more" % ground)
	check(contrast(theme.get_color(&"gold", &"StarChart"), theme.get_color(&"dark", &"StarChart")) >= 3.0, "A star held and one that waits differ in more than hue")
	for item in theme.get_font_size_list(&"StarChart"):
		check(theme.get_font_size(item, &"StarChart") >= 14, "The chart's %s stays at 14px or more" % item)


# The departure's vista: its words stand on the dark falls laid over the
# painting, so they are measured against the night those falls run to.
func check_vista(theme: Theme) -> void:
	var night := theme.get_color(&"night", &"Vista")
	for item: StringName in [&"pale", &"dim", &"gold", &"warn"]:
		var colour := theme.get_color(item, &"Vista")
		check(contrast(colour, night) >= 4.5, "The vista's %s reads on its night at 4.5:1 or more (%.1f)" % [item, contrast(colour, night)])
	check(theme.get_color(&"plate", &"Vista").a >= 0.6, "The step's plate hides the painting behind its words")
	check(theme.get_color(&"art_locked", &"Vista").get_luminance() < 0.3, "A sealed chapter's painting is dark")
	for item in theme.get_font_size_list(&"Vista"):
		check(theme.get_font_size(item, &"Vista") >= 14, "The vista's %s stays at 14px or more" % item)


# The route's gates: their words stand on the night the painting falls into
# and on the card under the thread, each reward's light among them, and none
# is smaller than 14px.
func check_gates(theme: Theme) -> void:
	var plate := theme.get_color(&"plate", &"Gates")
	check(plate.a >= 0.9, "The thread's card hides the gates behind its words")
	plate.a = 1.0
	for ground: Color in [theme.get_color(&"night", &"Gates"), plate]:
		for item: StringName in [&"pale", &"dim", &"boon", &"heal", &"echo", &"event", &"boss"]:
			var colour := theme.get_color(item, &"Gates")
			check(contrast(colour, ground) >= 4.5, "The gates' %s reads on their dark at 4.5:1 or more (%.1f)" % [item, contrast(colour, ground)])
		check(contrast(theme.get_color(&"faint", &"Gates"), ground) >= 3.0, "The gates' empty marks stay legible at 3:1 or more")
	var lights: Array[Color] = []
	for item: StringName in [&"boon", &"heal", &"echo", &"event", &"boss"]:
		lights.append(theme.get_color(item, &"Gates"))
	for index in lights.size():
		for other in range(index + 1, lights.size()):
			check(absf(lights[index].h - lights[other].h) > 0.06 and absf(lights[index].h - lights[other].h) < 0.94, "No two gates' lights are of one hue")
	check(theme.get_color(&"art", &"Gates").get_luminance() < 0.3 and theme.get_color(&"shape", &"Gates").get_luminance() < 0.05, "The far painting and a foe not turned to are dark")
	for item in theme.get_font_size_list(&"Gates"):
		check(theme.get_font_size(item, &"Gates") >= 14, "The gates' %s stays at 14px or more" % item)


# The settings' list and stage: their words stand on the stage's dark face
# or on the veil laid over the hall.
func check_stage(theme: Theme) -> void:
	for ground: StringName in [&"ink", &"veil", &"scene"]:
		var face := theme.get_color(ground, &"SettingsStage")
		face.a = 1.0
		for item: StringName in [&"pale", &"dim", &"gold", &"warn"]:
			var colour := theme.get_color(item, &"SettingsStage")
			check(contrast(colour, face) >= 4.5, "The settings' %s reads on its %s at 4.5:1 or more (%.1f)" % [item, ground, contrast(colour, face)])
	for item in theme.get_font_size_list(&"SettingsStage"):
		check(theme.get_font_size(item, &"SettingsStage") >= 14, "The settings' %s stays at 14px or more" % item)


func theme_color(theme: Theme, item: StringName, type: StringName) -> Color:
	var at := type
	while at != &"":
		if theme.has_color(item, at):
			return theme.get_color(item, at)
		at = theme.get_type_variation_base(at)
	return theme.get_color(item, &"Label")


static func contrast(a: Color, b: Color) -> float:
	var x := relative_luminance(a)
	var y := relative_luminance(b)
	return (maxf(x, y) + 0.05) / (minf(x, y) + 0.05)


static func relative_luminance(colour: Color) -> float:
	var linear := colour.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b
