class_name SpawnTable
extends Resource

# Who an EnemyDirector sends and how many: the foes alive it aims for grow
# with the area's time, up to a cap, filled at a limited rate; elites come
# on their own schedule.

@export var entries: Array[SpawnEntry] = []
@export_range(0, 1000) var start_alive := 10
@export_range(0.0, 1000.0) var alive_per_minute := 30.0
@export_range(1, 1000) var max_alive := 120
# The most foes brought in per second while short of the aim.
@export_range(0.1, 100.0) var spawns_per_second := 6.0
@export var elite: FoeData
@export_range(0.0, 3600.0) var elite_first := 30.0
@export_range(1.0, 3600.0) var elite_every := 45.0
# Elites alive at once, at most.
@export_range(0, 20) var elite_cap := 2


func alive_at(time: float) -> int:
	return mini(max_alive, start_alive + floori(alive_per_minute * time / 60.0))
