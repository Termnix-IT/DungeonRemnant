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
	var choice := SegmentedChoice.new()
	root.add_child(choice)
	var picks: Array[int] = []
	choice.item_selected.connect(func(index: int): picks.append(index))
	choice.add_item("1F", 1)
	choice.add_item("11F", 11)
	choice.add_item("21F", 21)
	check(choice.item_count == 3 and choice.selected == 0 and choice.option(0).button_pressed, "The first option starts chosen")
	check(choice.get_item_text(1) == "11F" and choice.get_item_id(2) == 21, "Options keep their text and id")
	for index in choice.item_count:
		check(choice.option(index).focus_mode != Control.FOCUS_NONE and choice.option(index).toggle_mode, "Option %d is a focusable toggle" % index)
	choice.select(2)
	check(choice.selected == 2 and choice.get_selected_id() == 21 and picks.is_empty(), "select() changes the choice without emitting, like OptionButton")
	check(choice.option(2).button_pressed and not choice.option(0).button_pressed, "Only the chosen option is down")
	choice.option(1).pressed.emit()
	check(choice.selected == 1 and picks == [1], "Pressing an option chooses it and emits once")
	choice.option(1).pressed.emit()
	check(picks == [1] and choice.option(1).button_pressed, "Pressing the chosen option again changes nothing")
	choice.focus_selected()
	await process_frame
	check(choice.option(1).has_focus(), "Focus lands on the chosen option")
	choice.clear()
	await process_frame
	check(choice.item_count == 0 and choice.selected == -1 and choice.get_child_count() == 0, "Clearing removes every option")
	choice.add_item("倉庫")
	check(choice.selected == 0 and choice.get_selected_id() == 0, "Options without an id use their index")
	choice.queue_free()

	var main := preload("res://game/main.tscn").instantiate()
	main.saving_enabled = false
	root.add_child(main)
	var hub = main.get_node("Hub")
	hub.show_page("sell")
	await process_frame
	var shop: HubSell = hub.sell_page
	check(shop.source_choice.option(0).has_focus(), "The shop opens with focus on the chosen place")
	shop.source_choice.option(1).pressed.emit()
	check(shop._source() == main.state.inventory, "Pressing 持ち込み switches the shop to carried items")
	main.free()
	await process_frame
	print("Segmented choice: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
