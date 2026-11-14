extends SceneTree

# The one theme (ui/theme/dungeon_theme.tres) and the base's screens built on
# it, held to what any look must keep: the theme is what its tokens make, no
# screen styles itself, the upgrades page's actions fit and say when they
# cannot be pressed, every state of an action is told apart (focus, chosen,
# disabled), buttons keep their margins in every state, text is large enough
# and reads against its page, and words over the fight stand on an opaque
# plate. How things look beyond that (frames, plates, surfaces) is a choice
# described in docs/画面とUI.md and judged on the captures
# (tools/compare_captures.py), not checked here.

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
	# The bundled gothic for the body, buttons and figures; titles keep the
	# display face.
	check(theme.default_font != null and theme.default_font.resource_path.ends_with("BIZUDPGothic-Regular.ttf"), "The body text uses the bundled BIZ UDPGothic")
	check(FileAccess.file_exists("res://art/third_party/biz_udp_gothic/OFL.txt") and FileAccess.file_exists("res://art/third_party/biz_udp_gothic/SOURCE.txt"), "The font's licence and source are bundled beside it")
	check_tokens(theme)
	check_moods(theme)
	var main: Node = load("res://game/main.tscn").instantiate()
	main.show_prologue = false
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
	# The status page wears its mood; the header above it keeps the one theme.
	var mood_theme := ThemeMood.theme_of(&"status", theme)
	if mood_theme != null:
		check(hub.status_page.theme == mood_theme, "The status page wears its mood")
		check(hub.status_page.get_theme_color(&"lit_ring", &"LoadoutSlot") == mood_theme.get_color(&"lit_ring", &"LoadoutSlot"), "What is drawn on the status page takes the mood's colours")
		check(hub.echo_label.get_theme_color(&"font_color") == theme.get_color(&"font_color", &"GoldLabel"), "The header above it keeps the one theme's")
	hub.show_page("upgrade")
	for frame in 3:
		await process_frame
	var upgrades: MetaUpgradePage = hub.upgrade_page
	var cheap: Button = upgrades.buy_button
	(upgrades.nodes[MetaProgress.ROOT] as Button).grab_focus()
	check(not cheap.disabled and cheap.tooltip_text.is_empty(), "An upgrade the echo pays for can be bought")
	(upgrades.nodes[&"sturdy_body"] as Button).grab_focus()
	check(cheap.disabled and cheap.tooltip_text.contains("残響の灯"), "One whose root is not held is off and says what it waits for")
	main.meta.ranks[String(MetaProgress.ROOT)] = 1
	hub.refresh(main.meta)
	(upgrades.nodes[&"double_dash"] as Button).grab_focus()
	check(cheap.disabled and cheap.tooltip_text.contains("鍛えた体"), "So does one further along")
	(upgrades.nodes[&"sturdy_body"] as Button).grab_focus()
	main.meta.echo = 10
	hub.refresh(main.meta)
	check(cheap.disabled and cheap.tooltip_text.contains("足りない"), "One the echo cannot pay for says how much is missing")
	main.meta.echo = 100
	main.meta.ranks.clear()
	hub.refresh(main.meta)
	(upgrades.nodes[MetaProgress.ROOT] as Button).grab_focus()
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
	check(focus != null and not focus.draw_center and focus.border_width_left >= 2, "Focus overlays a visible outline without hiding state")
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
	# A secondary action that can be pressed must never look like one that
	# cannot.
	for state in [&"normal", &"hover", &"focus", &"pressed", &"hover_pressed", &"disabled"]:
		check(theme.has_stylebox(state, &"SecondaryButton"), "SecondaryButton has its own %s look" % state)
	check(theme.get_color(&"font_color", &"SecondaryButton") != theme.get_color(&"font_disabled_color", &"SecondaryButton"), "A secondary action looks different when it cannot be pressed")
	# A question's chosen answer is told apart from the others, and one that
	# cannot be undone is drawn in red.
	check(theme.get_color(&"lit_edge", &"BandButton") != theme.get_color(&"edge", &"BandButton"), "The chosen answer's edge turns gold")
	check(theme.get_type_variation_base(&"BandDangerButton") == &"BandButton" and theme.get_color(&"lit_edge", &"BandDangerButton").r > theme.get_color(&"lit_edge", &"BandDangerButton").g + 0.2, "An answer that cannot be undone is drawn in red")
	# The help's chosen topic is told apart from the others.
	check(theme.get_color(&"font_pressed_color", &"HelpTopic") != theme.get_color(&"font_color", &"HelpTopic"), "A help topic is chosen by its lit words")
	var primary := theme.get_stylebox(&"normal", &"PrimaryButton") as StyleBoxFlat
	check((theme.get_stylebox(&"focus", &"PrimaryButton") as StyleBoxFlat).border_width_top > primary.border_width_top, "A focused primary action draws a stronger edge")
	check(theme.get_stylebox(&"normal", &"LobbyAction") is StyleBoxTexture, "The lobby keeps its painted plate")
	# A chosen or focused item card is told apart by its frame.
	var card_chosen := theme.get_stylebox(&"pressed", &"CardButton") as StyleBoxFlat
	check(card_chosen.border_width_top > 0 and (theme.get_stylebox(&"focus", &"CardButton") as StyleBoxFlat).border_width_top > 0, "A chosen or focused card gets its frame")
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
	for pair: Array in [[&"font_size", &"NoteLabel"], [&"font_size", &"MutedLabel"], [&"font_size", &"LobbyFactCaption"], [&"cap_font_size", &"KeyGuideButton"], [&"font_size", &"KeyGuideButton"], [&"font_size", &"CategoryCap"], [&"font_size", &"HintMark"], [&"font_size", &"TextAction"], [&"font_size", &"SecondaryButton"]]:
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
