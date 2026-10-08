class_name SkillNodeButton
extends Button

# One node of the permanent tree: its emblem in a ring of rank marks, with no
# words on the tree (the name and rank are in its tooltip and the detail
# column). The start floor tree uses the same node with a picture in place of
# the emblem: a stage's island, or the guardian whose defeat opens a floor.
# The tree draws the wires between nodes; a node's dark disc covers their
# ends. A node not yet open is dim and carries a padlock; a node that can be grown with the Gold at hand carries a gold
# diamond (StateMark), so where to grow next reads before choosing; a capped
# node's ring is whole and bright; the chosen node stands on the lobby band's
# warm glow. The Button keeps focus and input.

var id: StringName
var emblem := ""
# Drawn in place of the emblem when set: the region of the texture to show,
# or the whole texture when the region is empty.
var picture: Texture2D
var picture_region := Rect2()
# The picture as a dark shadow, for what has not been met yet.
var picture_hidden := false
var title := ""
var rank := 0
var max_rank := 1
# Its prerequisite is capped, so it can be grown.
var open := true
# Open, short of its cap and affordable now.
var growable := false
# The emblem's size: the centre at its stored 96px, the tiers at their native 48px.
var emblem_size := 48.0
# 0 to 1 on a gain (UIMotion.glow_in): the ring brightens.
var glow := 0.0:
	set(value):
		glow = value
		queue_redraw()
static var _halo: GradientTexture2D


func _init() -> void:
	theme_type_variation = &"SkillNode"
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL


func radius() -> float:
	return emblem_size * 0.5 + 9.0


# The middle of the disc, where the wires meet the node.
func centre() -> Vector2:
	return size * 0.5


func setup(node_id: StringName, key: String, extent: float) -> void:
	id = node_id
	emblem = key
	emblem_size = extent
	# The disc and its focus ring only, so neighbours never share a pointer target.
	custom_minimum_size = Vector2.ONE * (radius() * 2.0 + 8.0)
	size = custom_minimum_size


func show_rank(name_text: String, current: int, cap: int, available: bool, affordable: bool = false) -> void:
	show_state(name_text, current, cap, available, available and current < maxi(cap, 1) and affordable)
	tooltip_text = "%s　Lv %d / %d%s" % [title, rank, max_rank, "" if available else "（未解放）"]


# The ring's lit marks out of its marks, whether it is open, and whether it
# carries the ready mark; the caller words the tooltip.
func show_state(name_text: String, lit: int, marks: int, available: bool, ready: bool) -> void:
	title = name_text
	tooltip_text = name_text
	rank = lit
	max_rank = maxi(marks, 1)
	open = available
	growable = ready
	queue_redraw()


func _draw() -> void:
	var middle := centre()
	var ring := radius()
	var rail := get_theme_color(&"rail", &"HubLobby")
	var muted := get_theme_color(&"font_color", &"MutedLabel")
	var capped := rank >= max_rank
	if button_pressed:
		if _halo == null:
			var fade := Gradient.new()
			fade.set_color(0, Color.WHITE)
			fade.set_color(1, Color(1, 1, 1, 0))
			_halo = GradientTexture2D.new()
			_halo.gradient = fade
			_halo.fill = GradientTexture2D.FILL_RADIAL
			_halo.fill_from = Vector2(0.5, 0.5)
			_halo.fill_to = Vector2(1.0, 0.5)
			_halo.changed.connect(queue_redraw)
		var band := get_theme_color(&"band", &"HubLobby")
		draw_texture_rect(_halo, Rect2(middle - Vector2.ONE * ring * 2.0, Vector2.ONE * ring * 4.0), false, Color(band, band.a * 4.0))
	# The disc covers the wires' ends; hover lifts it a step.
	draw_circle(middle, ring, get_theme_color(&"disc_hover" if is_hovered() else &"disc"))
	# The ring: one mark per rank, the grown ones lit.
	var gap := 0.18 if max_rank > 1 else 0.0
	var step := TAU / max_rank
	for mark in max_rank:
		var start := -PI * 0.5 + step * mark + gap * 0.5
		var lit := mark < rank
		var tone := Color(rail, 1.0) if lit else Color(muted, 0.35 if open else 0.18)
		if lit and (capped or glow > 0.0):
			tone = tone.lerp(Color.WHITE, 0.25 * maxf(glow, 0.4 if capped else 0.0))
		draw_arc(middle, ring - 2.0, start, start + step - gap, maxi(12, 48 / max_rank), tone, 3.0, true)
	var art := Rect2((middle - Vector2.ONE * emblem_size * 0.5).round(), Vector2.ONE * emblem_size)
	var shade := Color(1, 1, 1, 1.0 if open else 0.32)
	if picture != null:
		var region := picture_region if picture_region.has_area() else Rect2(Vector2.ZERO, picture.get_size())
		draw_texture_rect_region(picture, art, region, Color(0.24, 0.22, 0.2, 0.9) if picture_hidden else shade)
	elif EmblemIcons.texture(emblem) != null:
		draw_texture_rect(EmblemIcons.texture(emblem), art, false, shade)
	if has_focus():
		draw_arc(middle, ring + 4.0, 0, TAU, 48, get_theme_color(&"focus_ring"), 1.5, true)
	# The state mark sits on the disc's upper right, clear of the wires.
	var corner := middle + Vector2(ring, -ring) * 0.74
	if not open:
		StateMark.lock(self, corner, 14.0, Color(muted, 0.85))
	elif growable:
		StateMark.ready(self, corner, 6.0, get_theme_color(&"font_color", &"GoldLabel"))
