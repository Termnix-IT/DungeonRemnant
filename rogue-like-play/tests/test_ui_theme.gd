extends SceneTree

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
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	main.state.gold = 100
	root.add_child(main)
	var hub = main.get_node("Hub")
	var shop: HubSell = hub.sell_page
	hub.show_page("sell")
	shop.set_buying(true)
	for frame in 3:
		await process_frame
	check(shop.sell_button.disabled, "Transaction is disabled until selection")
	shop.item_list.select(0)
	shop.item_list.item_selected.emit(0)
	check(not shop.sell_button.disabled, "Valid purchase enables transaction")
	for control: Control in [shop.item_list, shop.details, shop.quantity, shop.total_label, shop.sell_button, shop.source_choice]:
		check(shop.get_global_rect().grow(1).encloses(control.get_global_rect()), "%s fits shop" % control.get_class())
	check(shop.source_label.size.y <= shop.source_choice.size.y, "Source caption stays on one row")
	check(not shop.total_label.get_global_rect().intersects(shop.sell_button.get_global_rect()), "Quote leaves action visible")
	inspect_styles(hub.get_node("Content"))
	var normal := shop.sell_button.get_theme_stylebox("normal")
	for state in ["hover", "pressed", "disabled", "focus"]:
		check(shop.sell_button.get_theme_stylebox(state) != normal, "Gold button has distinct " + state)
	var focus := shop.sell_button.get_theme_stylebox("focus") as StyleBoxFlat
	check(not focus.draw_center and focus.border_width_left >= 2, "Focus overlays a visible outline without hiding state")
	check(shop.sell_button.get_theme_color("font_disabled_color") != shop.sell_button.get_theme_color("font_color"), "Disabled text is distinct")
	check(shop.sell_button.get_theme_stylebox("normal") == hub.purchase_button.get_theme_stylebox("normal"), "Shop and upgrade share Gold style resource")
	check(shop.sell_button.get_theme_stylebox("focus") == hub.back_button.get_theme_stylebox("focus"), "Buttons share focus resource")
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
	var original := theme.get_color("font_color", "GoldLabel")
	var probe := Color(0.7, 0.8, 0.9)
	theme.set_color("font_color", "GoldLabel", probe)
	check(shop.total_label.get_theme_color("font_color") == probe and hub.gold_label.get_theme_color("font_color") == probe, "One theme edit reaches shop and the header's Gold")
	var money := Label.new()
	money.theme_type_variation = &"MoneyValueLabel"
	hub.add_child(money)
	check(money.get_theme_color("font_color") == probe, "Money values follow the one gold")
	money.free()
	check(hub.sell_page.showcase.effect.get_theme_color("font_color") != probe, "An item's effect is information, not gold")
	check(hub.upgrade_page.next_value.get_theme_color("font_color") != probe, "An upgrade's next value is information, not gold")
	theme.set_color("font_color", "GoldLabel", original)
	main.free()
	print("UI theme: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


# The hub's smallest text, key caps included: 16px at 1600x900 is about 19px
# at 1080p, above the 18px floor of Xbox Accessibility Guideline 101 for PC.
# The dungeon HUD (Hud*) keeps its own sizes for the floor it must not cover.
func check_readable_floor(theme: Theme) -> void:
	for pair: Array in [[&"font_size", &"NoteLabel"], [&"font_size", &"MutedLabel"], [&"font_size", &"LobbyFactCaption"], [&"cap_font_size", &"KeyGuideButton"], [&"font_size", &"KeyGuideButton"], [&"font_size", &"CategoryCap"], [&"note_font_size", &"StageNode"], [&"font_size", &"HintMark"], [&"font_size", &"SkillNode"], [&"rank_font_size", &"SkillNode"], [&"font_size", &"TextAction"], [&"font_size", &"SecondaryButton"]]:
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
