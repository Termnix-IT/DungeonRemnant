extends SceneTree

## Builds a CharacterRig scene from its rig description and parts layout.
##
##	godot --headless --path . --script res://tools/build_character_rig.gd -- res://art/characters/mio_rig/front_rig.json
##
## The rig description (hand-written JSON) names the bones with their joints,
## the parts in drawing order with the bones that move them, and the
## animations. The parts layout (written by tools/build_rig_parts.py)
## places each part's picture in the atlas and in the figure. Joints in the
## description are pixels of the source illustration, so they can be read off
## it directly; the layout's source_origin and scale bring them to the
## figure. The scene's origin is the point between the soles.
## Rigid parts are one quad on one bone; a part with a bone chain becomes a
## grid weighted to the chain by distance, so hair and hems bend smoothly.
## Every animation keys the same tracks (missing ones hold the rest pose), so
## blending from one motion to another never leaves a bone behind. A
## description with "set" and "facing" also lists the built rig in that
## DirectionalRig scene under its facing.

const RIG_SCRIPT := preload("res://actors/rig/character_rig.gd")
const DIRECTIONAL_SCRIPT := preload("res://actors/rig/directional_rig.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Pass the rig description: -- res://art/characters/mio_rig/front_rig.json")
		quit(1)
		return
	var error := build(arguments[0])
	quit(0 if error == OK else 1)


static func read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	return data if data is Dictionary else {}


# atlas_override lets a test build from a picture made on the spot.
static func build(description_path: String, atlas_override: Texture2D = null) -> Error:
	var rig_data := read_json(description_path)
	var layout := read_json(String(rig_data.get("layout", "")))
	var atlas: Texture2D = atlas_override if atlas_override != null else load(String(rig_data.get("atlas", "")))
	if rig_data.is_empty() or layout.is_empty() or atlas == null:
		push_error("Rig description, layout or atlas is missing")
		return ERR_FILE_NOT_FOUND
	var feet := _vector(layout.feet)
	var origin := _vector(layout.get("source_origin", [0, 0]))
	var source_scale := float(layout.get("scale", 1.0))
	var to_rig := func(value: Variant) -> Vector2: return (_vector(value) - origin) * source_scale - feet
	var root := Node2D.new()
	root.name = String(rig_data.get("name", "CharacterRig"))
	root.set_script(RIG_SCRIPT)
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.set("figure_height", float(layout.figure_height))
	# The height it stands in the world, where the description sets one.
	if rig_data.has("height"):
		root.set_meta(&"world_height", float(rig_data.height))
	var skeleton := Skeleton2D.new()
	skeleton.name = "Skeleton"
	root.add_child(skeleton)
	var joints := {}
	var bones := {}
	for entry: Dictionary in rig_data.bones:
		var bone := Bone2D.new()
		bone.name = String(entry.name)
		var joint: Vector2 = to_rig.call(entry.at)
		joints[bone.name] = joint
		var parent_name := String(entry.get("parent", ""))
		var parent: Node = skeleton if parent_name.is_empty() else bones[parent_name]
		bone.position = joint - (Vector2.ZERO if parent_name.is_empty() else joints[parent_name])
		bone.rest = Transform2D(0.0, bone.position)
		bone.set_autocalculate_length_and_angle(false)
		if entry.get("spring", false):
			bone.set_meta(&"spring", true)
			bone.set_meta(&"spring_gain", float(entry.get("gain", 1.0)))
		parent.add_child(bone)
		bones[bone.name] = bone
	# Bone length and angle only draw the bones in the editor.
	for entry: Dictionary in rig_data.bones:
		var bone: Bone2D = bones[String(entry.name)]
		var tip: Vector2 = to_rig.call(entry.tip) if entry.has("tip") else Vector2.ZERO
		if not entry.has("tip"):
			for child in bone.get_children():
				if child is Bone2D:
					tip = joints[String(child.name)]
					break
		var reach: Vector2 = tip - joints[String(entry.name)]
		if reach.length() < 1.0:
			reach = Vector2(0, 12)
		bone.set_length(reach.length())
		bone.set_bone_angle(reach.angle())
	for entry: Dictionary in rig_data.get("anchors", []):
		var anchor := Node2D.new()
		anchor.name = String(entry.name)
		var bone: Bone2D = bones[String(entry.bone)]
		anchor.position = to_rig.call(entry.at) - joints[String(entry.bone)]
		bone.add_child(anchor)
	var parts := Node2D.new()
	parts.name = "Parts"
	root.add_child(parts)
	for entry: Dictionary in rig_data.parts:
		var part_name := String(entry.name)
		# A facing cut as one picture (its layers not made yet) has only
		# "Whole" and the sword; the parts it lacks are left out.
		if not layout.parts.has(part_name):
			continue
		var placed: Dictionary = layout.parts[part_name]
		var chain: Array = entry.get("bones", [entry.get("bone", "")])
		var polygon := _part_polygon(placed, feet, entry.get("grid", [1, 1]))
		polygon.name = part_name
		polygon.texture = atlas
		polygon.visible = entry.get("visible", true)
		# Hidden when the facing is shown mirrored (CharacterRig.mirrored).
		if entry.get("mirror_hide", false):
			polygon.set_meta(&"mirror_hide", true)
		parts.add_child(polygon)
		polygon.skeleton = polygon.get_path_to(skeleton)
		var chain_joints: Array[Vector2] = []
		for bone_name: String in chain:
			chain_joints.append(joints[bone_name])
		var tip: Vector2 = to_rig.call(entry.tip) if entry.has("tip") else chain_joints[-1] + Vector2(0, 1)
		var weights := _weights(polygon.polygon, chain_joints, tip, entry.get("weights", "") == "along")
		for index in chain.size():
			polygon.add_bone(skeleton.get_path_to(bones[chain[index]]), weights[index])
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.add_animation_library(&"", _library(rig_data, bones, skeleton, source_scale))
	root.set("lean_bone", root.get_path_to(bones[String(rig_data.lean_bone)]))
	var eyes: Array[NodePath] = []
	for eye_name: String in rig_data.get("eyes", []):
		if layout.parts.has(eye_name):
			eyes.append(NodePath("Parts/" + eye_name))
	root.set("eye_parts", eyes)
	if rig_data.has("weapon_anchor"):
		var anchor: Node = root.find_child(String(rig_data.weapon_anchor), true, false)
		root.set("weapon_anchor_path", root.get_path_to(anchor))
	_own(root, root)
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error == OK:
		error = ResourceSaver.save(scene, String(rig_data.output))
	root.free()
	if error == OK and rig_data.has("set"):
		error = _register(String(rig_data.set), StringName(rig_data.facing), String(rig_data.output))
	return error


# Lists the built facing in the character's DirectionalRig scene, making the
# scene the first time.
static func _register(set_path: String, facing: StringName, rig_path: String) -> Error:
	var holder: Node2D
	if ResourceLoader.exists(set_path):
		holder = (ResourceLoader.load(set_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	else:
		holder = Node2D.new()
		holder.set_script(DIRECTIONAL_SCRIPT)
		holder.name = set_path.get_file().get_basename().to_pascal_case()
	var scenes: Dictionary = holder.get("facing_scenes").duplicate()
	scenes[facing] = ResourceLoader.load(rig_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	holder.set("facing_scenes", scenes)
	var packed := PackedScene.new()
	var error := packed.pack(holder)
	if error == OK:
		error = ResourceSaver.save(packed, set_path)
	holder.free()
	return error


static func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)


static func _vector(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


# A part as a grid of quads over its picture: one quad for a rigid part,
# more rows and columns where it bends.
static func _part_polygon(placed: Dictionary, feet: Vector2, grid: Array) -> Polygon2D:
	var region := Rect2(_vector(placed.atlas), _vector([placed.atlas[2], placed.atlas[3]]))
	var origin := _vector(placed.at) - feet
	var columns := maxi(1, int(grid[0]))
	var rows := maxi(1, int(grid[1]))
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for row in rows + 1:
		for column in columns + 1:
			var share := Vector2(float(column) / columns, float(row) / rows)
			points.append(origin + region.size * share)
			uv.append(region.position + region.size * share)
	var cells: Array = []
	for row in rows:
		for column in columns:
			var corner := row * (columns + 1) + column
			cells.append(PackedInt32Array([corner, corner + 1, corner + columns + 2, corner + columns + 1]))
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.uv = uv
	polygon.polygons = cells
	return polygon


# Each point follows the chain's bones by its distance to their segments,
# sharpened so a point near one bone is mostly moved by that bone. "along"
# measures only how far down the chain a point is, so the wide corners of a
# skirt or a sheet of hair follow the bone at their height, not the nearest.
static func _weights(points: PackedVector2Array, chain: Array[Vector2], tip: Vector2, along := false) -> Array[PackedFloat32Array]:
	var result: Array[PackedFloat32Array] = []
	for index in chain.size():
		result.append(PackedFloat32Array())
		result[index].resize(points.size())
	var axis := (tip - chain[0]).normalized()
	for point_index in points.size():
		var point := points[point_index]
		if along:
			point = chain[0] + axis * axis.dot(point - chain[0])
		var total := 0.0
		var raw: Array[float] = []
		for index in chain.size():
			var from: Vector2 = chain[index]
			var to: Vector2 = chain[index + 1] if index + 1 < chain.size() else tip
			var nearest := Geometry2D.get_closest_point_to_segment(point, from, to)
			var weight := 1.0 / pow(maxf(point.distance_to(nearest), 1.0), 3.0)
			raw.append(weight)
			total += weight
		for index in chain.size():
			result[index][point_index] = raw[index] / total
	return result


static func _library(rig_data: Dictionary, bones: Dictionary, skeleton: Skeleton2D, source_scale: float) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var animations: Dictionary = rig_data.animations
	# Every track any motion keys, plus the lean bone's rotation, which the
	# rig adds to each frame and so must be reset by every animation.
	var tracks := {"%s:rotation" % rig_data.lean_bone: true}
	for data: Dictionary in animations.values():
		for track: String in data.tracks:
			tracks[track] = true
	var reset := {"length": 0.001, "loop": false, "tracks": {}}
	animations = animations.duplicate()
	animations["RESET"] = reset
	for animation_name: String in animations:
		var data: Dictionary = animations[animation_name]
		var animation := Animation.new()
		animation.length = float(data.length)
		animation.loop_mode = Animation.LOOP_LINEAR if data.get("loop", false) else Animation.LOOP_NONE
		if data.has("impact"):
			animation.set_meta(&"impact", float(data.impact))
		for track: String in tracks:
			var bone_name := track.get_slice(":", 0)
			var property := track.get_slice(":", 1)
			var bone: Bone2D = bones[bone_name]
			var index := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(index, NodePath("Skeleton/%s:%s" % [skeleton.get_path_to(bone), property]))
			animation.track_set_interpolation_type(index, Animation.INTERPOLATION_CUBIC)
			animation.value_track_set_update_mode(index, Animation.UPDATE_CONTINUOUS)
			var keys: Array = data.tracks.get(track, [[0.0, null]])
			for key: Array in keys:
				animation.track_insert_key(index, float(key[0]), _rest_plus(bone, property, key[1], source_scale))
		library.add_animation(StringName(animation_name), animation)
	return library


# Keys are offsets from the rest pose: degrees for rotation, source pixels
# for position, factors for scale; null holds the rest pose.
static func _rest_plus(bone: Bone2D, property: String, value: Variant, source_scale: float) -> Variant:
	match property:
		"rotation":
			return deg_to_rad(float(value)) if value != null else 0.0
		"position":
			return bone.rest.origin + (_vector(value) * source_scale if value != null else Vector2.ZERO)
		"scale":
			return _vector(value) if value != null else Vector2.ONE
	return value
