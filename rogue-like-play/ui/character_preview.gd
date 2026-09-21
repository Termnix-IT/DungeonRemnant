class_name CharacterPreview
extends Control

var hero: AnimatedSprite2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero = AnimatedSprite2D.new()
	hero.sprite_frames = MioAnimation.build_front_idle_frames()
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.centered = false
	hero.offset = Vector2(-64, -121)
	add_child(hero)
	var eyes := AnimatedSprite2D.new()
	eyes.sprite_frames = MioAnimation.build_front_idle_frames(true)
	eyes.animation = &"idle_front"
	eyes.centered = false
	eyes.position = hero.offset + Vector2(55, 31)
	hero.add_child(eyes)
	hero.frame_changed.connect(func(): eyes.set_frame_and_progress(hero.frame, hero.frame_progress))
	hero.play(&"idle_front")
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	if hero == null:
		return
	var factor := maxf(0.01, minf(size.x / 90.0, (size.y - 14) / 128.0))
	hero.scale = Vector2.ONE * factor
	hero.position = Vector2(size.x / 2, size.y - 10)
	queue_redraw()


func _draw() -> void:
	var color := get_theme_color(&"font_color", &"GoldLabel")
	color.a = 0.3
	draw_set_transform(Vector2(size.x / 2, size.y - 12), 0, Vector2(1, 0.26))
	draw_arc(Vector2.ZERO, size.x * 0.45, 0, TAU, 64, color, 1.5, true)
	draw_set_transform(Vector2.ZERO)
