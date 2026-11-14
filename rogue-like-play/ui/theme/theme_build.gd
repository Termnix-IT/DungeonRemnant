class_name ThemeBuild
extends RefCounted

# Writes the one theme's colours and font sizes from its tokens (ThemeTokens)
# through its bindings (ThemeBindings), and tells what is out of step:
# a colour or size no token is bound to, a binding to a place or token that
# is not there, or a value that differs from its token. tools/build_theme.gd
# runs it on dungeon_theme.tres; test_ui_theme.gd checks that nothing is out
# of step.
#
# A place is named as in ThemeBindings. Properties of a built-in resource
# that still hold their class's default are not places, and a resource the
# theme uses twice is named once, by the first place it is met (types in
# name order).

const DATA_KINDS := {
	"colors": Theme.DATA_TYPE_COLOR,
	"font_sizes": Theme.DATA_TYPE_FONT_SIZE,
	"styles": Theme.DATA_TYPE_STYLEBOX,
	"fonts": Theme.DATA_TYPE_FONT,
	"icons": Theme.DATA_TYPE_ICON,
}
const DEFAULT_FONT_SIZE := "default_font_size"


# Every colour and font size the theme holds: {"colors": {place: Color},
# "font_sizes": {place: int}}.
static func places(theme: Theme) -> Dictionary:
	var found := {"colors": {}, "font_sizes": {}}
	var seen := {}
	if theme.default_font_size > 0:
		found["font_sizes"][DEFAULT_FONT_SIZE] = theme.default_font_size
	for kind: String in DATA_KINDS:
		var data_type: int = DATA_KINDS[kind]
		var types := Array(theme.get_theme_item_type_list(data_type))
		types.sort()
		for type_name: String in types:
			var items := Array(theme.get_theme_item_list(data_type, type_name))
			items.sort()
			for item: String in items:
				var place := "%s/%s/%s" % [type_name, kind, item]
				var value: Variant = theme.get_theme_item(data_type, item, type_name)
				if kind == "colors":
					found["colors"][place] = value
				elif kind == "font_sizes":
					found["font_sizes"][place] = value
				elif value is Resource:
					_walk(value, place, found, seen)
	return found


static func _walk(resource: Resource, place: String, found: Dictionary, seen: Dictionary) -> void:
	if seen.has(resource.get_instance_id()):
		return
	seen[resource.get_instance_id()] = true
	if not resource.resource_path.is_empty() and not resource.resource_path.contains("::"):
		return
	# A built-in class's default is unset; a scripted style's (QuietWindowStyle)
	# is its look, so every one of its colours is a place.
	var fresh: Object = null if resource.get_script() != null else ClassDB.instantiate(resource.get_class())
	for property in resource.get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE) or property.name == "script":
			continue
		var value: Variant = resource.get(property.name)
		if fresh != null and typeof(fresh.get(property.name)) == typeof(value) and fresh.get(property.name) == value:
			continue
		var at := "%s:%s" % [place, property.name]
		if value is Color:
			found["colors"][at] = value
		elif value is PackedColorArray:
			for i in (value as PackedColorArray).size():
				found["colors"]["%s[%d]" % [at, i]] = value[i]
		elif value is Resource:
			_walk(value, at, found, seen)


# Writes every bound place from its token. Returns the places it changed.
static func apply(theme: Theme, tokens: ThemeTokens, bindings: ThemeBindings) -> PackedStringArray:
	var changed: PackedStringArray = []
	for place: String in bindings.colors:
		var parsed := ThemeBindings.parse_color(bindings.colors[place])
		if not tokens.colors.has(parsed[0]):
			continue
		var want := tokens.color(parsed[0], parsed[1])
		var have: Variant = read(theme, place)
		if have is Color and not (have as Color).is_equal_approx(want):
			write(theme, place, want)
			changed.append(place)
	for place: String in bindings.font_sizes:
		var token := StringName(bindings.font_sizes[place])
		if not tokens.font_sizes.has(token):
			continue
		var size := tokens.font_size(token)
		if read(theme, place) is int and read(theme, place) != size:
			write(theme, place, size)
			changed.append(place)
	return changed


# What is out of step between the theme, its tokens and its bindings; empty
# when the theme is exactly what its tokens make.
static func problems(theme: Theme, tokens: ThemeTokens, bindings: ThemeBindings) -> PackedStringArray:
	var found := places(theme)
	var out: PackedStringArray = []
	for place: String in found["colors"]:
		if not bindings.colors.has(place):
			out.append("No token is bound to the colour at %s" % place)
	for place: String in found["font_sizes"]:
		if not bindings.font_sizes.has(place):
			out.append("No token is bound to the font size at %s" % place)
	for place: String in bindings.colors:
		var parsed := ThemeBindings.parse_color(bindings.colors[place])
		var have: Variant = read(theme, place)
		if not tokens.colors.has(parsed[0]):
			out.append("%s is bound to %s, which is not a token" % [place, parsed[0]])
		elif not have is Color:
			out.append("%s is bound but is not a colour in the theme" % place)
		elif not (have as Color).is_equal_approx(tokens.color(parsed[0], parsed[1])):
			out.append("%s differs from %s; run tools/build_theme.gd" % [place, bindings.colors[place]])
	for place: String in bindings.font_sizes:
		var token := StringName(bindings.font_sizes[place])
		var have: Variant = read(theme, place)
		if not tokens.font_sizes.has(token):
			out.append("%s is bound to %s, which is not a token" % [place, token])
		elif not have is int:
			out.append("%s is bound but is not a font size in the theme" % place)
		elif have != tokens.font_size(token):
			out.append("%s differs from %s; run tools/build_theme.gd" % [place, token])
	return out


# Binds each unbound place whose value is exactly a token's (any alpha for a
# colour). Returns the places it could not bind.
static func bind_exact(theme: Theme, tokens: ThemeTokens, bindings: ThemeBindings) -> PackedStringArray:
	var found := places(theme)
	var left: PackedStringArray = []
	for place: String in found["colors"]:
		if bindings.colors.has(place):
			continue
		var value: Color = found["colors"][place]
		var hit := StringName()
		for token: StringName in tokens.colors:
			if tokens.color(token, value.a).is_equal_approx(value):
				hit = token
				break
		if hit.is_empty():
			left.append(place)
		else:
			bindings.colors[place] = ThemeBindings.color_binding(hit, value.a)
	for place: String in found["font_sizes"]:
		if bindings.font_sizes.has(place):
			continue
		var token: Variant = tokens.font_sizes.find_key(found["font_sizes"][place])
		if token == null:
			left.append(place)
		else:
			bindings.font_sizes[place] = String(token)
	return left


static func read(theme: Theme, place: String) -> Variant:
	if place == DEFAULT_FONT_SIZE:
		return theme.default_font_size
	var steps := place.split(":")
	var head := steps[0].split("/")
	if head.size() != 3 or not DATA_KINDS.has(head[1]):
		return null
	var data_type: int = DATA_KINDS[head[1]]
	if not theme.has_theme_item(data_type, head[2], head[0]):
		return null
	var value: Variant = theme.get_theme_item(data_type, head[2], head[0])
	for i in range(1, steps.size()):
		if not value is Object:
			return null
		var index := _index(steps[i])
		value = (value as Object).get(_name(steps[i]))
		if index >= 0:
			if not value is PackedColorArray or index >= (value as PackedColorArray).size():
				return null
			value = value[index]
	return value


static func write(theme: Theme, place: String, value: Variant) -> void:
	if place == DEFAULT_FONT_SIZE:
		theme.default_font_size = value
		return
	var steps := place.split(":")
	var head := steps[0].split("/")
	var data_type: int = DATA_KINDS[head[1]]
	if steps.size() == 1:
		theme.set_theme_item(data_type, head[2], head[0], value)
		return
	var holder: Object = theme.get_theme_item(data_type, head[2], head[0])
	for i in range(1, steps.size() - 1):
		holder = holder.get(steps[i])
	var last := steps[steps.size() - 1]
	var index := _index(last)
	if index < 0:
		holder.set(last, value)
	else:
		var colors: PackedColorArray = holder.get(_name(last))
		colors[index] = value
		holder.set(_name(last), colors)


static func _name(step: String) -> String:
	var bracket := step.find("[")
	return step if bracket < 0 else step.substr(0, bracket)


static func _index(step: String) -> int:
	var bracket := step.find("[")
	return -1 if bracket < 0 else step.substr(bracket + 1, step.length() - bracket - 2).to_int()
