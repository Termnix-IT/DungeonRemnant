class_name ThemeBindings
extends Resource

# Where each token is used in the one theme (ui/theme/theme_bindings.tres),
# kept by tools/build_theme.gd rather than by hand. A key is a place in the
# theme: `Type/colors/item` or `Type/font_sizes/item` for a theme item,
# `default_font_size`, or a property inside a theme item's resource after a
# colon, as `PrimaryButton/styles/normal:bg_color` or, for one colour of a
# gradient, `CodexStage/styles/panel:texture:gradient:colors[1]`. A colour's
# value is its token with the binding's alpha after an `@`
# (`gold.12@0.45`; no `@` is fully opaque); a size's value is its token.

const PATH := "res://ui/theme/theme_bindings.tres"

@export var colors: Dictionary[String, String] = {}
@export var font_sizes: Dictionary[String, String] = {}


static func current() -> ThemeBindings:
	return load(PATH) as ThemeBindings


static func color_binding(token: StringName, alpha: float) -> String:
	if is_equal_approx(alpha, 1.0):
		return String(token)
	return "%s@%s" % [token, snappedf(alpha, 0.0001)]


# [token, alpha] from a colour binding.
static func parse_color(binding: String) -> Array:
	var at := binding.find("@")
	if at < 0:
		return [StringName(binding), 1.0]
	return [StringName(binding.substr(0, at)), binding.substr(at + 1).to_float()]
