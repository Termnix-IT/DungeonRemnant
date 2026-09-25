class_name RunLoss
extends RefCounted


static func apply(inventory: Inventory, gold: int, rng: RandomNumberGenerator) -> Dictionary:
	var amount := ceili(inventory.entries.size() / 2.0)
	var units := 0
	var lost: Dictionary = {}
	# Presentation copy of the same loss, keeping item identity for glyphs.
	var entries: Array[Dictionary] = []
	# Equipment lives outside inventory; remove whole randomly selected slots.
	for draw in amount:
		var index := rng.randi_range(0, inventory.entries.size() - 1)
		var entry := inventory.entries[index]
		var label := entry.item.display_name
		lost[label] = int(lost.get(label, 0)) + entry.count
		entries.append({"item": entry.item, "count": entry.count})
		units += entry.count
		inventory.remove(index, entry.count)
	return {"gold_lost": gold / 2, "items_lost": lost, "item_count_lost": units, "slots_lost": amount, "lost_entries": entries}
