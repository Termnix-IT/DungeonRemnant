class_name RigView
extends Node2D

# Holds a rig (a CharacterRig or DirectionalRig) in the world. This node's
# origin is the rig's origin, the point between its soles; the owner moves,
# turns and squashes this node, and the rig keeps its own motion inside it.
#
# The rig is drawn straight into the world, which the project draws without
# pixel snap, so its parts move smoothly. (It once had a SubViewport of its
# own per actor, drawn at the screen's scale, because the whole world was
# snapped to pixels for the pixel-art floor.) The rig's parts keep their draw
# order by sibling order and use no z_index, so nothing in it reaches the
# actors' y-sort.

var rig: Node2D
var _paused := false


func setup(rig_node: Node2D) -> void:
	rig = rig_node
	add_child(rig)
	# A hidden actor (an enemy out of sight) still processes its children;
	# its rig stops here instead.
	visibility_changed.connect(_follow_visibility)
	_follow_visibility()


# Only a rig this view paused is resumed, so one its owner stopped (a fallen
# hero) stays still.
func _follow_visibility() -> void:
	var shown := is_visible_in_tree()
	if not shown and rig.process_mode != Node.PROCESS_MODE_DISABLED:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
		_paused = true
	elif shown and _paused:
		rig.process_mode = Node.PROCESS_MODE_INHERIT
		_paused = false
