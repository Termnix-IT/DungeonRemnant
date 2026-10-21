class_name MetaStore
extends RefCounted

# Keeps MetaProgress in user://progress.json, the way the old SaveStore kept
# the turn-based game's: written to a temporary file and read back before it
# replaces the save, the replaced save kept as .bak, an unreadable save moved
# aside rather than overwritten, and saving stopped while a save cannot be
# read. A save from the turn-based game (versions 1 to 4) is brought in
# through MetaCodec.migrate; before the first save over it, the old file is
# kept as progress.json.v4.

const MAX_BYTES := 65536

var path := "user://progress.json"
var message := ""
var blocked := false
# True while message reports something the player should notice.
var alert := false
# The last load brought in an old save that still waits to be kept aside.
var migrated := false


func _read(file_path: String) -> Variant:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data


# Lasting progress from a file: a version 5 save, or an old one migrated.
func _progress(file_path: String) -> MetaProgress:
	var data: Variant = _read(file_path)
	var version := MetaCodec.version_of(data)
	if version == MetaCodec.VERSION:
		return MetaCodec.decode(data)
	if version > 0 and version < MetaCodec.VERSION:
		var meta := MetaCodec.migrate(data)
		migrated = meta != null
		return meta
	return null


func load_progress() -> MetaProgress:
	blocked = false
	migrated = false
	var meta := _progress(path) if FileAccess.file_exists(path) else null
	if meta != null:
		message = "以前の冒険の記録を引き継ぎました。所持Goldと強化に使ったGoldを残響に換えています。" if migrated else "保存データを読み込みました。"
		alert = migrated
		return meta
	migrated = false
	meta = _progress(path + ".bak") if FileAccess.file_exists(path + ".bak") else null
	if meta != null:
		message = "前回のバックアップから復元しました。最新の進行とは異なる場合があります。"
		alert = true
		return meta
	migrated = false
	blocked = FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
	message = "保存データを読めません。元ファイルを保護し、保存を停止しています。" if blocked else "新規開始。ランの途中の状態は保存されません。"
	alert = blocked
	return MetaProgress.new()


func save_progress(meta: MetaProgress) -> bool:
	if blocked:
		message = "保存停止中：既存データを読み込めません。元ファイルは保持されています。"
		alert = true
		return false
	var data := MetaCodec.encode(meta)
	if MetaCodec.decode(data) == null:
		message = "保存失敗：進行データが保存形式に適合しません。"
		alert = true
		return false
	# The turn-based game's save is kept as it was, once.
	if migrated and FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".v4"):
		if DirAccess.copy_absolute(path, path + ".v4") != OK:
			return _failed("以前の保存データを残せません")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failed("一時ファイルを作成できません")
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or MetaCodec.decode(_read(temporary)) == null:
		return _failed("書き込みを検証できません")
	if FileAccess.file_exists(path):
		if _progress(path) != null:
			if DirAccess.copy_absolute(path, path + ".bak.tmp") != OK or _progress(path + ".bak.tmp") == null:
				return _failed("バックアップを作成できません")
			if DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak") != OK:
				return _failed("バックアップを確定できません")
		else:
			# Preserve unreadable data before replacement, including unknown versions.
			var archive := path + ".unreadable-" + str(Time.get_ticks_usec())
			while FileAccess.file_exists(archive):
				archive += "-copy"
			if DirAccess.copy_absolute(path, archive) != OK:
				return _failed("読めない元データを退避できません")
	if DirAccess.rename_absolute(temporary, path) != OK:
		return _failed("保存ファイルを確定できません")
	migrated = false
	message = "保存済み。ランの途中で終了すると、最後に保存した拠点の状態に戻ります。"
	alert = false
	return true


func _failed(reason: String) -> bool:
	message = "保存失敗：%s。直前の保存データは保持されています。" % reason
	alert = true
	return false
