extends SceneTree

# Writes the colours and font sizes of ui/theme/dungeon_theme.tres from its
# tokens (ui/theme/theme_tokens.tres) through its bindings
# (ui/theme/theme_bindings.tres). Run it after changing a token, and after
# adding a colour or size to the theme by hand: a new value that is exactly a
# token's is bound to it; any other is reported, to be made a token or
# changed to one.
#
#   godot --headless --path . --script res://tools/build_theme.gd
#   godot --headless --path . --script res://tools/build_theme.gd -- --check
#
# With --check it writes nothing and fails when the theme is out of step.

const THEME_PATH := "res://ui/theme/dungeon_theme.tres"


func _init() -> void:
	var check_only := OS.get_cmdline_user_args().has("--check")
	var theme: Theme = load(THEME_PATH)
	var tokens := ThemeTokens.current()
	var bindings := ThemeBindings.current()
	var before := bindings.colors.size() + bindings.font_sizes.size()
	var unbound := ThemeBuild.bind_exact(theme, tokens, bindings)
	var newly_bound := bindings.colors.size() + bindings.font_sizes.size() - before
	var changed := ThemeBuild.apply(theme, tokens, bindings)
	for place in unbound:
		printerr("No token matches %s (%s); add a token or use one" % [place, ThemeBuild.read(theme, place)])
	for place in changed:
		print("Written from its token: ", place)
	if check_only:
		var problems := ThemeBuild.problems(load(THEME_PATH), tokens, ThemeBindings.current())
		for problem in problems:
			printerr(problem)
		print("Theme check: %d problems" % problems.size())
		quit(0 if problems.is_empty() else 1)
		return
	if newly_bound > 0:
		print("Bound %d new places to tokens" % newly_bound)
		ResourceSaver.save(bindings, ThemeBindings.PATH)
	if not changed.is_empty() or newly_bound > 0:
		ResourceSaver.save(theme, THEME_PATH)
	print("Theme built: %d written, %d newly bound, %d unbound" % [changed.size(), newly_bound, unbound.size()])
	quit(0 if unbound.is_empty() else 1)
