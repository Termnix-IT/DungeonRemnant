class_name GroundRing
extends Node2D

# A shock racing out over the floor from where a round blow (a charged
# swing, the skill, a blast, a boss's roar) lands, to the blow's reach, and
# burning away behind its front: what the blow covered, shown at once. It
# is a true circle that stops at the reach, as the blow is measured (and
# the foes' warnings are drawn). Drawn among the floor's marks, under the
# fighters, added as light (Vfx.ring); it frees itself.

const TIME := 0.36
# Ring colours by the attack's painted effect.
const COLORS := {&"magic": Color(0.62, 0.7, 1.0), &"heavy": Color(1.0, 0.8, 0.45), &"roar": Color(1.0, 0.28, 0.18, 0.8), &"flame": Color(1.0, 0.6, 0.3), &"hostile": Color(1.0, 0.34, 0.24)}
const DEFAULT := Color(1.0, 0.92, 0.75)

var radius := 100.0
var color := DEFAULT


func start(at: Vector2, reach: float, effect: StringName) -> void:
	position = at
	radius = reach
	color = COLORS.get(effect, DEFAULT)
	var shock := Vfx.ring(self, Vector2.ZERO, reach, color, TIME)
	shock.tree_exited.connect(queue_free)
