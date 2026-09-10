class_name Inventory
extends RefCounted

const MAX_ENTRIES := 40
const MAX_STACK := 50
var entries: Array[InventoryEntry] = []
var max_entries: int
var max_stack: int


func _init(entry_limit: int = MAX_ENTRIES, stack_limit: int = MAX_STACK) -> void:
	max_entries = entry_limit
	max_stack = stack_limit


func add(item: ItemData, amount: int = 1) -> int:
	# Returns the unaccepted amount. A stackable type never spills into a second slot.
	if item == null or amount <= 0:
		return maxi(0, amount)
	if item.stackable():
		for entry in entries:
			if entry.item.id == item.id:
				var accepted := mini(amount, max_stack - entry.count)
				entry.count += accepted
				return amount - accepted
		if entries.size() >= max_entries:
			return amount
		var accepted := mini(amount, max_stack)
		entries.append(InventoryEntry.new(item, accepted))
		return amount - accepted
	var accepted := mini(amount, max_entries - entries.size())
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
	var result := Inventory.new(max_entries, max_stack)
	for entry in entries:
		result.entries.append(InventoryEntry.new(entry.item, entry.count))
	return result
