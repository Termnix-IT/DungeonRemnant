class_name ActionSlot
extends Control

# One of the hero's actions in the HUD's bottom right: its emblem in a round
# slot, darkened by a sweep while it comes back and ringed gold when ready,
# its key (or gamepad button) under it, and for the dash, a pip for each
# charge. Never takes input.

const SIZE := 72.0
const BACK := Color(0.02, 0.025, 0.035, 0.88)
const SHADE := Color(0.0, 0.0, 0.0, 0.62)
const READY := Color("ffd27a")
const WAIT := Color(0.55, 0.58, 0.62, 0.9)
const PIP_FULL := Color("9fe3dc")
const PIP_EMPTY := Color(0.35, 0.4, 0.42, 0.7)
const SEGMENTS := 40

var icon: Texture2D
# 0 to 1: how far it has come back; 1 is ready.
var share := 1.0
# A ring of its own over the slot (the charge filling), 0 for none.
var fill := 0.0
var fill_color := READY
# Charges shown as pips above the slot; 0 shows none.
var charges := 0
var charges_max := 0
var key_label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE, SIZE + 26.0)
	key_label = Label.new()
	key_label.theme_type_variation = &"HudCaption"
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	key_label.offset_top = -24.0
	add_child(key_label)


func show_state(ready_share: float, ring: float = 0.0, charge_count: int = 0, charge_max: int = 0) -> void:
	share = clampf(ready_share, 0.0, 1.0)
	fill = clampf(ring, 0.0, 1.0)
	charges = charge_count
	charges_max = charge_max
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, SIZE * 0.5)
	var radius := SIZE * 0.5 - 3.0
	draw_circle(center, radius, BACK)
	if icon != null:
		var inset := radius * 0.92
		draw_texture_rect(icon, Rect2(center - Vector2.ONE * inset, Vector2.ONE * inset * 2.0), false)
	var ready := share >= 1.0
	if not ready:
		# The part still coming back, swept clockwise from the top.
		var points := PackedVector2Array([center])
		var start := -PI * 0.5 + TAU * share
		for index in SEGMENTS + 1:
			points.append(center + Vector2.from_angle(lerpf(start, PI * 1.5, float(index) / SEGMENTS)) * radius)
		if points.size() >= 3:
			draw_colored_polygon(points, SHADE)
	draw_arc(center, radius, 0.0, TAU, SEGMENTS, READY if ready else WAIT, 3.0 if ready else 2.0, true)
	if fill > 0.0:
		draw_arc(center, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * fill, SEGMENTS, fill_color, 3.0, true)
	for index in charges_max:
		var at := center + Vector2((index - (charges_max - 1) * 0.5) * 14.0, -radius - 8.0)
		draw_circle(at, 4.5, PIP_FULL if index < charges else PIP_EMPTY)
