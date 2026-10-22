extends Node

# The game: the base (Hub) and, while one lasts, a run (RunDirector). It owns
# the lasting progress (MetaProgress) and its store: a purchase at the base
# is saved before it is shown, and rolled back if the save fails; a run is
# shaped by the progress at its start and hands its result back at its end,
# which is recorded and saved before the result screen offers the way home.

@export var run_scene: PackedScene = preload("res://game/expedition/run_director.tscn")
@export var saving_enabled := true
# Zero leaves every run random. Tests set it so a run lays out the same
# route and offers the same boons each time.
@export var run_seed := 0
var store := MetaStore.new()
var meta := MetaProgress.new()
var active_run: RunDirector
var transition: SceneTransition


func _ready() -> void:
	preload("res://combat/strike_effect.gd").warm()
	# Script-only instances in rule tests have no hub.
	if not has_node("Hub"):
		return
	if saving_enabled:
		meta = store.load_progress()
		$Hub.settings.load_settings()
	$Hub.settings.apply_volume()
	$Hub.settings.apply_display()
	$Hub.settings_changed.connect(func():
		if saving_enabled:
			$Hub.settings.save_settings())
	transition = SceneTransition.new()
	add_child(transition)
	var music := GameMusic.new()
	music.name = "Music"
	add_child(music)
	# The interface's small sounds: a focus moving anywhere on screen.
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	$Hub.start_requested.connect(start_run)
	$Hub.upgrade_requested.connect(buy_upgrade)
	$Hub.equip_requested.connect(equip_skill)
	$Hub.refresh(meta)
	_update_save_status()


# A skill set in a slot (or the slot cleared), kept only once it is saved.
func equip_skill(slot: int, id: StringName) -> bool:
	if active_run != null or not has_node("Hub") or not $Hub.visible:
		return false
	var loadout := meta.loadout.duplicate()
	var special := meta.special
	if not meta.equip(slot, id):
		$Hub.refresh(meta, "このスキルは付けられません。")
		return false
	if saving_enabled and not store.save_progress(meta):
		meta.loadout = loadout
		meta.special = special
		$Hub.refresh(meta, "保存に失敗したため、付け替えを取り消しました。")
		_update_save_status()
		return false
	if slot == MetaProgress.SPECIAL_SLOT:
		var move := MetaProgress.find_special(id)
		$Hub.refresh(meta, "必殺技に「%s」を付けました。" % move.display_name if move != null else "必殺技を外しました。")
		_update_save_status()
		$Hub.present_equip()
		return true
	var skill := MetaProgress.find_skill(id)
	$Hub.refresh(meta, "スキル%dに「%s」を付けました。" % [slot + 1, skill.display_name] if skill != null else "スキル%dを外しました。" % (slot + 1))
	_update_save_status()
	$Hub.present_equip()
	return true


var _last_focus_sound := 0


# One soft tick per move of the focus, however fast the keys repeat.
func _on_focus_changed(_control: Control) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_focus_sound < 60:
		return
	_last_focus_sound = now
	GameAudio.play(self, &"ui_move", -24.0)


func buy_upgrade(id: StringName) -> bool:
	if active_run != null or not has_node("Hub") or not $Hub.visible:
		return false
	var echo := meta.echo
	var ranks := meta.ranks.duplicate()
	if not meta.buy(id):
		$Hub.refresh(meta, "強化できません。残響と強化の上限を確認してください。")
		return false
	if saving_enabled and not store.save_progress(meta):
		meta.echo = echo
		meta.ranks = ranks
		$Hub.refresh(meta, "保存に失敗したため、強化を取り消しました。")
		_update_save_status()
		return false
	$Hub.refresh(meta, "「%s」を強化しました。" % MetaProgress.find(id).display_name)
	_update_save_status()
	$Hub.present_action(id, meta.echo - echo)
	return true


func start_run() -> void:
	if active_run != null or not has_node("Hub") or not $Hub.visible:
		return
	if saving_enabled and not store.save_progress(meta):
		_update_save_status()
		return
	$Hub.hide()
	active_run = run_scene.instantiate()
	active_run.name = "Run"
	active_run.seed_value = run_seed
	active_run.meta = meta
	active_run.settings = $Hub.settings
	active_run.returns_to_base = true
	active_run.settings_changed.connect(func():
		if saving_enabled:
			$Hub.settings.save_settings())
	active_run.finished.connect(_on_run_finished)
	active_run.base_requested.connect(return_to_hub)
	add_child(active_run)
	# The run is already live underneath; the cover only eases the cut.
	transition.play_departure(active_run.chapter)


# The run's end, recorded and saved before its result offers the way home.
func _on_run_finished(result: Dictionary) -> void:
	meta.record_run(result)
	if saving_enabled:
		store.save_progress(meta)
		active_run.end_view.show_save_status(store.message, store.alert)
	else:
		active_run.end_view.show_save_status("テストモード：保存は無効です。", false)


func return_to_hub() -> void:
	if active_run == null or active_run.result.is_empty():
		return
	var finished := active_run
	active_run = null
	remove_child(finished)
	finished.queue_free()
	get_tree().paused = false
	$Hub.refresh(meta)
	$Hub.show()
	$Hub.show_page("home")
	_update_save_status()
	transition.play_return("旅支度の間", "残響と永続強化は次のランへ引き継がれます。")


func _update_save_status() -> void:
	if saving_enabled:
		$Hub.show_save_status(store.message, store.alert)
	else:
		$Hub.show_save_status("テストモード：保存は無効です。", false)


func _enter_tree() -> void:
	# Route controller UI navigation through the same native focus/press
	# signals; the fight's own actions are in project.godot's InputMap.
	var ui_buttons := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B, "ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT}
	for action: String in ui_buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = ui_buttons[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
