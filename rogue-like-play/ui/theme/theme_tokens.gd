class_name ThemeTokens
extends Resource

# The named values the one theme is built from (ui/theme/theme_tokens.tres):
# its colours, grouped in families and ordered dark to light within each
# (`gold.1` is the darkest gold), and its font sizes, small to large. Every
# colour and font size in dungeon_theme.tres is bound to one of these
# (ThemeBindings) and written from it by tools/build_theme.gd, so a token
# changed here reaches every place that uses it.
#
# A family can be turned as a whole: `families` holds, per family, a hue turn
# in degrees, a saturation factor and a value factor, applied to each of its
# colours as it is written (Vector3(0, 1, 1) leaves it as it is). Making the
# golds a little cooler is one entry, not a hunt through the theme.

const PATH := "res://ui/theme/theme_tokens.tres"

@export var colors: Dictionary[StringName, Color] = {}
@export var font_sizes: Dictionary[StringName, int] = {}
@export var families: Dictionary[StringName, Vector3] = {}


# The tokens in use. Loaded, not preloaded, so that no node's export holds
# them as a default (see the SelfList note in CLAUDE.md).
static func current() -> ThemeTokens:
	return load(PATH) as ThemeTokens


static func family_of(token: StringName) -> StringName:
	var name := String(token)
	var dot := name.find(".")
	return StringName(name.substr(0, dot)) if dot > 0 else token


# The colour a token stands for once its family's turn is applied, with
# `alpha` for its opacity (tokens carry hue and light, a binding its alpha).
func color(token: StringName, alpha := 1.0) -> Color:
	var base: Color = colors[token]
	var turn: Vector3 = families.get(family_of(token), Vector3(0.0, 1.0, 1.0))
	if turn != Vector3(0.0, 1.0, 1.0):
		base = Color.from_hsv(fposmod(base.h + turn.x / 360.0, 1.0), clampf(base.s * turn.y, 0.0, 1.0), base.v * turn.z)
	return Color(base, alpha)


func font_size(token: StringName) -> int:
	return font_sizes[token]
