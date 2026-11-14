class_name ThemeMood
extends Resource

# A screen's own mood (ui/theme/moods/<page>.tres): the one theme with some
# of its tokens turned, set on the screen's root so that it reaches that
# screen alone. A mood changes colours only, and only through the tokens:
# a whole family turned (`families`, as in ThemeTokens) or one token given
# another colour (`colors`). Everything else (sizes, margins, fonts, the
# shapes of frames) stays the one theme's, and test_ui_theme checks that its
# words still read against its pages.
#
# The theme for a mood is built when it is first asked for (HubTheme.mood()):
# the one theme copied with the mood's tokens written through the bindings,
# so a change to the one theme or its tokens reaches every mood with no file
# to rebuild.

const FOLDER := "res://ui/theme/moods/"

@export var families: Dictionary[StringName, Vector3] = {}
@export var colors: Dictionary[StringName, Color] = {}

static var _built: Dictionary = {}


# The mood of `page`, or null when the page has none.
static func of(page: StringName) -> ThemeMood:
	var path := FOLDER + String(page) + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as ThemeMood


# The one theme in `page`'s mood, or null when the page has none. Built once.
static func theme_of(page: StringName, base: Theme) -> Theme:
	if _built.has(page):
		return _built[page]
	var mood := ThemeMood.of(page)
	var built: Theme = null
	if mood != null:
		built = mood.build(base, ThemeTokens.current(), ThemeBindings.current())
	_built[page] = built
	return built


# The tokens as this mood turns them.
func turn(tokens: ThemeTokens) -> ThemeTokens:
	var turned := tokens.duplicate(true) as ThemeTokens
	for family: StringName in families:
		turned.families[family] = families[family]
	for token: StringName in colors:
		turned.colors[token] = colors[token]
	return turned


func build(base: Theme, tokens: ThemeTokens, bindings: ThemeBindings) -> Theme:
	var built := base.duplicate(true) as Theme
	ThemeBuild.apply(built, turn(tokens), bindings)
	return built
