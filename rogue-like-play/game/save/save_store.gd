class_name SaveStore
extends RefCounted

var path := "user://progress.json"
var message := ""
var blocked := false
const MAX_BYTES := 65536


func _read(file_path: String) -> RunCarryover:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return SaveCodec.decode(json.data)


func load_state() -> RunCarryover:
	blocked = false
	var state := _read(path) if FileAccess.file_exists(path) else null
	if state != null:
		message = "保存データを読み込みました。"
		return state
	state = _read(path + ".bak") if FileAccess.file_exists(path + ".bak") else null
	if state != null:
		message = "前回のバックアップから復元しました。最新の進行とは異なる場合があります。"
		return state
	blocked = FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
	message = "保存データを読めません。元ファイルを保護し、保存を停止しています。" if blocked else "新規開始。冒険途中の状態は保存されません。"
	return RunCarryover.new()


func save_state(state: RunCarryover) -> bool:
	if blocked:
		message = "保存停止中：既存データを読み込めません。元ファイルは保持されています。"
		return false
	var data := SaveCodec.encode(state)
	if SaveCodec.decode(data) == null:
		message = "保存失敗：所持データが保存形式に適合しません。"
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failed("一時ファイルを作成できません")
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or _read(temporary) == null:
		return _failed("書き込みを検証できません")
	if FileAccess.file_exists(path):
		if _read(path) != null:
			if DirAccess.copy_absolute(path, path + ".bak.tmp") != OK or _read(path + ".bak.tmp") == null:
				return _failed("バックアップを作成できません")
			if DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak") != OK:
				return _failed("バックアップを確定できません")
		else:
			# Preserve invalid data before replacement, including unknown versions.
			var archive := path + ".unreadable-" + str(Time.get_ticks_usec())
			while FileAccess.file_exists(archive):
				archive += "-copy"
			if DirAccess.copy_absolute(path, archive) != OK:
				return _failed("読めない元データを退避できません")
	if DirAccess.rename_absolute(temporary, path) != OK:
		return _failed("保存ファイルを確定できません")
	message = "保存済み。冒険途中で終了すると最後に保存した拠点状態に戻ります。"
	return true


func _failed(reason: String) -> bool:
	message = "保存失敗：%s。直前の保存データは保持されています。" % reason
	return false
