class_name WaveData
extends Resource

# One wave of an arena: how many of each foe come in (foes[i], counts[i]),
# a few at a time, each announced by a mark on the floor.

@export var foes: Array[FoeData] = []
@export var counts: Array[int] = []
# Foes brought in per second while the wave is still arriving.
@export_range(0.5, 50.0) var spawns_per_second := 4.0


func total() -> int:
	var sum := 0
	for count in counts:
		sum += count
	return sum


# The wave's foes in the order they arrive: the kinds taken in turn.
func order() -> Array[FoeData]:
	var left := counts.duplicate()
	var sequence: Array[FoeData] = []
	var added := true
	while added:
		added = false
		for index in mini(foes.size(), left.size()):
			if left[index] > 0:
				sequence.append(foes[index])
				left[index] -= 1
				added = true
	return sequence
