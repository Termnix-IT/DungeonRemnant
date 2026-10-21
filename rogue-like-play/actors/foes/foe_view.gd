class_name FoeView
extends Node2D

# How a foe looks, told by its Foe: mirrored to face its way, walking,
# bracing through a wind-up, striking, flinching and falling; a shadow, and
# for an elite a ring at its feet and a health bar once hurt. A crowd foe
# (FoeData.baked) is drawn from its rig baked into frames (FoeFrames), which
# costs far less than the skinned rig; the others draw the rig itself
# (EnemySprites). It never changes what happens in the fight.

const RIG_HEIGHT := 60.0
const FLASH := Color(2.6, 2.6, 2.6)
const FLASH_TIME := 0.12
const SHADOW := Color(0.04, 0.045, 0.05, 0.5)
const ELITE_RING := Color(0.95, 0.3, 0.2, 0.55)
const BAR_BACK := Color(0.05, 0.04, 0.04, 0.8)
const BAR_FILL := Color(0.92, 0.3, 0.22)
const BAR_SIZE := Vector2(54, 5)
# The baked walk was drawn for this walking speed (world px/s); faster foes
# play it faster.
const WALK_SPEED := 100.0
const IDLE := &"idle"
const WALK := &"walk"
const BRACE := &"brace"
const ATTACK := &"attack_sword"
const HURT := &"hurt"
const DOWN := &"down"

var foe: Foe
var rig: CharacterRig
var rig_view: RigView
var sprite: AnimatedSprite2D
var height := RIG_HEIGHT
var _body: Node2D
var _flash: Tween
var _braced := false
# The tint of the status it carries (Status.TINT), under any flash.
var _tint := Color.WHITE


func setup(owner_foe: Foe) -> void:
	foe = owner_foe
	var baked := FoeFrames.of(foe.data.visual_id) if foe.data.baked else {}
	if not baked.is_empty():
		sprite = AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.sprite_frames = baked.frames
		sprite.centered = false
		sprite.offset = -baked.feet
		sprite.scale = Vector2.ONE * foe.data.size_scale / baked.scale
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.animation_finished.connect(_on_motion_finished)
		add_child(sprite)
		height = baked.height * foe.data.size_scale
		_body = sprite
		_play(IDLE)
		sprite.frame = randi() % sprite.sprite_frames.get_frame_count(IDLE)
		return
	var path := EnemySprites.rig_path(foe.data.visual_id)
	if not ResourceLoader.exists(path):
		return
	rig_view = RigView.new()
	rig_view.name = "RigView"
	add_child(rig_view)
	rig = (load(path) as PackedScene).instantiate()
	height = float(rig.get_meta(&"world_height", RIG_HEIGHT)) * foe.data.size_scale
	rig.world_height = height
	rig_view.setup(rig)
	_body = rig_view


func walk(direction: Vector2) -> void:
	if absf(direction.x) > 8.0:
		face(direction.x < 0.0)
	var moving := direction.length() > 20.0
	if rig != null:
		if moving:
			rig.step(direction)
	elif sprite != null and sprite.animation in [IDLE, WALK]:
		if moving:
			_play(WALK)
			sprite.speed_scale = clampf(direction.length() / WALK_SPEED, 0.6, 2.2)
		else:
			_play(IDLE)


func face(left: bool) -> void:
	if sprite != null:
		sprite.flip_h = left
	elif rig_view != null:
		rig_view.scale.x = -1.0 if left else 1.0


func brace(on: bool) -> void:
	_braced = on
	if rig != null:
		rig.braced = on
	elif sprite != null and sprite.animation in [IDLE, WALK, BRACE]:
		_play(BRACE if on and sprite.sprite_frames.has_animation(BRACE) else IDLE)


func strike() -> void:
	if rig != null:
		rig.attack()
	elif sprite != null:
		_play(ATTACK, true)


func hurt(flinch: bool) -> void:
	if _body == null:
		return
	if _flash != null:
		_flash.kill()
	_body.modulate = FLASH
	_flash = create_tween()
	_flash.tween_property(_body, "modulate", _tint, FLASH_TIME)
	if flinch:
		if rig != null:
			rig.hurt()
		elif sprite != null:
			_play(HURT, true)
	queue_redraw()


func fall() -> void:
	_braced = false
	if rig != null:
		rig.braced = false
		rig.fall()
	elif sprite != null:
		_play(DOWN, true)
	queue_redraw()


# Tints by the status it carries: burning over shocked.
func show_statuses(statuses: Dictionary) -> void:
	_tint = Color.WHITE
	for id: StringName in [Status.SHOCK, Status.BURN]:
		if statuses.has(id):
			_tint = Status.TINT[id]
	if _body != null and (_flash == null or not _flash.is_running()):
		_body.modulate = _tint


func revive() -> void:
	_braced = false
	_tint = Color.WHITE
	if _flash != null:
		_flash.kill()
	if _body != null:
		_body.modulate = Color.WHITE
	if rig != null:
		rig.braced = false
		rig.idle()
	elif sprite != null:
		_play(IDLE, true)
	queue_redraw()


# Plays a motion from its start when asked, or carries on if it already
# plays; one missing from the bake falls back to the idle.
func _play(motion: StringName, restart: bool = false) -> void:
	if not sprite.sprite_frames.has_animation(motion):
		motion = IDLE
	if sprite.animation == motion and not restart and sprite.is_playing():
		return
	sprite.speed_scale = 1.0
	sprite.play(motion)
	if restart:
		sprite.frame = 0


# A one-shot motion over: back to the brace or the idle (the fall holds).
func _on_motion_finished() -> void:
	if sprite.animation == DOWN:
		return
	_play(BRACE if _braced else IDLE)


func _draw() -> void:
	var size := foe.data.size_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 13.0 * size, SHADOW)
	if foe.data.elite and not foe.dying:
		draw_arc(Vector2.ZERO, foe.hit_radius + 6.0, 0.0, TAU, 36, ELITE_RING, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if foe.data.elite and not foe.dying and foe.health.hp < foe.health.max_hp:
		var top := Vector2(-BAR_SIZE.x * 0.5, -height - 12.0)
		draw_rect(Rect2(top - Vector2.ONE, BAR_SIZE + Vector2.ONE * 2.0), BAR_BACK)
		draw_rect(Rect2(top, Vector2(BAR_SIZE.x * foe.health.hp / foe.health.max_hp, BAR_SIZE.y)), BAR_FILL)
