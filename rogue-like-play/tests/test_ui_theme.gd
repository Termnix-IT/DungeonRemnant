extends SceneTree

# The one theme (ui/theme/dungeon_theme.tres) and the base's screens built on
# it: no screen styles itself, the upgrades page's actions fit and say when
# they cannot be pressed, one theme edit reaches every gold, buttons keep
# their margins in every state, the smallest text stays readable, panels
# tile their grain, wells sit darker than cards, scroll bars are bronze
# rails, and dialogs stand on the warm stone plate.

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


func run_tests() -> void:
	var theme := preload("res://ui/theme/dungeon_theme.tres")
	# The bundled gothic for the body, buttons and figures; titles keep the
	# display face.
	check(theme.default_font != null and theme.default_font.resource_path.ends_with("BIZUDPGothic-Regular.ttf"), "The body text uses the bundled BIZ UDPGothic")
	check(theme.get_font(&"font", &"ValueLabel").resource_path.ends_with("BIZUDPGothic-Bold.ttf") and theme.get_font(&"font", &"HudValue").resource_path.ends_with("BIZUDPGothic-Bold.ttf"), "Figures use its bold weight")
	check((theme.get_font(&"font", &"TitleLabel") as FontVariation).base_font.resource_path.ends_with("ShipporiMincho-Bold.ttf"), "Titles keep the display face")
	check(FileAccess.file_exists("res://art/third_party/biz_udp_gothic/OFL.txt") and FileAccess.file_exists("res://art/third_party/biz_udp_gothic/SOURCE.txt"), "The font's licence and source are bundled beside it")
	var main: Node = load("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.meta.echo = 100
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.refresh(main.meta)
	for page in ["upgrade", "codex", "settings", "home"]:
		hub.show_page(page)
		for frame in 3:
			await process_frame
	inspect_styles(hub.get_node("Content"))
	hub.show_page("upgrade")
	for frame in 3:
		await process_frame
	var upgrades: MetaUpgradePage = hub.upgrade_page
	var cheap: Button = upgrades.buttons[0]
	var dear: Button = upgrades.buttons[1]
	check(not cheap.disabled and dear.disabled, "An upgrade the echo pays for can be bought; one it cannot is off")
	check(not dear.tooltip_text.is_empty(), "One the echo cannot pay for says how much is missing")
	for button in upgrades.buttons:
		check(upgrades.get_global_rect().grow(1).encloses(button.get_global_rect()), "%s fits the page" % button.text)
	var normal := cheap.get_theme_stylebox("normal")
	for state in ["hover", "pressed", "disabled", "focus"]:
		check(cheap.get_theme_stylebox(state) != normal, "The gold button has a distinct " + state)
	var focus := cheap.get_theme_stylebox("focus") as StyleBoxFlat
	check(focus != null and not focus.draw_center and focus.border_width_left >= 2, "Focus overlays a visible outline without hiding state")
	check(cheap.get_theme_color("font_disabled_color") != cheap.get_theme_color("font_color"), "Disabled text is distinct")
	check(cheap.get_theme_stylebox("focus") == hub.back_button.get_theme_stylebox("focus"), "Buttons share one focus resource")
	var original := theme.get_color("font_color", "GoldLabel")
	var probe := Color(0.7, 0.8, 0.9)
	theme.set_color("font_color", "GoldLabel", probe)
	check(hub.echo_label.get_theme_color("font_color") == probe and hub.feedback.get_theme_color("font_color") == probe, "One theme edit reaches the header's echo and the notes in gold")
	theme.set_color("font_color", "GoldLabel", original)
	main.free()
	var frame := theme.get_stylebox("panel", "MainPanel") as StyleBoxTexture
	check(frame != null and frame.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT and frame.axis_stretch_vertical == StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT, "Panel grain tiles at one scale instead of stretching")
	var raised := theme.get_stylebox("card", "ItemCardList") as StyleBoxTexture
	var sunk := theme.get_stylebox("panel", "InsetPanel") as StyleBoxTexture
	check(raised != null and sunk != null and raised != sunk, "Cards are raised and detail wells are sunk")
	if raised != null and sunk != null:
		check(centre_tone(sunk.texture) < centre_tone(raised.texture), "Sunk wells sit darker than raised cards")
	check(theme.get_stylebox("pressed", "Button") is StyleBoxFlat and theme.get_stylebox("normal", "TabActive") is StyleBoxFlat, "Pressed buttons and the active tab stay flat against raised surfaces")
	check_steady_buttons(theme)
	check_readable_floor(theme)
	# Scroll bars are drawn in the hall's bronze, not the engine's grey bar.
	for bar in [&"VScrollBar", &"HScrollBar"]:
		for part in [&"scroll", &"grabber", &"grabber_highlight", &"grabber_pressed"]:
			check(theme.get_stylebox(part, bar) is ScrollRailStyle, "%s %s is a bronze rail" % [bar, part])
	# A secondary action that can be pressed must never look like one that
	# cannot.
	for state in [&"normal", &"hover", &"focus", &"pressed", &"hover_pressed", &"disabled"]:
		check(theme.has_stylebox(state, &"SecondaryButton"), "SecondaryButton has its own %s look" % state)
	# Frames only where needed: a secondary action is its words, a faint band
	# when pointed at and a gold bar when focused; the primary action keeps its
	# plate, and an answer that cannot be undone a thin red frame.
	var rest := theme.get_stylebox(&"normal", &"SecondaryButton") as StyleBoxFlat
	var marked := theme.get_stylebox(&"focus", &"SecondaryButton") as StyleBoxFlat
	check(rest != null and rest.border_width_left + rest.border_width_top + rest.border_width_right + rest.border_width_bottom == 0 and rest.bg_color.a == 0.0, "A secondary action has no frame at rest")
	check(marked != null and marked.border_width_left > 0 and marked.border_width_top == 0, "A focused secondary action is marked by a bar, not a box")
	check(theme.get_color(&"font_color", &"SecondaryButton") != theme.get_color(&"font_disabled_color", &"SecondaryButton"), "A secondary action looks different when it cannot be pressed")
	var primary := theme.get_stylebox(&"normal", &"PrimaryButton") as StyleBoxFlat
	check(primary != null and primary.border_width_top == 1 and primary.bg_color.a > 0.0, "The primary action is a quiet gold-tinted plate with a hairline")
	check((theme.get_stylebox(&"focus", &"PrimaryButton") as StyleBoxFlat).border_width_top > primary.border_width_top, "A focused primary action draws a stronger edge")
	check(theme.get_stylebox(&"normal", &"LobbyAction") is StyleBoxTexture, "The lobby keeps its painted plate")
	check((theme.get_stylebox(&"normal", &"DangerButton") as StyleBoxFlat).border_width_top > 0, "An answer that cannot be undone keeps a frame")
	check(theme.get_stylebox(&"panel", &"QuietWindow") is QuietWindowStyle, "Popup windows are the quiet surface")
	# The hub pages' main panel is the same quiet surface, its two columns one
	# panel; every item card shares one face.
	check(theme.get_stylebox(&"panel", &"SlabSolid") is QuietWindowStyle and theme.get_stylebox(&"panel", &"SlabSolidEnd") is QuietWindowStyle, "A page's main panel is the quiet surface")
	check(not ((theme.get_stylebox(&"panel", &"SlabSolidEnd") as QuietWindowStyle).sides & QuietWindowStyle.SIDE_LEFT), "A page's two columns share one hairline between them")
	var card_rest := theme.get_stylebox(&"normal", &"CardButton") as StyleBoxFlat
	var card_chosen := theme.get_stylebox(&"pressed", &"CardButton") as StyleBoxFlat
	check(card_rest.border_width_top == 0 and card_rest.bg_color.a > 0.0 and theme.get_stylebox(&"panel", &"CardSurface") == card_rest, "An item card is a faint face without a frame at rest, the same for buttons and panels")
	check(card_chosen.border_width_top > 0 and (theme.get_stylebox(&"focus", &"CardButton") as StyleBoxFlat).border_width_top > 0, "A chosen or focused card gets its frame")
	var fresh := theme.get_stylebox(&"new", &"AbilityCard") as StyleBoxFlat
	var ranked := theme.get_stylebox(&"raise", &"AbilityCard") as StyleBoxFlat
	check(fresh.bg_color == card_rest.bg_color and fresh.border_width_top > 0 and fresh.border_width_left == 0 and fresh.border_color != ranked.border_color, "Level-up cards share the card face, a coloured band telling new from raised")
	check(theme.get_color(&"font_color", &"SecondaryButton").get_luminance() - theme.get_color(&"font_disabled_color", &"SecondaryButton").get_luminance() > 0.3, "Its words dim when it cannot be pressed")
	# The fight's dialogs (level-up, the route, prompts, menu, result) stand on
	# warm stone in the bronze frame.
	var dialog := theme.get_stylebox(&"panel", &"MainPanel") as StyleBoxTexture
	check(dialog != null and dialog.texture.resource_path.ends_with("dialog_plate.png"), "Dialogs stand on the stone plate")
	var middle := dialog.texture.get_image().get_pixel(dialog.texture.get_width() / 2, dialog.texture.get_height() / 2)
	check(middle.r > middle.b + 0.02 and middle.a > 0.9, "The plate's stone is warm and nearly opaque")
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


func centre_tone(texture: Texture2D) -> float:
	var image := texture.get_image()
	return image.get_pixel(image.get_width() / 2, image.get_height() / 2).v
