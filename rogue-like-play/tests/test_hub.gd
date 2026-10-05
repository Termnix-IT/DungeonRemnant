extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func ignores_pointer(node: Node) -> bool:
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not ignores_pointer(child):
			return false
	return true


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func run_tests() -> void:
	var state := RunCarryover.new()
	check(not state.purchase_upgrade() and state.gold == 0 and state.hp_upgrade_level == 0, "Insufficient funds do not mutate state")
	state.gold = 29
	check(not state.purchase_upgrade() and state.gold == 29, "Price boundary below cost")
	state.gold = 180
	for expected in range(1, 4):
		check(state.purchase_upgrade() and state.hp_upgrade_level == expected, "Purchase advances one level")
	check(state.gold == 0 and state.upgrade.hp_bonus(3) == 3, "All three prices total 180 for HP +3")
	state.gold = 999
	for attempt in 10:
		check(not state.purchase_upgrade() and state.gold == 999 and state.hp_upgrade_level == 3, "Repeated purchase cannot exceed cap or spend Gold")
	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	var hub: CanvasLayer = main.get_node("Hub")
	var lobby: HubLobby = hub.home_page
	var hero: LobbyHero = lobby.get_node("Hero")
	var viewport := root.get_visible_rect().size
	# The texture keeps a clear margin above her for swaying hair.
	var figure := hero.size.y * (1.0 - 40.0 / hero.texture.get_height())
	check(figure >= viewport.y * 0.74 and figure <= viewport.y * 0.82, "Lobby heroine stands about 78% of the screen tall")
	check(hero.get_global_rect().end.x <= viewport.x + 1, "Heroine and her swaying hair stay on screen")
	# Idle: breathing, lean, three-step blinks every 3-7 s, glances of 1-2°
	# with the eyes, and the back hair swinging on its spring.
	hero.rng.seed = 7
	var blinks := 0
	var was_closed := false
	var half_seen := false
	var glanced_eyes := false
	var widest_angle := 0.0
	var widest_hair := 0.0
	var gestures := 0
	var was_posing := false
	for step in 2400:
		hero.advance(0.025)
		var posing := hero.pose_mix > 0.0
		if posing and not was_posing:
			gestures += 1
		was_posing = posing
		var closed := hero.eye_frame == LobbyHero.Eyes.CLOSED
		if closed and not was_closed:
			blinks += 1
		was_closed = closed
		half_seen = half_seen or hero.eye_frame == LobbyHero.Eyes.HALF
		glanced_eyes = glanced_eyes or hero.eye_frame in [LobbyHero.Eyes.LEFT, LobbyHero.Eyes.RIGHT]
		widest_angle = maxf(widest_angle, absf(rad_to_deg(hero.head_angle)))
		widest_hair = maxf(widest_hair, absf(hero.hair_angle))
	check(blinks >= 8 and blinks <= 21, "She blinks every 3-7 s over 60 s: %d" % blinks)
	check(gestures >= 2 and gestures <= 5, "A Random Idle gesture comes every 12-25 s: %d in 60 s" % gestures)
	check(half_seen, "Blinks pass through half-closed eyes")
	check(glanced_eyes, "Glances move her eyes to one side")
	check(widest_angle > 0.5 and widest_angle <= 2.01, "Glances turn her head by up to 2°: %.2f" % widest_angle)
	check(widest_hair > 0.003 and widest_hair <= LobbyHero.HAIR_LIMIT, "Back hair swings within its limit: %.4f" % widest_hair)
	var material := hero.material as ShaderMaterial
	for texture_name in [&"hair_texture", &"eye_atlas", &"motion_mask"]:
		check(material.get_shader_parameter(texture_name) != null, "Idle shader has its %s" % texture_name)
	check(material.get_shader_parameter(&"eye_frame") == float(hero.eye_frame), "The shader shows the current eyes")
	# The hair follows the body late: right after the hop starts it has barely
	# moved, and a moment later it hangs below the rising body.
	hero.react()
	hero.advance(0.016)
	check(hero.scale.y > 1.0, "A click lifts her in a small hop")
	var early := absf(hero.hair_offset.y)
	hero.advance(0.15)
	check(absf(hero.hair_offset.y) > early * 3.0, "Hair trails the hop a moment late")
	# Quick taps: a tap mid-hop neither restarts the hop nor flips her head,
	# and right after a hop she rests before the next one.
	var mid_scale := hero.scale.y
	var head_side := signf(hero._glance_target)
	hero.react()
	hero.advance(0.016)
	check(hero.scale.y > mid_scale - 0.004 and signf(hero._glance_target) == head_side, "A tap mid-hop keeps the hop and the head's side")
	hero.advance(LobbyHero.REACT_TIME)
	hero.react()
	hero.advance(0.016)
	check(is_equal_approx(hero.scale.y, 1.0), "Right after a hop she rests before hopping again")
	hero.advance(LobbyHero.REACT_REST)
	hero.react()
	hero.advance(0.05)
	check(hero.scale.y > 1.0, "After resting she hops again")
	var steady := true
	for tap in 40:
		hero.react()
		hero.advance(0.05)
		steady = steady and absf(hero.hair_angle) < LobbyHero.HAIR_LIMIT and is_finite(hero.hair_angle) and is_finite(hero.hair_offset.y)
	check(steady, "Forty quick taps keep the hair within its limit")
	# A click brings a smile that fades again.
	hero.advance(2.0)
	hero.react()
	hero.advance(0.05)
	check(hero.face_mix > 0.0, "A click starts a smile")
	hero.advance(LobbyHero.SMILE_IN + LobbyHero.SMILE_HOLD * 0.5)
	check(is_equal_approx(hero.face_mix, 1.0), "The smile holds")
	hero.advance(LobbyHero.SMILE_HOLD + LobbyHero.SMILE_OUT)
	check(hero.face_mix == 0.0, "The smile fades back")
	# A gesture fades in, holds, fades out, and holds the back hair still.
	for name: StringName in LobbyHero.POSES:
		var frames: Array = LobbyHero.POSES[name][1]
		hero.gesture(name)
		# On the way the arm passes through each in-between frame in turn.
		var seen: Array = []
		for step in 36:
			hero.advance(LobbyHero.POSE_FADE_IN / 36.0)
			var shown = material.get_shader_parameter(&"pose_to") if material.get_shader_parameter(&"pose_to_mix") > 0.0 else material.get_shader_parameter(&"pose_from")
			if not seen.has(shown):
				seen.append(shown)
		check(seen == frames, "Gesture %s passes through its in-betweens in order" % name)
		hero.advance(0.05)
		var rect: Rect2 = LobbyHero.POSES[name][0]
		check(hero.pose == name and is_equal_approx(hero.pose_mix, 1.0) and material.get_shader_parameter(&"pose_rect") == Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y), "Gesture %s shows its patch" % name)
		check(is_zero_approx(material.get_shader_parameter(&"hair_angle")), "The back hair holds still under gesture %s" % name)
		hero.advance(LobbyHero.POSE_HOLD.y + LobbyHero.POSE_FADE_OUT + 0.05)
		check(hero.pose_mix == 0.0, "Gesture %s returns to the idle" % name)
	hero.advance(LobbyHero.REACT_TIME)
	check(is_equal_approx(hero.scale.y, 1.0) and is_equal_approx(hero.scale.x, 1.0), "The hop settles back to rest")
	check(hero.get_rect().get_center().x > viewport.x * 0.66, "Heroine stands on the right side of the lobby")
	check(lobby.buttons.map(func(button: Button): return button.text) == ["出撃", "装備", "倉庫", "ショップ", "強化", "設定"], "Lobby menu lists the six entries in order")
	check(lobby.selected_id() == &"departure" and hub.start_button.has_focus(), "Lobby starts on departure with focus")
	for button in lobby.buttons:
		check(button.get_global_rect().end.x <= viewport.x * 0.22, "Menu entry stays within about a fifth of the width: " + button.text)
	check(not hub.title_label.is_visible_in_tree() and hub.gold_label.is_visible_in_tree() and hub.find_children("SettingsButton", "", true, false).is_empty(), "Lobby top shows only Gold; settings live in the menu")
	for label in hub.find_children("*", "Label", true, false):
		check(not (label.is_visible_in_tree() and label.text.contains("Lv")), "Lobby shows no level: " + label.text)
	var ambience: HubAmbience = hub.get_children().filter(func(child: Node): return child is HubAmbience)[0]
	check(ambience.get_index() < hub.get_node("Content").get_index() and ambience.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Ambience sits beneath the panels and ignores the pointer")
	ambience.size = Vector2(1600, 900)
	check(ambience.light_rect(Vector2(0.5, 0.5), 10.0).get_center().is_equal_approx(Vector2(800, 450)), "Lights follow the covered background")
	hub.hide()
	check(not ambience.dust.emitting, "Hidden hub stops the dust")
	hub.show()
	# Choosing and entering are separate: one press chooses, the next enters.
	await create_timer(HubAmbience.FOCUS_TIME + 0.1).timeout
	check(ambience.focus_id == &"departure" and ambience.focus_strength > 0.9, "Departure lights the gate")
	hub.equipment_button.pressed.emit()
	check(hub.page == "home" and lobby.selected_id() == &"equipment" and hub.decide_button.text == "装備を整える", "First press chooses equipment without leaving")
	await create_timer(HubAmbience.FOCUS_TIME + 0.1).timeout
	check(ambience.focus_id == &"equipment", "Choosing equipment lights the weapon rack")
	check(lobby.equipment_label.is_visible_in_tree() and not lobby.carried_label.is_visible_in_tree(), "Panel shows only the chosen entry's information")
	# Every entry shows the same panel: one rect, the button in one place.
	var panel_rects := {}
	var button_rects := {}
	for index in lobby.buttons.size():
		lobby.select(index)
		await process_frame
		panel_rects[lobby.panel.get_global_rect()] = true
		button_rects[lobby.decide_button.get_global_rect()] = true
	check(panel_rects.size() == 1 and button_rects.size() == 1, "Every lobby entry keeps the same panel size and button place")
	check(lobby.decide_button.size.y >= 60.0, "The decide button stands 60px tall")
	check(lobby.panel.get_global_rect().end.y <= viewport.y - 60.0 and lobby.panel.get_global_rect().position.y >= viewport.y * 0.62, "The panel sits low, clear of the altar and the stairs")
	for index in lobby.buttons.size():
		lobby.select(index)
		check(lobby._art.texture != null, "Entry %s shows its illustration" % lobby.selected_id())
		check(lobby.title_icon.kind == HubLobby.ENTRIES[index][2], "Entry %s shows its menu mark" % lobby.selected_id())
	check(lobby.carried_room.text == "%d 枠" % (main.state.inventory.max_entries - main.state.inventory.entries.size()), "Shop shows the free carry slots")
	check(lobby.worn_value.text.ends_with("/ 5") and lobby.upgrade_ready.text.ends_with("件"), "Equipment and upgrade show their second facts")
	# Facts lie on a band, not in a sunken box; Gold reads as a coin and an amount.
	check(lobby.find_children("*", "PanelContainer", true, false).all(func(box: PanelContainer): return box == lobby.panel), "The lobby panel holds no boxed fields")
	check(lobby.equipment_label.custom_minimum_size.x > 0.0, "The main weapon's name keeps its width")
	# No hover popup repeats what is already on screen.
	check(lobby.buttons.all(func(button: Button): return button.tooltip_text.is_empty()) and lobby.decide_button.tooltip_text.is_empty(), "Menu entries and the decide button have no tooltip")
	check(lobby.equipment_label.tooltip_text.is_empty() and lobby.description_label.tooltip_text.is_empty(), "Whole texts need no tooltip")
	# The hints that remain are drawn in the speech bubble's ink, not the boxed tooltip.
	for hinted: Control in [hub.hero_button, hub.gold_label]:
		var tip: Control = hinted._make_custom_tooltip(hinted.tooltip_text)
		check(tip != null and tip.theme_type_variation == &"InkTooltip" and (tip.get_child(0) as Label).text == hinted.tooltip_text, "%s hints in ink" % hinted.name)
		tip.free()
	# Shared screen parts (docs/MVP_SPEC.md, 個別画面のUI文法).
	check(hub.find_children("*", "Label", true, false).all(func(label: Label): return label.text != "Dungeon Remnant"), "No screen carries the game's logo")
	hub.show_page("equipment")
	check(hub.key_guide.visible and hub.back_button.get_parent() == hub.key_guide and hub.key_guide.cap_text(hub.back_button) == "Esc", "Pages show the key guide with Esc to go back")
	check(hub.purse.quiet and hub.gold_label.theme_type_variation == &"PurseValueQuiet", "Gold is quiet where nothing costs")
	var pad_press := InputEventJoypadButton.new()
	pad_press.button_index = JOY_BUTTON_DPAD_DOWN
	pad_press.pressed = true
	hub.key_guide._input(pad_press)
	check(hub.key_guide.cap_text(hub.back_button) == "B", "A gamepad turns the cap to its button")
	var key_press := InputEventKey.new()
	key_press.keycode = KEY_DOWN
	key_press.pressed = true
	hub.key_guide._input(key_press)
	check(hub.key_guide.cap_text(hub.back_button) == "Esc", "Keys turn it back")
	hub.back_button.pressed.emit()
	check(hub.page == "home" and not hub.key_guide.visible and not hub.purse.quiet, "The guide's back returns to the lobby, where Gold is full")
	hub.show_page("sell")
	check(not hub.purse.quiet, "Gold is full in the shop")
	# The shop: no framed panels, one stat display, buying and selling at the title's place.
	var shop: HubSell = hub.sell_page
	check(shop.mode_tabs.visible and not hub.title_label.visible, "The shop switches buying and selling at the title's place")
	check(shop.find_children("*", "PanelContainer", true, false).all(func(box: PanelContainer): return box.theme_type_variation in [&"SlabSolid", &"SlabColumn", &"ShopHeroBand"]), "The shop has no framed panels")
	shop.set_buying(true)
	shop.category_tabs.select(2, true)
	check(shop.rows.all(func(row: Dictionary): return row.item.kind == ItemData.Kind.ARMOR), "The armor tab lists only armor")
	shop.item_list.select(0)
	shop.item_list.item_selected.emit(0)
	var raised: Array = shop.hero_specs.rows.filter(func(row: Array): return row[2] > row[1])
	check(not raised.is_empty() and shop.swap_label.text.begins_with("防具と入れ替え"), "New armor shows her defense rising")
	check(not shop.showcase.effect.visible, "The name is not followed by its effect again")
	var r_key := InputEventKey.new()
	r_key.keycode = KEY_R
	r_key.pressed = true
	shop._unhandled_input(r_key)
	check(not shop.buying, "R switches to selling")
	var e_key := InputEventKey.new()
	e_key.keycode = KEY_E
	e_key.pressed = true
	shop._unhandled_input(e_key)
	check(shop.category_tabs.selected == 3, "E steps to the next category")
	shop.category_tabs.select(0, true)
	hub.show_page("home")
	check(lobby.decide_button.theme_type_variation == &"PrimaryAction" and lobby.decide_button.size.y >= HubUI.PRIMARY_ACTION_HEIGHT, "The lobby's decide button is the shared primary action")
	var focus_style := lobby.decide_button.get_theme_stylebox(&"focus") as StyleBoxFlat
	var selected_gold := Color(0.8392157, 0.7176471, 0.48235294)
	check(not focus_style.border_color.is_equal_approx(Color(selected_gold, focus_style.border_color.a)), "Focus is not drawn in the selection's gold")
	var empty := ItemCardList.new()
	empty.empty_text = "持ち込める品はまだない"
	check(empty.item_count == 0 and empty.empty_text != "", "Lists can say why they are empty")
	empty.free()
	check(UIFormat.gold(20) == "20 G" and UIFormat.gold(12500) == "12,500 G", "Prices put the unit after grouped digits")
	check(UIFormat.amount(0) == "0" and UIFormat.amount(1280) == "1,280" and UIFormat.amount(1234567) == "1,234,567" and UIFormat.amount(999) == "999", "Gold amounts group thousands")
	var purse_row: HBoxContainer = hub.gold_label.get_parent()
	check(purse_row.get_children().filter(func(node: Node): return node is Label).size() == 1, "Gold shows no word beside the amount")
	lobby.select(1)
	hub.equipment_button.pressed.emit()
	check(hub.page == "equipment", "Pressing the chosen entry enters it")
	await create_timer(HubAmbience.FOCUS_TIME + 0.1).timeout
	check(ambience.focus_id == &"", "Pages away from the lobby clear the hall light")
	hub.show_page("home")
	check(lobby.selected_id() == &"equipment" and hub.equipment_button.has_focus(), "Returning home keeps the chosen entry")
	hub.decide_button.pressed.emit()
	check(hub.page == "equipment", "Panel button enters the chosen entry")
	hub.show_page("home")
	# Keyboard and gamepad focus chooses directly.
	hub.warehouse_button.grab_focus()
	check(lobby.selected_id() == &"storage" and lobby.stored_label.is_visible_in_tree(), "Focus chooses an entry")
	# Settings open as their own page, entered like the others.
	var settings_entry: Button = lobby.buttons[-1]
	settings_entry.pressed.emit()
	check(lobby.selected_id() == &"settings" and hub.decide_button.visible and hub.decide_button.text == "設定を開く" and lobby.volume_value.text == "100%" and lobby.display_value.text == "ウィンドウ", "Settings entry shows current values and an open button")
	settings_entry.pressed.emit()
	var page: HubSettings = hub.settings_page
	check(hub.page == "settings" and page.visible and not lobby.visible and page.volume_slider.has_focus(), "Settings slide in as a page with the volume bar focused")
	var master := AudioServer.get_bus_index(&"Master")
	page.volume_slider.value = 50
	check(is_equal_approx(hub.settings.volume, 0.5) and is_equal_approx(AudioServer.get_bus_volume_linear(master), 0.5) and page.volume_value.text == "50%", "Volume bar sets the master volume")
	var step_right := InputEventAction.new()
	step_right.action = &"ui_right"
	step_right.pressed = true
	root.push_input(step_right)
	check(page.volume_slider.value == 55 and hub.settings.volume_percent() == 55, "Right on the focused bar raises the volume one step")
	page.volume_slider.value = 0
	check(AudioServer.is_bus_mute(master), "Silent mutes the master bus")
	page.volume_slider.value = 100
	check(not AudioServer.is_bus_mute(master) and is_equal_approx(AudioServer.get_bus_volume_linear(master), 1.0), "Loudest restores full volume")
	page.display_cycler.grab_focus()
	root.push_input(step_right)
	check(hub.settings.fullscreen and page.display_cycler.text == "全画面" and page.display_cycler.has_focus(), "Right on the selector steps to fullscreen and keeps focus")
	page.display_cycler.pressed.emit()
	check(not hub.settings.fullscreen and page.display_cycler.text == "ウィンドウ", "Confirming the selector wraps back to window")
	page.volume_slider.value = 80
	hub.go_back()
	check(hub.page == "home" and lobby.selected_id() == &"settings" and lobby.volume_value.text == "80%", "Back returns to the lobby with the new values")
	page.volume_slider.value = 100
	hub.start_button.grab_focus()
	check(not hub.hero_speech.visible, "Home speech starts hidden")
	hub.hero_button.pressed.emit()
	check(hub.hero_speech.visible, "Clicking hero opens speech")
	var speech_rect: Rect2 = hub.hero_speech.get_global_rect()
	check(root.get_visible_rect().encloses(speech_rect) and not speech_rect.intersects(lobby.panel.get_global_rect()) and speech_rect.end.x <= hero.get_global_rect().position.x + hero.size.x * HubLobby.FACE.x, "Speech sits beside her face, on screen and clear of the panel")
	var backing := hub.hero_speech.get_theme_stylebox(&"panel") as StyleBoxTexture
	check(backing != null and backing.texture != null and hub.hero_speech.find_children("*", "Polygon2D", true, false).is_empty(), "The speech backing is the ink-wash strip, with no drawn triangle tail")
	var line_width: float = lobby.speech_label.get_theme_font(&"font").get_string_size(lobby.speech_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lobby.speech_label.get_theme_font_size(&"font_size")).x
	check(lobby.speech_label.size.x >= line_width + HubLobby.SPEECH_GAP * 2.0 - 1.0, "The line keeps its gap from the end studs")
	var first_line: String = lobby.speech_label.text
	hub.hero_button.pressed.emit()
	check(hub.hero_speech.visible and lobby.speech_label.text != first_line, "Clicking again moves to her next line")
	await create_timer(HubLobby.SPEECH_TIME + 0.2).timeout
	check(not hub.hero_speech.visible, "Speech fades by itself after a while")
	hub.hero_button.pressed.emit()
	hub.show_page("stages")
	hub.show_page("home")
	check(not hub.hero_speech.visible, "Returning home resets speech")
	hub.hero_button.pressed.emit()
	hub.open_warehouse()
	check(not hub.hero_speech.visible, "Warehouse closes speech")
	hub.warehouse_panel.close()
	check(hub.visible and main.active_run == null and hub.purchase_button.disabled, "Game starts in Hub with no active dungeon")
	check(hub.get_child(hub.get_child_count() - 1) == hub.warehouse_panel, "Warehouse modal is last in GUI input order")
	check(hub.gold_label.text.contains("0") and hub.equipment_label.text.contains("剣"), "Hub displays initial Gold and equipment")
	main.state.gold = 101
	main.state.inventory.add(ItemCatalog.POTION, 10)
	main.state.inventory.add(preload("res://data/items/leather_armor.tres"))
	main.state.equipment.slots[3] = preload("res://data/items/vital_charm.tres")
	hub.warehouse_panel.present(main.state)
	check(hub.warehouse_panel.visible and hub.warehouse_panel.get_node("%InventoryList").item_count == 2, "Warehouse opens with carried inventory")
	hub.warehouse_panel.get_node("%InventoryList").item_selected.emit(1)
	hub.warehouse_panel.get_node("%Deposit").pressed.emit()
	check(main.state.storage.entries.size() == 1 and main.state.inventory.entries.size() == 1, "Hub UI deposits one equipment item")
	hub.warehouse_panel.get_node("%StorageList").item_selected.emit(0)
	hub.warehouse_panel.get_node("%Withdraw").pressed.emit()
	check(main.state.storage.entries.is_empty() and main.state.inventory.entries.size() == 2, "Hub UI withdraws deposited item")
	main.state.inventory.remove(1)
	main.state.storage.add(ItemCatalog.POTION, 12)
	hub.warehouse_panel.close()
	check(main.purchase_upgrade() and main.state.gold == 71 and main.state.hp_upgrade_level == 1, "Hub purchase updates shared state")
	main.start_run()
	var run: Node2D = main.active_run
	var player: Node2D = run.turns.player
	check(not hub.visible and run.turns.gold == 71 and run.progression.level == 1, "Start initializes new run with remaining Gold")
	check(player.stats.max_hp == 29 and player.hp == 29, "Base HP plus permanent upgrade plus equipment")
	main.start_run()
	var runs := main.get_children().filter(func(child: Node): return child.has_method("finish_run"))
	check(main.active_run == run and runs.size() == 1, "Repeated start cannot create duplicate run")
	check(main.transition.visible and not main.transition.title.text.is_empty() and run.turns.player.input_enabled, "Departure covers the cut while the run is already live")
	var cell_before: Vector2i = player.cell
	var step := InputEventAction.new()
	step.pressed = true
	for candidate: Array in [["move_e", Vector2i.RIGHT], ["move_w", Vector2i.LEFT], ["move_s", Vector2i.DOWN], ["move_n", Vector2i.UP]]:
		if run.dungeon.grid.can_step(cell_before, cell_before + candidate[1]):
			step.action = candidate[0]
			break
	check(not step.action.is_empty(), "Start cell has a walkable neighbour for the input check")
	root.push_input(step)
	check(player.cell == cell_before and run.turns.turn_count == 0, "Input is swallowed while the cover is up")
	check(main.transition.root.mouse_filter == Control.MOUSE_FILTER_STOP, "Cover blocks pointer input while covering")
	await create_timer(SceneTransition.HOLD_TIME + SceneTransition.REVEAL_TIME + 0.1).timeout
	check(not main.transition.visible and not main.transition.covering and main.transition.root.modulate.a == 1.0, "Transition reveals itself and resets")
	check(ignores_pointer(main.transition.root), "Revealed transition releases pointer input")
	# Control case: the same input moves the player once the cover is gone.
	root.push_input(step)
	var release := InputEventAction.new()
	release.action = step.action
	root.push_input(release)
	check(player.cell != cell_before, "The swallowed input would have moved the player")
	if run.presentation.playing:
		await run.presentation.finished
	await process_frame
	check(not main.purchase_upgrade() and main.state.gold == 71, "Purchases blocked during adventure")
	main.return_to_hub()
	check(main.active_run == run, "Cannot return without finishing run")
	player.gain_ability(preload("res://data/abilities/max_hp.tres"))
	check(player.stats.max_hp == 32, "Ability stacks with permanent and equipped HP")
	player.apply_permanent_hp(1)
	check(player.stats.max_hp == 32, "Permanent bonus application is idempotent")
	run.floor_number = 2
	run._load_floor()
	check(player.stats.max_hp == 32, "Floor transition does not multiply HP bonus")
	run.finish_run(false)
	check(run.result_panel.accept.text.contains("拠点") and run.turns.gold == 36, "Result offers Hub return after one loss")
	run.retry_run()
	check(main.active_run == null and hub.visible and main.state.gold == 36, "Result returns to Hub with surviving Gold")
	check(main.transition.visible and main.transition.title.text == "旅支度の間" and not main.transition.art.visible, "Return to Hub is covered by its own heading")
	check(main.state.hp_upgrade_level == 1 and main.state.inventory.entries.is_empty() and main.state.equipment.slots[3] != null, "Death preserves upgrade and gear, halves inventory")
	check(main.state.storage.entries[0].count == 12, "Death leaves warehouse untouched")
	main.return_to_hub()
	check(main.state.gold == 36, "Duplicate Hub return cannot apply loss")
	for cycle in 3:
		main.start_run()
		run = main.active_run
		player = run.turns.player
		check(player.stats.max_hp == 29 and player.hp == 29 and player.abilities.levels.is_empty(), "Next adventure resets ability, retains permanent HP exactly once")
		check(run.progression.level == 1 and run.progression.exp == 0 and run.turns.earned_gold == 0, "New adventure counters reset")
		run.finish_run(true)
		run.retry_run()
		check(main.state.gold == 36 and main.state.inventory.entries.is_empty(), "Clear round trip preserves possessions")
	main.state.gold = 150
	check(main.purchase_upgrade() and main.state.gold == 90 and main.state.hp_upgrade_level == 2, "Next price is 60")
	check(main.purchase_upgrade() and main.state.gold == 0 and main.state.hp_upgrade_level == 3, "Final price is 90")
	check(hub.purchase_button.disabled and hub.purchase_button.text.contains("上限"), "UI displays cap")
	main.start_run()
	check(main.active_run.turns.player.stats.max_hp == 31, "Maximum upgrade applies +3 alongside gear")
	check(preload("res://data/player_stats.tres").max_hp == 24, "Shared base Resource remains unchanged")
	main.free()
	# Settings live apart from progress and fall back to defaults when unreadable.
	var stored := GameSettings.new()
	stored.path = "res://.godot/settings-test.cfg"
	stored.volume = 0.35
	stored.fullscreen = true
	check(stored.save_settings(), "Settings save to their own file")
	var loaded := GameSettings.new()
	loaded.path = stored.path
	loaded.load_settings()
	check(is_equal_approx(loaded.volume, 0.35) and loaded.fullscreen, "Settings survive a restart")
	var broken := FileAccess.open(stored.path, FileAccess.WRITE)
	broken.store_string("[audio\nvolume = ")
	broken.close()
	var fallback := GameSettings.new()
	fallback.path = stored.path
	fallback.load_settings()
	check(is_equal_approx(fallback.volume, 1.0) and not fallback.fullscreen, "Unreadable settings fall back to full volume in a window")
	# The first settings files stored five volume steps.
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "volume_step", 2)
	legacy.save(stored.path)
	var upgraded := GameSettings.new()
	upgraded.path = stored.path
	upgraded.load_settings()
	check(is_equal_approx(upgraded.volume, 0.5), "Old volume steps load as their level")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stored.path))
	print("Hub tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
