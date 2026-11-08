class_name ChapterDoor
extends Button

# A chapter's door on the departure (HubSortie), as stage selects that set
# their places side by side as doors show them: the chapter's painting cut
# to a round-topped arch, and at its foot a dark plate with the number, the
# name and how far it has been taken. The doors stand shoulder to shoulder;
# the chosen one steps forward, a little larger and lit, over its neighbours
# in a glowing gold frame, while the others stay darker. A sealed door is
# dark, with the chapter seal on it. The focus adds a thin light edge
# outside the frame.
#
# The door draws itself on a face inside the button, so it can step forward
# (scale) without moving what the container laid out; the button keeps no
# style of its own (DoorButton).

const CHOSEN_SCALE := 1.05
const SEAL_SIZE := 64.0
# The plate at the door's foot, and the fall from the painting into it.
const PLATE_HEIGHT := 112.0
const PLATE_FADE := 72.0
const ARCH_STEPS := 40
const FOCUS_GAP := 10.0
# The chosen frame: a gold line, a finer line inside it, and a glow round it.
const FRAME_WIDTH := 3.0
const INNER_INSET := 6.0
const GLOW_WIDTHS := [16.0, 9.0]

var painting: Texture2D:
	set(value):
		painting = value
		_face.queue_redraw()
# Where across the painting the arch looks (0 its left edge, 1 its right).
var focus_x := 0.5:
	set(value):
		focus_x = value
		_face.queue_redraw()
var sealed := false:
	set(value):
		sealed = value
		_face.queue_redraw()
# 0 stands in line, 1 stands forward as the chosen door (UIMotion.stand()).
var stand := 0.0:
	set(value):
		stand = value
		_place_face()
var number_label: Label
var name_label: Label
var state_label: Label
var _face: Control
var _words: VBoxContainer


func _init() -> void:
	theme_type_variation = &"DoorButton"
	toggle_mode = true
	_face = Control.new()
	_face.name = "Face"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.draw.connect(_draw_face)
	_face.resized.connect(_place_face)
	_words = VBoxContainer.new()
	_words.theme_type_variation = &"CompactStack"
	_words.alignment = BoxContainer.ALIGNMENT_CENTER
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_words)
	_words.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_words.offset_top = -PLATE_HEIGHT
	_words.offset_bottom = -12
	number_label = _line(&"NoteLabel")
	name_label = _line(&"HeadingLabel")
	state_label = _line(&"MutedLabel")
	focus_entered.connect(_face.queue_redraw)
	focus_exited.connect(_face.queue_redraw)
	mouse_entered.connect(_face.queue_redraw)
	mouse_exited.connect(_face.queue_redraw)


func _line(role: StringName) -> Label:
	var line := HubUI.label(_words, "", role)
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return line


# The face grows from the door's foot as it steps forward, over its
# neighbours, and its words brighten with it.
func _place_face() -> void:
	if _face == null:
		return
	var weight := clampf(stand, 0.0, 1.0)
	_face.pivot_offset = Vector2(_face.size.x * 0.5, _face.size.y)
	_face.scale = Vector2.ONE * lerpf(1.0, CHOSEN_SCALE, weight)
	_face.z_index = 1 if weight > 0.0 else 0
	_words.modulate = Color(1, 1, 1, lerpf(0.62, 1.0, weight))
	_face.queue_redraw()


# The door's outline: straight sides, a half circle over the top.
func _outline(rect: Rect2) -> PackedVector2Array:
	var radius := rect.size.x * 0.5
	var points := PackedVector2Array([Vector2(rect.position.x, rect.end.y)])
	var centre := Vector2(rect.position.x + radius, rect.position.y + radius)
	for step in ARCH_STEPS + 1:
		var angle := PI + PI * step / ARCH_STEPS
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	points.append(rect.end)
	return points


# Where in the painting each point of the door falls: the painting covers
# the door, cut around where the arch looks.
func _uvs(points: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var cut := Rect2(0, 0, 1, 1)
	if painting != null:
		var picture := Vector2(painting.get_size())
		var door_ratio := rect.size.x / rect.size.y
		if picture.x / picture.y > door_ratio:
			cut.size.x = picture.y * door_ratio / picture.x
			cut.position.x = clampf(focus_x - cut.size.x * 0.5, 0.0, 1.0 - cut.size.x)
		else:
			cut.size.y = picture.x / door_ratio / picture.y
			cut.position.y = (1.0 - cut.size.y) * 0.5
	var uvs := PackedVector2Array()
	for point in points:
		var along := (point - rect.position) / rect.size
		uvs.append(cut.position + along * cut.size)
	return uvs


func _draw_face() -> void:
	var rect := Rect2(Vector2.ZERO, _face.size)
	if rect.size.x <= 0.0 or rect.size.y <= rect.size.x * 0.5:
		return
	var weight := clampf(stand, 0.0, 1.0)
	var shape := _outline(rect)
	var closed := shape.duplicate()
	closed.append(shape[0])
	# The chosen door's glow spreads round it, behind the door itself.
	if weight > 0.0:
		var glow := get_theme_color(&"glow", &"DoorButton")
		for width: float in GLOW_WIDTHS:
			_face.draw_polyline(closed, Color(glow, glow.a * weight), width, true)
	# A shadow falls behind the door so it stands off the hall.
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(0, 8))
	_face.draw_colored_polygon(shadow, get_theme_color(&"shade", &"DoorButton"))
	# The painting, darker while sealed and while standing back.
	var tint := get_theme_color(&"art_locked" if sealed else &"art_open", &"DoorButton")
	var light := lerpf(get_theme_constant(&"rest_light", &"DoorButton") / 100.0, 1.0, weight)
	if is_hovered() and weight < 1.0:
		light = minf(1.0, light + 0.12)
	tint = Color(tint.r * light, tint.g * light, tint.b * light, 1.0)
	if painting != null:
		_face.draw_polygon(shape, PackedColorArray([tint]), _uvs(shape, rect), painting)
	else:
		_face.draw_colored_polygon(shape, tint)
	# The plate: the painting falls into it, and the words stand on it.
	var plate := get_theme_color(&"plate", &"DoorButton")
	var fade_top := rect.end.y - PLATE_HEIGHT - PLATE_FADE
	var plate_top := rect.end.y - PLATE_HEIGHT
	_face.draw_polygon(
		PackedVector2Array([Vector2(0, fade_top), Vector2(rect.size.x, fade_top), Vector2(rect.size.x, plate_top), Vector2(0, plate_top)]),
		PackedColorArray([Color(plate, 0.0), Color(plate, 0.0), plate, plate]))
	_face.draw_rect(Rect2(0, plate_top, rect.size.x, PLATE_HEIGHT), plate)
	if sealed:
		var seal := EmblemIcons.texture("seal_chapter")
		var middle := Vector2(rect.size.x * 0.5, (rect.size.x * 0.5 + plate_top) * 0.5)
		_face.draw_texture_rect(seal, Rect2(middle - Vector2.ONE * SEAL_SIZE * 0.5, Vector2.ONE * SEAL_SIZE), false, Color(1, 1, 1, lerpf(0.7, 1.0, weight)))
	# The edge: quiet bronze in line; once chosen, a gold frame with a finer
	# line inside it.
	var gold := get_theme_color(&"chosen_edge", &"DoorButton")
	if weight > 0.0:
		var inner := _outline(rect.grow(-INNER_INSET))
		inner.append(inner[0])
		_face.draw_polyline(inner, Color(gold, 0.55 * weight), 1.0, true)
	var edge := get_theme_color(&"edge", &"DoorButton").lerp(gold, weight)
	_face.draw_polyline(closed, edge, lerpf(1.0, FRAME_WIDTH, weight), true)
	if has_focus():
		var outer := _outline(rect.grow(FOCUS_GAP))
		outer.append(outer[0])
		_face.draw_polyline(outer, get_theme_color(&"focus_edge", &"DoorButton"), 1.0, true)
