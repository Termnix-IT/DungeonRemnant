class_name WeaponMount
extends RefCounted

# A weapon other than the sword drawn in the hero's hand: the rig's sword
# part is hidden and in its place lies a quad of the weapon's picture,
# skinned to the same hand bone, so every motion that swings the sword swings
# it. The quad lies along the sword's own axis in that facing (measured from
# the sword's picture: the long axis of its opaque pixels, its grip being the
# end nearer the hand), the hand on the weapon's grip (Moveset.art_grip, a
# share of the picture's height from its head) and the weapon art_length
# times as long as the sword. The picture stands upright, head at the top.

const PART := &"Sword"
const NAME := &"Weapon"
# Pixels with less alpha are not counted as the sword.
const SOLID := 0.5


# Holds `weapon` in every facing of a DirectionalRig (or one CharacterRig).
static func hold(rig: Node, weapon: Moveset) -> void:
	if rig is DirectionalRig:
		for each: CharacterRig in (rig as DirectionalRig).facing_rigs():
			_hold(each, weapon)
	elif rig is CharacterRig:
		_hold(rig, weapon)


static func _hold(rig: CharacterRig, weapon: Moveset) -> void:
	var parts := rig.get_node_or_null(^"Parts")
	var sword := parts.get_node_or_null(NodePath(PART)) as Polygon2D if parts != null else null
	if sword == null:
		return
	var old := parts.get_node_or_null(NodePath(NAME))
	if old != null:
		old.free()
	var art: Texture2D = weapon.art if weapon != null else null
	sword.visible = art == null
	if art == null or sword.get_bone_count() == 0:
		return
	var axis := sword_axis(sword)
	if axis.is_empty():
		sword.visible = true
		return
	var grip: Vector2 = axis[0]
	var tip: Vector2 = axis[1]
	var along := (tip - grip).normalized()
	var across := along.orthogonal()
	var extent := art.get_size()
	var scale := (tip - grip).length() * weapon.art_length / extent.y
	var head := grip + along * extent.y * weapon.art_grip * scale
	var foot := grip - along * extent.y * (1.0 - weapon.art_grip) * scale
	var half := across * extent.x * 0.5 * scale
	var quad := Polygon2D.new()
	quad.name = NAME
	quad.texture = art
	quad.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.polygon = PackedVector2Array([head - half, head + half, foot + half, foot - half])
	quad.uv = PackedVector2Array([Vector2.ZERO, Vector2(extent.x, 0.0), extent, Vector2(0.0, extent.y)])
	if sword.has_meta(&"mirror_hide"):
		quad.set_meta(&"mirror_hide", true)
	parts.add_child(quad)
	parts.move_child(quad, sword.get_index() + 1)
	quad.skeleton = sword.skeleton
	for index in sword.get_bone_count():
		var weight := 1.0 if index == 0 else 0.0
		quad.add_bone(sword.get_bone_path(index), PackedFloat32Array([weight, weight, weight, weight]))


# [grip, tip] of the sword part in the rig's rest space: the long axis of its
# opaque pixels, the grip the end nearer the joint of the bone that holds it.
# Empty when its picture cannot be read.
static func sword_axis(sword: Polygon2D) -> Array:
	if sword.texture == null or sword.uv.is_empty() or sword.polygon.is_empty():
		return []
	var image := sword.texture.get_image()
	if image == null:
		return []
	if image.is_compressed():
		image.decompress()
	var region := Rect2(sword.uv[0], Vector2.ZERO)
	for point in sword.uv:
		region = region.expand(point)
	var placed := Rect2(sword.polygon[0], Vector2.ZERO)
	for point in sword.polygon:
		placed = placed.expand(point)
	var cells: Array[Vector2] = []
	var middle := Vector2.ZERO
	for y in int(region.size.y):
		for x in int(region.size.x):
			if image.get_pixel(int(region.position.x) + x, int(region.position.y) + y).a >= SOLID:
				var at := Vector2(x, y)
				cells.append(at)
				middle += at
	if cells.size() < 4:
		return []
	middle /= cells.size()
	var xx := 0.0
	var yy := 0.0
	var xy := 0.0
	for at in cells:
		var off := at - middle
		xx += off.x * off.x
		yy += off.y * off.y
		xy += off.x * off.y
	var along := Vector2.from_angle(0.5 * atan2(2.0 * xy, xx - yy))
	var low := INF
	var high := -INF
	for at in cells:
		var reach := (at - middle).dot(along)
		low = minf(low, reach)
		high = maxf(high, reach)
	var stretch := placed.size / region.size
	var first := placed.position + (middle + along * low) * stretch
	var second := placed.position + (middle + along * high) * stretch
	var joint := _rest_joint(sword)
	return [first, second] if first.distance_to(joint) <= second.distance_to(joint) else [second, first]


# Where the first bone the part follows has its joint, at rest, in the
# rig's space (its skeleton sits at the rig's origin).
static func _rest_joint(part: Polygon2D) -> Vector2:
	var skeleton := part.get_node_or_null(part.skeleton)
	var bone := skeleton.get_node_or_null(part.get_bone_path(0)) if skeleton != null else null
	var rest := Transform2D.IDENTITY
	while bone is Bone2D:
		rest = (bone as Bone2D).rest * rest
		bone = bone.get_parent()
	return rest.origin
