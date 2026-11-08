extends SceneTree

# The save's move to its own folder: the old folder's save, its backup and
# the settings copied once into an empty new folder and read back there, the
# old files left in place, and nothing copied when the new folder already
# holds a save, when there is nothing to bring, or a second time.

var failures := 0
var checks := 0
var folder := ""


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func make(name: String) -> String:
	var path := ProjectSettings.globalize_path(folder.path_join(name))
	DirAccess.make_dir_recursive_absolute(path)
	return path


func write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# An old folder as the old build left it: a save with this much echo, the
# save before it as backup, and the settings.
func old_save(name: String, echo: int) -> String:
	var path := make(name)
	var store := MetaStore.new()
	store.path = path.path_join("progress.json")
	var meta := MetaProgress.new()
	meta.echo = echo - 10
	store.save_progress(meta)
	meta.echo = echo
	store.save_progress(meta)
	write(path.path_join("settings.cfg"), "[audio]\nvolume=0.25\n")
	return path


func echo_in(path: String) -> int:
	var store := MetaStore.new()
	store.path = path.path_join("progress.json")
	return store.load_progress().echo


func run_tests() -> void:
	folder = "res://.godot/save-move-test-%d" % Time.get_ticks_usec()

	check(OS.get_user_data_dir().replace("\\", "/").ends_with("/DungeonRemnant"), "The save lives in a folder of its own")
	check(SaveFolderMove.old_folder().replace("\\", "/").to_lower().ends_with("godot/app_userdata/roguelike_play"), "The old folder is the one Godot gave the working name")

	var old := old_save("old", 120)
	var new := ProjectSettings.globalize_path(folder.path_join("new"))
	var copied := SaveFolderMove.carry_over(old, new)
	check(copied.has("progress.json") and copied.has("progress.json.bak") and copied.has("settings.cfg"), "The save, its backup and the settings are copied")
	check(echo_in(new) == 120, "The copied save reads back with its echo")
	var settings := GameSettings.new()
	settings.path = new.path_join("settings.cfg")
	settings.load_settings()
	check(is_equal_approx(settings.volume, 0.25), "The copied settings read back")
	check(FileAccess.file_exists(old.path_join("progress.json")) and FileAccess.file_exists(old.path_join("progress.json.bak")), "The old files stay where they were")
	check(not FileAccess.file_exists(new.path_join("progress.json.carry")), "No partial copy is left behind")

	# The new folder's own save is newer than anything left in the old one.
	var newer := MetaStore.new()
	newer.path = new.path_join("progress.json")
	var meta := newer.load_progress()
	meta.echo = 300
	newer.save_progress(meta)
	check(SaveFolderMove.carry_over(old, new).is_empty(), "Nothing is copied a second time")
	check(echo_in(new) == 300, "The new folder's save is kept")

	var settled := make("settled")
	write(settled.path_join("settings.cfg"), "[audio]\nvolume=0.75\n")
	copied = SaveFolderMove.carry_over(old, settled)
	check(copied.has("progress.json") and not copied.has("settings.cfg"), "Settings saved in the new folder are not replaced")
	settings = GameSettings.new()
	settings.path = settled.path_join("settings.cfg")
	settings.load_settings()
	check(is_equal_approx(settings.volume, 0.75), "The new folder's settings are kept")

	var backup_only := make("backup-only")
	DirAccess.copy_absolute(old.path_join("progress.json.bak"), backup_only.path_join("progress.json.bak"))
	check(SaveFolderMove.carry_over(backup_only, ProjectSettings.globalize_path(folder.path_join("from-backup"))) == ["progress.json.bak"], "A backup alone is still brought over")

	var empty := make("empty")
	var untouched := ProjectSettings.globalize_path(folder.path_join("untouched"))
	check(SaveFolderMove.carry_over(empty, untouched).is_empty() and not DirAccess.dir_exists_absolute(untouched), "Nothing is made when there is nothing to bring")
	check(SaveFolderMove.carry_over(old, old).is_empty(), "A folder is not copied onto itself")

	_remove(ProjectSettings.globalize_path(folder))
	print("Save folder move: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _remove(path: String) -> void:
	for name in DirAccess.get_directories_at(path):
		_remove(path.path_join(name))
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
