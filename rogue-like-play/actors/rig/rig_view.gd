class_name RigView
extends Node2D

# Shows a rig (a CharacterRig or DirectionalRig) in the world as one picture.
# The rig is drawn into its own SubViewport at the screen's scale (camera
# zoom and window stretch) with pixel snap off, so its parts move smoothly
# while the project snaps everything else (the floor's pixel art) to pixels;
# the picture is then placed here, one texel per screen pixel. This node's
# origin is the rig's origin, the point between its soles.
#
# With unsnapped off, the rig is simply a child and snaps like the rest of
# the world: cheaper (no render target per actor), but its small motions
# then move a pixel at a time.

# The local px around the origin the picture covers, room for the rig's
# reach in every motion.
@export var box := Rect2(-60, -100, 120, 128)
@export var unsnapped := true

var rig: Node2D
var viewport: SubViewport
var display: Sprite2D
var _holder: Node2D
# This node's scale in the world when set up (an enemy's 1.5, say). The
# screen's scale is read live, but a squash or stretch the battle
# presentation puts on a parent is left to the picture, so the view is not
# resized on every frame of it.
var _world_scale := 1.0
var _paused := false


func setup(rig_node: Node2D) -> void:
	rig = rig_node
	if not unsnapped:
		add_child(rig)
		return
	viewport = SubViewport.new()
	viewport.name = "View"
	viewport.transparent_bg = true
	viewport.snap_2d_transforms_to_pixel = false
	viewport.snap_2d_vertices_to_pixel = false
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(viewport)
	_holder = Node2D.new()
	viewport.add_child(_holder)
	_holder.add_child(rig)
	display = Sprite2D.new()
	display.name = "Display"
	display.centered = false
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.texture = viewport.get_texture()
	add_child(display)
	_world_scale = absf(global_transform.get_scale().y) if is_inside_tree() else 1.0
	# A view is a canvas of its own, so hiding this node (an enemy out of
	# sight) does not hide the rig inside it; stop it here instead.
	visibility_changed.connect(_follow_visibility)
	_follow_visibility()
	fit()


# Only a rig this view paused is resumed, so one its owner stopped (a fallen
# hero) stays still.
func _follow_visibility() -> void:
	var shown := is_visible_in_tree()
	set_process(shown)
	if not shown and rig.process_mode != Node.PROCESS_MODE_DISABLED:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
		_paused = true
	elif shown and _paused:
		rig.process_mode = Node.PROCESS_MODE_INHERIT
		_paused = false


func _process(_delta: float) -> void:
	fit()


# Sizes the view to the screen's scale at this node, so its picture lands one
# texel per screen pixel.
func fit() -> void:
	if viewport == null or not is_inside_tree():
		return
	var screen_scale := absf((get_viewport().get_final_transform() * get_canvas_transform()).get_scale().y) * _world_scale
	if screen_scale <= 0.0:
		return
	var size := Vector2i((box.size * screen_scale).ceil())
	if viewport.size != size:
		viewport.size = size
	_holder.position = -box.position * screen_scale
	_holder.scale = Vector2.ONE * screen_scale
	display.position = box.position
	display.scale = Vector2.ONE / screen_scale
