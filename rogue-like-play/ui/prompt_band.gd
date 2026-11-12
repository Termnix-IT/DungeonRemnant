class_name PromptBand
extends PanelContainer

# The band a question stands on (ChoicePrompt): a low strip across the whole
# screen instead of a boxed window, so the world it asks about stays in view
# above and below it. A dark see-through face fades out toward both sides; a
# gold hairline runs along its top and its bottom, brightest in the middle
# and gone at the ends; a four-pointed star sits on the top line's middle and
# a small diamond on the bottom one's. Nothing else is ornament.
#
# Opening, the lines draw out from the middle to their ends (`reveal`, 0 to
# 1). The colours are the theme's (PromptBand); the panel style only keeps
# the room above and below the words.

# How much of each side the face and the lines take to fade to nothing.
const FADE := 0.32
# The lines reach this far across the band, each side of the middle.
const LINE_REACH := 0.46
const STAR_LONG := 22.0
const STAR_SHORT := 9.0
const STAR_WAIST := 2.2
const GLOW_RADII := [22.0, 16.0, 11.0, 7.0]
const DIAMOND := 3.5
const GLINT := 90.0
# Where the lines start drawing out from when the band opens.
const REVEAL_FROM := 0.18

var reveal := 1.0:
	set(value):
		reveal = value
		queue_redraw()


func _init() -> void:
	theme_type_variation = &"PromptBand"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var width := size.x
	var middle := width * 0.5
	# The face: opaque in the middle, faded at the sides.
	var fill := get_theme_color(&"fill")
	var clear := Color(fill, 0.0)
	var edge := width * FADE
	var xs := [0.0, edge, width - edge, width]
	var tones := [clear, fill, fill, clear]
	for index in 3:
		draw_polygon(
			PackedVector2Array([Vector2(xs[index], 0), Vector2(xs[index + 1], 0), Vector2(xs[index + 1], size.y), Vector2(xs[index], size.y)]),
			PackedColorArray([tones[index], tones[index + 1], tones[index + 1], tones[index]]))
	# The lines, drawn out from the middle by `reveal`.
	var line := get_theme_color(&"line")
	var reach := width * LINE_REACH * lerpf(REVEAL_FROM, 1.0, clampf(reveal, 0.0, 1.0))
	for y: float in [0.5, size.y - 0.5]:
		_hairline(Vector2(middle, y), reach, line)
	# The star on the top line, in a soft glow, and the diamond below.
	var star := get_theme_color(&"ornament")
	var glow := get_theme_color(&"glow")
	var top := Vector2(middle, 0.5)
	for radius: float in GLOW_RADII:
		draw_circle(top, radius, Color(glow, glow.a * reveal))
	# A short glint along the line each side of the star.
	_hairline(top, GLINT * reveal, star)
	draw_colored_polygon(PackedVector2Array([
		top + Vector2(0, -STAR_LONG), top + Vector2(STAR_WAIST, -STAR_WAIST),
		top + Vector2(STAR_SHORT * 2.2, 0), top + Vector2(STAR_WAIST, STAR_WAIST),
		top + Vector2(0, STAR_LONG), top + Vector2(-STAR_WAIST, STAR_WAIST),
		top + Vector2(-STAR_SHORT * 2.2, 0), top + Vector2(-STAR_WAIST, -STAR_WAIST),
	]), star)
	draw_circle(top, 2.0, Color(1, 1, 1, 0.85 * star.a))
	var bottom := Vector2(middle, size.y - 0.5)
	draw_colored_polygon(PackedVector2Array([
		bottom + Vector2(0, -DIAMOND), bottom + Vector2(DIAMOND, 0),
		bottom + Vector2(0, DIAMOND), bottom + Vector2(-DIAMOND, 0),
	]), Color(star, star.a * 0.8))


# A hairline from centre out to both sides, bright at the centre and fading
# to nothing at its ends.
func _hairline(centre: Vector2, reach: float, color: Color) -> void:
	var points := PackedVector2Array([centre - Vector2(reach, 0), centre - Vector2(reach * 0.45, 0), centre, centre + Vector2(reach * 0.45, 0), centre + Vector2(reach, 0)])
	var colors := PackedColorArray([Color(color, 0.0), Color(color, color.a * 0.55), color, Color(color, color.a * 0.55), Color(color, 0.0)])
	draw_polyline_colors(points, colors, 1.0, true)
