extends Node2D

var kind: StringName = &"slash"
var points: Array[Vector2] = []
var direction := Vector2.RIGHT
var phase := 0.0:
	set(value):
		phase = value
		queue_redraw()


func start(effect_kind: StringName, cells: Array[Vector2], facing: Vector2, duration: float = 0.22) -> void:
	kind = effect_kind
	points = cells
	direction = facing.normalized()
	z_index = 12
	var tween := create_tween()
	tween.tween_property(self, "phase", 1.0, duration)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var tint := Color("f3dfb2")
	if kind == &"magic":
		tint = Color("bdb1f1")
	elif kind == &"heal":
		tint = Color("8ed7b6")
	elif kind == &"heavy":
		tint = Color("d6b287")
	tint.a = (1.0 - phase) * 0.9
	var side := direction.orthogonal()
	for center in points:
		match kind:
			&"slash":
				var angle := direction.angle() - 1.2 + phase * 1.1
				draw_arc(center - direction * 9, 17 + phase * 7, angle, angle + 1.7, 12, tint, 3, true)
			&"thrust":
				var tip := center + direction * (phase * 18 - 6)
				draw_line(tip - direction * 22, tip, tint, 3, true)
				draw_line(tip - direction * 6 + side * 4, tip, tint, 2, true)
				draw_line(tip - direction * 6 - side * 4, tip, tint, 2, true)
			&"magic":
				draw_circle(center, 5 + phase * 11, Color(tint, tint.a * 0.2))
				draw_arc(center, 8 + phase * 12, 0, TAU, 16, tint, 2, true)
				for index in 4:
					var ray := Vector2.from_angle(index * PI / 2 + phase)
					draw_line(center + ray * 5, center + ray * (12 + phase * 6), tint, 2, true)
			&"heal":
				draw_arc(center, 12 + phase * 12, 0, TAU, 20, tint, 2, true)
				draw_line(center + Vector2(0, -9 - phase * 8), center + Vector2(0, 3 - phase * 8), tint, 3)
				draw_line(center + Vector2(-6, -3 - phase * 8), center + Vector2(6, -3 - phase * 8), tint, 3)
			_:
				for index in 6:
					var ray := Vector2.from_angle(index * TAU / 6 + direction.angle())
					draw_line(center + ray * (3 + phase * 10), center + ray * (11 + phase * 16), tint, 2, true)
				if kind == &"heavy":
					draw_arc(center, 4 + phase * 23, 0, TAU, 20, tint, 2, true)
