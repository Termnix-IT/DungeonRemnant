extends SceneTree

# The translation table, locale/text.csv: one row for every Japanese text the
# game shows, keyed by the Japanese itself, with its English. The game's
# words are written in Japanese where they are used (the scripts' strings,
# and the text fields of the data's .tres), and shown through tr(), which
# finds the English here when the language is English and keeps the Japanese
# otherwise (the fallback locale is Japanese).
#
# Run from rogue-like-play/ after the Japanese changes:
#   godot --headless --path . --script res://tools/text_catalog.gd
# It adds a row for each new text, keeps the English already written, drops
# the rows whose Japanese is gone (printing them, so a reworded line's
# English can be carried over by hand), and reports the rows still without
# English. tests/test_translation.gd checks the table the same way.
#
# A line ending in the comment "# not translated" holds Japanese that is not
# shown as words (TextWrap's breaking rules, the languages' own names), and
# is left out.
#
# Columns: the Japanese key, its ?context (tr()'s second argument, for one
# Japanese that needs two English words), the English, and _where, the first
# file it was found in (columns starting with "_" are not imported).

const TABLE := "res://locale/text.csv"
const HEADER: Array[String] = ["keys", "?context", "en", "_where"]
const SCANNED: Array[String] = ["res://actors", "res://audio", "res://combat", "res://data", "res://game", "res://progression", "res://ui", "res://world"]

static var _japanese: RegEx
static var _with_context: RegEx


static func has_japanese(text: String) -> bool:
	if _japanese == null:
		_japanese = RegEx.create_from_string("[\\x{3040}-\\x{30ff}\\x{3400}-\\x{9fff}\\x{ff01}-\\x{ff5e}]")
	return _japanese.search(text) != null


# Every Japanese text the game shows, in the order found: an Array of
# {key, context, where}, one per key and context.
static func gather() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen := {}
	for folder in SCANNED:
		for path in _files(folder):
			var texts := _script_texts(path) if path.ends_with(".gd") else _data_texts(path)
			for pair: Array in texts:
				var id := row_id(pair[0], pair[1])
				if seen.has(id):
					continue
				seen[id] = true
				found.append({"key": pair[0], "context": pair[1], "where": path.trim_prefix("res://")})
	return found


static func row_id(key: String, context: String) -> String:
	return key + "\u0004" + context


# The table as written: row_id -> {key, context, en, where}, in file order.
static func read_table(path: String = TABLE) -> Dictionary:
	var rows := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 3 or line[0] == "":
			continue
		rows[row_id(line[0], line[1])] = {"key": line[0], "context": line[1], "en": line[2], "where": line[3] if line.size() > 3 else ""}
	return rows


static func _files(folder: String) -> Array[String]:
	var files: Array[String] = []
	for name in DirAccess.get_files_at(folder):
		if name.ends_with(".gd") or name.ends_with(".tres"):
			files.append(folder.path_join(name))
	for name in DirAccess.get_directories_at(folder):
		files.append_array(_files(folder.path_join(name)))
	return files


# The scripts' Japanese strings, outside comments and multi-line strings
# (the shaders'): [text, context] pairs.
static func _script_texts(path: String) -> Array:
	if _with_context == null:
		_with_context = RegEx.create_from_string("^\\s*,\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*\\)")
	var texts := []
	var in_block := false
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.count("\"\"\"") % 2 == 1:
			in_block = not in_block
			continue
		if in_block or line.ends_with("# not translated"):
			continue
		for part: Array in _literals(line):
			var text: String = (part[0] as String).c_unescape()
			if not has_japanese(text):
				continue
			var context := ""
			var after: String = line.substr(part[1])
			var called := _with_context.search(after)
			if called != null and line.substr(0, part[2]).ends_with("tr("):
				context = called.get_string(1).c_unescape()
			texts.append([text, context])
	return texts


# The string literals of one line before its comment: [text as written,
# the index after its closing quote, the index of its opening quote].
static func _literals(line: String) -> Array:
	var parts := []
	var at := 0
	while at < line.length():
		var c := line[at]
		if c == "#":
			break
		if c == "\"":
			var end := at + 1
			while end < line.length() and line[end] != "\"":
				if line[end] == "\\":
					end += 1
				end += 1
			parts.append([line.substr(at + 1, end - at - 1), end + 1, at])
			at = end + 1
			continue
		at += 1
	return parts


# The data's text fields, read from the loaded Resource (a text may run over
# several lines of the file): every String property, and every String in an
# Array property (a boon's families), holding Japanese, in the Resource and
# the Resources it holds.
static func _data_texts(path: String) -> Array:
	var texts := []
	_resource_texts(load(path), texts, {})
	return texts


static func _resource_texts(resource: Resource, texts: Array, visited: Dictionary) -> void:
	if resource == null or visited.has(resource):
		return
	visited[resource] = true
	for property: Dictionary in resource.get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = resource.get(property.name)
		var values: Array = value if value is Array else ([value] if not value is PackedStringArray else Array(value))
		for item: Variant in values:
			if item is String and has_japanese(item):
				texts.append([item, ""])
			elif item is Resource and (item as Resource).resource_path.is_empty() or item is Resource and (item as Resource).resource_path.contains("::"):
				_resource_texts(item, texts, visited)


func _initialize() -> void:
	var old := read_table()
	var found := gather()
	var file := FileAccess.open(TABLE, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % TABLE)
		quit(1)
		return
	file.store_csv_line(PackedStringArray(HEADER))
	var missing := 0
	var kept := {}
	for row in found:
		var id := row_id(row.key, row.context)
		var english: String = old[id].en if old.has(id) else ""
		kept[id] = true
		if english == "":
			missing += 1
		file.store_csv_line(PackedStringArray([row.key, row.context, english, row.where]))
	file.close()
	for id: String in old:
		if not kept.has(id) and old[id].en != "":
			print("Dropped: %s -> %s" % [old[id].key, old[id].en])
	print("Text table: %d rows, %d without English" % [found.size(), missing])
	quit(0)
