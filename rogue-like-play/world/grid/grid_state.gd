class_name GridState
extends RefCounted

var size := Vector2i.ZERO
var walls: Dictionary = {}
## Pillars are also walls for movement, line of sight and attacks.
var pillars: Dictionary = {}
## Obstacles standing on floor cells: cell -> kind (a key of OBSTACLES).
## None can be walked through; each kind says whether sight and attacks
## pass it, and a breakable one is destroyed by the first attack to reach it.
var obstacles: Dictionary = {}
var occupants: Dictionary = {}
const RUBBLE := &"rubble"
const CRATE := &"crate"
const WATER := &"water"
# kind: [sight passes, attacks pass, breakable]. Rubble is a low heap: seen
# over, but it stops a thrust or a bolt. A crate hides what is behind it and
# breaks when struck. Deep water stops only feet.
const OBSTACLES := {
	RUBBLE: [true, false, false],
	CRATE: [false, false, true],
	WATER: [true, true, false],
}
## Transient presentation events; combat rules remain synchronous.
var visual_events: Array[Dictionary] = []


func is_floor(cell: Vector2i) -> bool:
	return in_bounds(cell) and not walls.has(cell)


# A floor cell an actor can stand on: no obstacle.
func is_open(cell: Vector2i) -> bool:
	return is_floor(cell) and not obstacles.has(cell)


# Sight passes walls never, obstacles by their kind.
func is_transparent(cell: Vector2i) -> bool:
	return is_floor(cell) and (not obstacles.has(cell) or OBSTACLES[obstacles[cell]][0])


# An attack's line passes walls never, obstacles by their kind.
func lets_attacks(cell: Vector2i) -> bool:
	return is_floor(cell) and (not obstacles.has(cell) or OBSTACLES[obstacles[cell]][1])


func is_breakable(cell: Vector2i) -> bool:
	return obstacles.has(cell) and OBSTACLES[obstacles[cell]][2]


# An attack's line from one cell to the next, diagonals not cutting a corner
# it could not pass.
func attack_passes(from: Vector2i, to: Vector2i) -> bool:
	if not lets_attacks(to):
		return false
	var delta := to - from
	if delta.x != 0 and delta.y != 0:
		return lets_attacks(from + Vector2i(delta.x, 0)) and lets_attacks(from + Vector2i(0, delta.y))
	return true


# Breaks a breakable obstacle; the presentation shows it splinter.
func break_obstacle(cell: Vector2i) -> bool:
	if not is_breakable(cell):
		return false
	visual_events.append({"kind": "break", "cell": cell, "obstacle": obstacles[cell]})
	obstacles.erase(cell)
	return true


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func can_step(from: Vector2i, to: Vector2i) -> bool:
	var delta := to - from
	if delta == Vector2i.ZERO or absi(delta.x) > 1 or absi(delta.y) > 1:
		return false
	if not is_open(to):
		return false
	if delta.x != 0 and delta.y != 0:
		return is_open(from + Vector2i(delta.x, 0)) and is_open(from + Vector2i(0, delta.y))
	return true


func place(actor: Node2D, cell: Vector2i) -> bool:
	if not is_open(cell) or occupants.has(cell):
		return false
	occupants[cell] = actor
	actor.cell = cell
	return true


func move_actor(actor: Node2D, destination: Vector2i) -> bool:
	if not can_step(actor.cell, destination) or occupants.has(destination):
		return false
	visual_events.append({"kind": "move", "actor": actor, "origin": actor.cell, "direction": destination - actor.cell})
	occupants.erase(actor.cell)
	occupants[destination] = actor
	actor.cell = destination
	return true


func remove_actor(actor: Node2D) -> void:
	if occupants.get(actor.cell) == actor:
		occupants.erase(actor.cell)
