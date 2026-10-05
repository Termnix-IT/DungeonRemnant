class_name SkillNodeButton
extends Button

# One node of the permanent tree: its emblem in a ring of rank marks, its
# name and rank under it. The tree draws the wires between nodes; a node's
# dark disc covers their ends. A node not yet open is dim and carries a
# padlock; a node that can be grown with the Gold at hand carries a gold
# diamond (StateMark), so where to grow next reads before choosing; a capped
# node's ring is whole and bright; the chosen node stands on the lobby band's
# warm glow with its name in gold. The Button keeps focus and input.

const NAME_GAP := 6.0

var id: StringName
var emblem := ""
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
	return Vector2(size.x * 0.5, radius() + 4.0)


# From the disc's middle down to the foot of the name and rank, where a wire
# leaving downwards starts so it never crosses them.
func foot() -> float:
	return size.y - centre().y


func setup(node_id: StringName, key: String, extent: float) -> void:
	id = node_id
	emblem = key
	emblem_size = extent
	var font := get_theme_font(&"font")
	var lines := font.get_height(get_theme_font_size(&"font_size")) + font.get_height(get_theme_font_size(&"rank_font_size"))
	# Narrow enough that neighbouring tiers never share a pointer target.
	custom_minimum_size = Vector2(maxf(radius() * 2.0 + 8.0, 100.0), radius() * 2.0 + 4.0 + NAME_GAP + lines + 4.0)
	size = custom_minimum_size


func show_rank(name_text: String, current: int, cap: int, available: bool, affordable: bool = false) -> void:
	title = name_text
	rank = current
	max_rank = maxi(cap, 1)
	open = available
	growable = available and current < max_rank and affordable
	tooltip_text = "%s　Lv %d / %d%s" % [title, rank, max_rank, "" if available else "（未解放）"]
	queue_redraw()


func _draw() -> void:
	var middle := centre()
	var ring := radius()
	var rail := get_theme_color(&"rail", &"HubLobby")
	var muted := get_theme_color(&"font_color", &"MutedLabel")
	var body := get_theme_color(&"font_color", &"Label")
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
		draw_arc(middle, ring - 2.0, start, start + step - gap, 12, tone, 3.0, true)
	var art := Rect2((middle - Vector2.ONE * emblem_size * 0.5).round(), Vector2.ONE * emblem_size)
	var picture := EmblemIcons.texture(emblem)
	var shade := Color(1, 1, 1, 1.0 if open else 0.32)
	if picture != null:
		draw_texture_rect(picture, art, false, shade)
	if has_focus():
		draw_arc(middle, ring + 4.0, 0, TAU, 48, get_theme_color(&"focus_ring"), 1.5, true)
	# The state mark sits on the disc's upper right, clear of the wires.
	var corner := middle + Vector2(ring, -ring) * 0.74
	if not open:
		StateMark.lock(self, corner, 14.0, Color(muted, 0.85))
	elif growable:
		StateMark.ready(self, corner, 6.0, get_theme_color(&"font_color", &"GoldLabel"))
	# Name and rank under the disc, centred.
	var font := get_theme_font(&"font")
	var name_size := get_theme_font_size(&"font_size")
	var rank_size := get_theme_font_size(&"rank_font_size")
	var top := middle.y + ring + NAME_GAP + font.get_ascent(name_size)
	var name_tone := get_theme_color(&"font_color", &"GoldLabel") if button_pressed else (body if open else muted)
	draw_string(font, Vector2(0, top), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, name_size, name_tone)
	var rank_text := "上限" if capped else "Lv %d / %d" % [rank, max_rank]
	draw_string(font, Vector2(0, top + font.get_descent(name_size) + font.get_ascent(rank_size) + 2.0), rank_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, rank_size, muted)
