class_name SpawnEntry
extends Resource

# One kind of foe in a SpawnTable: how often it is picked against the others,
# and the stretch of the area's time (seconds) it appears in.

@export var foe: FoeData
@export_range(0.0, 100.0) var weight := 1.0
@export_range(0.0, 3600.0) var from_time := 0.0
# Zero: until the end.
@export_range(0.0, 3600.0) var until_time := 0.0


func active_at(time: float) -> bool:
	return foe != null and weight > 0.0 and time >= from_time and (until_time <= 0.0 or time < until_time)
