class_name SaveFolderMove
extends RefCounted

# The save once lived in Godot's own folder under the project's working name
# (%APPDATA%\Godot\app_userdata\RogueLike_play). It now has a folder of its
# own (project.godot's custom user dir), so the first start after the move
# copies what the old folder kept into the new one. Nothing is copied once
# the new folder holds a save, and the old files are left where they were.

const OLD_NAME := "RogueLike_play"
# The save itself goes first: a copy cut short after it still starts from
# the newest progress. Each file is written under a temporary name and then
# renamed, so a half-written copy never passes for a save.
const FILES: Array[String] = ["progress.json", "progress.json.bak", "progress.json.v4", "settings.cfg"]
const SAVES: Array[String] = ["progress.json", "progress.json.bak"]


# Where the old build kept its save on this machine.
static func old_folder() -> String:
	var godot := "godot" if OS.get_name() in ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"] else "Godot"
	return OS.get_data_dir().path_join(godot).path_join("app_userdata").path_join(OLD_NAME)


static func _has_save(folder: String) -> bool:
	for name in SAVES:
		if FileAccess.file_exists(folder.path_join(name)):
			return true
	return false


# Copies the old folder's save into the new one when the new one has none.
# Returns the names copied (empty when there was nothing to bring over).
static func carry_over(from: String, to: String) -> Array[String]:
	var copied: Array[String] = []
	if from.simplify_path() == to.simplify_path() or _has_save(to) or not _has_save(from):
		return copied
	DirAccess.make_dir_recursive_absolute(to)
	for name in FILES:
		var source := from.path_join(name)
		var target := to.path_join(name)
		# Settings saved here before the move are newer than the old ones.
		if not FileAccess.file_exists(source) or FileAccess.file_exists(target):
			continue
		var partial := target + ".carry"
		if DirAccess.copy_absolute(source, partial) != OK or DirAccess.rename_absolute(partial, target) != OK:
			DirAccess.remove_absolute(partial)
			return copied
		copied.append(name)
	return copied
