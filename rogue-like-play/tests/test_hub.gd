extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


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
	var hero: AnimatedSprite2D = hub.home_page.get_node("Hero")
	check(hero.is_playing() and hero.animation == &"idle_front", "Home hero starts idle animation")
	check(hero.sprite_frames.get_frame_count(&"idle_front") == 8, "Home uses all eight high-resolution idle frames")
	var last_frame := hero.sprite_frames.get_frame_texture(&"idle_front", 7) as AtlasTexture
	check(last_frame.region == Rect2(0, 0, 128, 128), "Idle keeps the same body silhouette through the loop")
	var eyes: AnimatedSprite2D = hero.get_node("Eyes")
	hero.frame = 5
	check(eyes.frame == 5, "Blink stays synchronized with idle timing")
	var blink := eyes.sprite_frames.get_frame_texture(&"idle_front", 5) as AtlasTexture
	check(blink.region == Rect2(183, 159, 19, 8), "Blink affects only the eye region")
	check(not hub.hero_speech.visible, "Home speech starts hidden")
	hub.hero_button.pressed.emit()
	check(hub.hero_speech.visible, "Clicking hero opens speech")
	check(hub.hero_speech.position.y + hub.hero_speech.size.y + 14 < hero.position.y + hero.offset.y * hero.scale.y, "Speech and tail stay above hero")
	hub.hero_button.pressed.emit()
	check(not hub.hero_speech.visible, "Clicking hero again closes speech")
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
	check(hub.warehouse_panel.visible and hub.warehouse_panel.get_node("Panel/InventoryList").item_count == 2, "Warehouse opens with carried inventory")
	hub.warehouse_panel.get_node("Panel/InventoryList").item_selected.emit(1)
	hub.warehouse_panel.get_node("Panel/Deposit").pressed.emit()
	check(main.state.storage.entries.size() == 1 and main.state.inventory.entries.size() == 1, "Hub UI deposits one equipment item")
	hub.warehouse_panel.get_node("Panel/StorageList").item_selected.emit(0)
	hub.warehouse_panel.get_node("Panel/Withdraw").pressed.emit()
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
	check(main.active_run == run and main.get_child_count() == 2, "Repeated start cannot create duplicate run")
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
	print("Hub tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
