class_name InventoryEntry
extends RefCounted

var item: ItemData
var count: int


func _init(definition: ItemData = null, amount: int = 1) -> void:
	item = definition
	count = amount
