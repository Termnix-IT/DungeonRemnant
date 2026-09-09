class_name GridState
extends RefCounted

var size := Vector2i.ZERO
var walls: Dictionary = {}
## Pillars are also walls for movement, line of sight and attacks.
var pillars: Dictionary = {}
var occupants: Dictionary = {}


func is_floor(cell: Vector2i) -> bool:
	return in_bounds(cell) and not walls.has(cell)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func can_step(from: Vector2i, to: Vector2i) -> bool:
	var delta := to - from
	if delta == Vector2i.ZERO or absi(delta.x) > 1 or absi(delta.y) > 1:
		return false
	if not is_floor(to):
		return false
	if delta.x != 0 and delta.y != 0:
		return is_floor(from + Vector2i(delta.x, 0)) and is_floor(from + Vector2i(0, delta.y))
	return true


func place(actor: Node2D, cell: Vector2i) -> bool:
	if not is_floor(cell) or occupants.has(cell):
		return false
	occupants[cell] = actor
	actor.cell = cell
	return true


func move_actor(actor: Node2D, destination: Vector2i) -> bool:
	if not can_step(actor.cell, destination) or occupants.has(destination):
		return false
	occupants.erase(actor.cell)
	occupants[destination] = actor
	actor.cell = destination
	return true


func remove_actor(actor: Node2D) -> void:
	if occupants.get(actor.cell) == actor:
		occupants.erase(actor.cell)
