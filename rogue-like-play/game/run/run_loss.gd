class_name RunLoss
extends RefCounted


static func apply(inventory: Inventory, gold: int, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for entry in inventory.entries:
		total += entry.count
	var amount := total / 2
	var lost: Dictionary = {}
	# Draw uniformly from remaining individual units, not inventory slots.
	for draw in amount:
		var ticket := rng.randi_range(0, total - 1)
		for index in inventory.entries.size():
			var entry := inventory.entries[index]
			if ticket < entry.count:
				var label := entry.item.display_name
				lost[label] = int(lost.get(label, 0)) + 1
				inventory.remove(index)
				break
			ticket -= entry.count
		total -= 1
	return {"gold_lost": gold / 2, "items_lost": lost, "item_count_lost": amount}
