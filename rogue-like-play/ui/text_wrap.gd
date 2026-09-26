class_name TextWrap
extends RefCounted

# Japanese has no spaces, so autowrap breaks wherever the width runs out and
# can strand one or two characters ("増加す／る"). For text that needs two
# lines, this picks a break near the middle after a particle or punctuation
# and inserts it explicitly. Longer text is left to the Label's autowrap.
const BREAK_AFTER := "、。，．・がをにはでともへのや）」』"
const NO_LINE_START := "、。，．・ゃゅょっゎぁぃぅぇぉャュョッヮァィゥェォー）」』！？"
const SOURCE := &"text_wrap_source"


static func set_text(label: Label, text: String) -> void:
	# Bound callables are not reliably equal, so the meta marks the hookup.
	if not label.has_meta(SOURCE):
		label.resized.connect(_rebalance.bind(label))
	label.set_meta(SOURCE, text)
	_rebalance(label)


static func _rebalance(label: Label) -> void:
	var source: String = label.get_meta(SOURCE, label.text)
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	# Measure against the text area the Label really wraps in, or autowrap
	# re-breaks the chosen line a character early.
	var style := label.get_theme_stylebox(&"normal")
	var width := label.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT) - 2.0
	var text := balanced(source, font, font_size, width)
	if label.text != text:
		label.text = text


static func balanced(text: String, font: Font, font_size: int, width: float) -> String:
	if width <= 0.0 or text.contains("\n"):
		return text
	var total := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if total <= width:
		return text
	var best := -1
	var best_score := INF
	for index in range(1, text.length()):
		var head := font.get_string_size(text.substr(0, index), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if head > width:
			break
		if total - head > width or NO_LINE_START.contains(text[index]):
			continue
		# Prefer natural break points; otherwise the split nearest the middle.
		var score := absf(head - total / 2.0) + (0.0 if BREAK_AFTER.contains(text[index - 1]) else width * 0.3)
		if score < best_score:
			best_score = score
			best = index
	return text if best < 0 else text.substr(0, best) + "\n" + text.substr(best)
