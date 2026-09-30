extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func run_tests() -> void:
	var catalog: Array[ItemData] = []
	for path in DirAccess.get_files_at("res://data/items"):
		if path.ends_with(".tres"):
			catalog.append(load("res://data/items/" + path))
	for weapon_path in ["sword", "spear", "hammer", "axe", "staff"]:
		catalog.append(ItemData.from_weapon(load("res://data/weapons/%s.tres" % weapon_path)))
	var missing: Array[String] = []
	for item in catalog:
		var texture := ItemIcons.icon(item)
		if texture == null:
			missing.append(String(item.id))
		elif texture.get_size() != Vector2(96, 96):
			missing.append("%s (size %s)" % [item.id, texture.get_size()])
	check(missing.is_empty(), "Every item and weapon has a 48px icon stored at 2x: missing %s" % [missing])

	var unknown := ItemData.new()
	unknown.id = &"not_generated_yet"
	check(ItemIcons.icon(unknown) == null, "Items without art keep the drawn symbol")
	check(ItemIcons.icon(null) == null, "An empty slot has no icon")
	var socketed := ItemData.from_weapon(load("res://data/weapons/staff.tres"))
	socketed.socketed_scroll = load("res://data/items/bolt_scroll.tres")
	check(ItemIcons.icon(socketed) == ItemIcons.icon(ItemData.from_weapon(load("res://data/weapons/staff.tres"))), "A staff with a scroll keeps the staff icon")

	check(ItemIcons.tint(Color("D6B77B")) == Color.WHITE, "Gold roles show the icon as painted")
	check(ItemIcons.tint(Color("EEE9DF")) == Color.WHITE, "Body text roles show the icon as painted")
	check(ItemIcons.tint(Color("8A8B84")).r < 0.7, "Muted roles dim the icon")
	check(is_equal_approx(ItemIcons.tint(Color(0.84, 0.72, 0.48, 0.4)).a, 0.4), "Alpha carries through to the icon")

	# The shared painter draws the icon inside the requested rectangle; only
	# a rendering run can read pixels back.
	if DisplayServer.get_name() != "headless":
		await check_painted_rectangle()
	var expected_kinds := [ItemData.Kind.WEAPON, ItemData.Kind.WEAPON, ItemData.Kind.ARMOR, ItemData.Kind.ACCESSORY, ItemData.Kind.ACCESSORY]
	for slot in expected_kinds.size():
		var symbol := ItemGlyph.slot_symbol(slot)
		check(symbol.kind == expected_kinds[slot] and ItemIcons.icon(symbol) == null, "Empty slot %d shows its drawn category symbol, never an item's art" % slot)
	test_emblems()
	print("Item icons: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_painted_rectangle() -> void:
	var marker := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	marker.fill(Color(1, 0, 0))
	var potion: ItemData = load("res://data/items/healing_potion.tres")
	ItemIcons.set_override(potion.id, ImageTexture.create_from_image(marker))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Control.new()
	canvas.size = Vector2(64, 64)
	canvas.draw.connect(func(): ItemGlyph.paint(canvas, Rect2(8, 8, 48, 48), potion, Color("D6B77B")))
	viewport.add_child(canvas)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot := viewport.get_texture().get_image()
	check(shot.get_pixel(32, 32).r > 0.9 and shot.get_pixel(2, 2).a < 0.1, "The icon fills its rectangle and nothing else")
	ItemIcons.set_override(potion.id, null)
	check(ItemIcons.icon(potion) != null and ItemIcons.icon(potion).get_size() == Vector2(96, 96), "Clearing an override restores the generated icon")
	viewport.queue_free()
	await process_frame


func test_emblems() -> void:
	for effect: int in AbilityData.Effect.values():
		var key := EmblemIcons.ability_key(effect)
		check(EmblemIcons.texture(key) != null, "Ability %s has its emblem" % key)
		var emblem := EmblemIcons.texture(key)
		if emblem != null:
			check(emblem.get_size() == Vector2(96, 96), "Emblem %s is a 48px emblem stored at 2x" % key)
	check(EmblemIcons.upgrade_key(&"hp", false) == "max_hp", "Base HP shares the Max HP ability emblem")
	check(EmblemIcons.upgrade_key(&"hp", true) == "vitality", "The vitality branch has its own emblem")
	check(EmblemIcons.upgrade_key(&"mp", true) == "mana" and EmblemIcons.texture("mana") != null, "Mana has its own emblem")
	check(EmblemIcons.upgrade_key(&"attack", true) == "attack" and EmblemIcons.upgrade_key(&"defense", true) == "defense", "Attack and defense upgrades share the ability emblems")
	check(EmblemIcons.texture("") == null and EmblemIcons.texture("no_such_emblem") == null, "Unknown keys keep the drawn symbol")
	var card := AbilityCard.new()
	check(card.symbol.custom_minimum_size == Vector2(96, 96) and card.symbol.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Ability cards show emblems at their stored size without blur")
	card.free()
