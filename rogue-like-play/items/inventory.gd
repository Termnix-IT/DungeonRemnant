class_name Inventory
extends RefCounted

const MAX_ENTRIES := 40
const MAX_STACK := 50
var entries: Array[InventoryEntry] = []


func add(item: ItemData, amount: int = 1) -> int:
	# Returns the unaccepted amount. A stackable type never spills into a second slot.
	if item == null or amount <= 0:
		return maxi(0, amount)
	if item.stackable():
		for entry in entries:
			if entry.item.id == item.id:
				var accepted := mini(amount, MAX_STACK - entry.count)
				entry.count += accepted
				return amount - accepted
		if entries.size() >= MAX_ENTRIES:
			return amount
		var accepted := mini(amount, MAX_STACK)
		entries.append(InventoryEntry.new(item, accepted))
		return amount - accepted
	var accepted := mini(amount, MAX_ENTRIES - entries.size())
	for index in accepted:
		entries.append(InventoryEntry.new(item))
	return amount - accepted


func remove(index: int, amount: int = 1) -> bool:
	if index < 0 or index >= entries.size() or amount <= 0 or entries[index].count < amount:
		return false
	entries[index].count -= amount
	if entries[index].count == 0:
		entries.remove_at(index)
	return true


func copy() -> Inventory:
	var result := Inventory.new()
	for entry in entries:
		result.entries.append(InventoryEntry.new(entry.item, entry.count))
	return result
