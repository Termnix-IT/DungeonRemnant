extends Node

# The game: the base (Hub) and, while one lasts, a run (RunDirector). It owns
# the lasting progress (MetaProgress) and its store: a purchase at the base
# is saved before it is shown, and rolled back if the save fails; a run is
# shaped by the progress at its start and hands its result back at its end,
# which is recorded and saved before the result screen offers the way home.
# The way home after the last chapter's first clear plays the ending first.

@export var run_scene: PackedScene = preload("res://game/expedition/run_director.tscn")
@export var saving_enabled := true
# Zero leaves every run random. Tests set it so a run lays out the same
# route and offers the same boons each time.
@export var run_seed := 0
const HUB_SCENE := preload("res://game/hub/hub.tscn")
var store := MetaStore.new()
var meta := MetaProgress.new()
var active_run: RunDirector
var transition: SceneTransition
# The ending is owed: the run just recorded was the last chapter's first
# clear, so the way home plays it first (EndingView).
var ending_due := false
var ending_view: EndingView
# The prologue: the stills played before the first run ever sets out (no run
# recorded yet), once in a sitting. Tests that start runs turn it off.
@export var show_prologue := true
var prologue_view: EndingView
var _prologue_played := false
var _loaded := false


func _ready() -> void:
	preload("res://combat/strike_effect.gd").warm()
	# Script-only instances in rule tests have no hub.
	if not has_node("Hub"):
		return
	$Hub.settings.apply_volume()
	$Hub.settings.apply_display()
	transition = SceneTransition.new()
	add_child(transition)
	var music := GameMusic.new()
	music.name = "Music"
	add_child(music)
	# The interface's small sounds: a focus moving anywhere on screen.
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_hook_hub()
	_update_save_status()


# The saves are read, and the language set, before the hub writes its words
# in its _ready, which runs before this node's.
func _load_saves() -> void:
	if _loaded or not has_node("Hub"):
		return
	_loaded = true
	if saving_enabled:
		# Only the real save is brought over from the old folder; a test's
		# store points elsewhere and must not touch the player's files.
		if store.path == MetaStore.DEFAULT_PATH:
			SaveFolderMove.carry_over(SaveFolderMove.old_folder(), OS.get_user_data_dir())
		meta = store.load_progress()
		$Hub.settings.load_settings()
		# Tests keep the language they were started in (run_tests.py: Japanese).
		$Hub.settings.apply_language()


func _hook_hub() -> void:
	$Hub.settings_changed.connect(func():
		if saving_enabled:
			$Hub.settings.save_settings())
	$Hub.language_changed.connect(_change_language, CONNECT_DEFERRED)
	$Hub.start_requested.connect(start_run)
	$Hub.upgrade_requested.connect(buy_upgrade)
	$Hub.equip_requested.connect(equip_skill)
	$Hub.refresh(meta)


# The hub's pages write their words once, as they are built: another
# language builds the hub anew, opened where the old one was, on the
# language's row. Deferred, so the row that asked is not freed under its
# own signal.
func _change_language() -> void:
	var old: Node = $Hub
	var settings: GameSettings = old.settings
	settings.apply_language()
	if saving_enabled:
		settings.save_settings()
	var hub: Node = HUB_SCENE.instantiate()
	hub.settings = settings
	hub.chapter = old.chapter
	hub.step = old.step
	remove_child(old)
	old.queue_free()
	hub.name = "Hub"
	add_child(hub)
	move_child(hub, 0)
	_hook_hub()
	_update_save_status()
	hub.open_language()


# A skill set in a slot (or the slot cleared), kept only once it is saved.
func equip_skill(slot: int, id: StringName) -> bool:
	if active_run != null or not has_node("Hub") or not $Hub.visible:
		return false
	var loadout := meta.loadout.duplicate()
	var special := meta.special
	var weapon := meta.weapon
	if not meta.equip(slot, id):
		$Hub.refresh(meta, tr("このスキルは付けられません。"))
		return false
	if saving_enabled and not store.save_progress(meta):
		meta.loadout = loadout
		meta.special = special
		meta.weapon = weapon
		$Hub.refresh(meta, tr("保存に失敗したため、付け替えを取り消しました。"))
		_update_save_status()
		return false
	if slot == MetaProgress.WEAPON_SLOT:
		$Hub.refresh(meta, tr("武器を「%s」に持ち替えました。") % tr(MetaProgress.find_weapon(id).display_name))
		_update_save_status()
		$Hub.present_equip()
		return true
	if slot == MetaProgress.SPECIAL_SLOT:
		var move := MetaProgress.find_special(id)
		$Hub.refresh(meta, tr("必殺技に「%s」を付けました。") % tr(move.display_name) if move != null else tr("必殺技を外しました。"))
		_update_save_status()
		$Hub.present_equip()
		return true
	var skill := MetaProgress.find_skill(id)
	$Hub.refresh(meta, tr("スキル%dに「%s」を付けました。") % [slot + 1, tr(skill.display_name)] if skill != null else tr("スキル%dを外しました。") % (slot + 1))
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
		$Hub.refresh(meta, tr("強化できません。残響と強化の上限を確認してください。"))
		return false
	if saving_enabled and not store.save_progress(meta):
		meta.echo = echo
		meta.ranks = ranks
		$Hub.refresh(meta, tr("保存に失敗したため、強化を取り消しました。"))
		_update_save_status()
		return false
	$Hub.refresh(meta, tr("「%s」を強化しました。") % tr(MetaProgress.find(id).display_name))
	_update_save_status()
	$Hub.present_action(id, meta.echo - echo)
	return true


# Whether the next setting out is the first ever, the prologue still unseen.
func prologue_due() -> bool:
	return show_prologue and not _prologue_played and meta.runs == 0


func start_run() -> void:
	if active_run != null or not has_node("Hub") or not $Hub.visible or not meta.chapter_open($Hub.chapter):
		return
	if prologue_view != null and prologue_view.visible:
		return
	if prologue_due():
		_prologue_played = true
		prologue_view = EndingView.new()
		prologue_view.scenes = EndingView.PROLOGUE
		prologue_view.rolls = false
		add_child(prologue_view)
		prologue_view.finished.connect(start_run)
		prologue_view.play()
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
	active_run.chapter = $Hub.chapter
	active_run.step = clampi($Hub.step, 0, meta.steps_open())
	active_run.settings_changed.connect(func():
		if saving_enabled:
			$Hub.settings.save_settings())
	active_run.finished.connect(_on_run_finished)
	active_run.base_requested.connect(return_to_hub)
	add_child(active_run)
	# The run is already live underneath; the cover only eases the cut.
	transition.play_departure(active_run.chapter)


# The run's end, recorded and saved before its result offers the way home.
# The first clear of the last chapter is the ending: it opens the difficulty
# steps; clearing it at the highest step open opens the next.
func _on_run_finished(result: Dictionary) -> void:
	var ending_before := meta.ending_seen()
	var open_before := meta.steps_open()
	meta.record_run(result)
	if not ending_before and meta.ending_seen():
		active_run.end_view.tell_opened(tr("難易度の段階が開いた"))
		ending_due = true
	elif meta.steps_open() > open_before:
		active_run.end_view.tell_opened(tr("段階%dが開いた") % meta.steps_open())
	if saving_enabled:
		store.save_progress(meta)
		active_run.end_view.show_save_status(store.message, store.alert)
	else:
		active_run.end_view.show_save_status(tr("テストモード：保存は無効です。"), false)


func return_to_hub() -> void:
	if active_run == null or active_run.result.is_empty():
		return
	var finished := active_run
	active_run = null
	remove_child(finished)
	finished.queue_free()
	get_tree().paused = false
	if ending_due:
		ending_due = false
		if ending_view == null:
			ending_view = EndingView.new()
			add_child(ending_view)
			ending_view.finished.connect(_arrive_home.bind(true))
		ending_view.play()
		return
	_arrive_home(false)


# Home to the lobby; after the ending, the steps it opened are named.
func _arrive_home(after_ending: bool) -> void:
	$Hub.refresh(meta)
	$Hub.show()
	$Hub.show_page("home")
	_update_save_status()
	if after_ending:
		transition.play_return(tr("旅支度の間"), tr("難易度の段階が開いた。出撃の画面で選べる。"))
	else:
		transition.play_return(tr("旅支度の間"), tr("残響と強化は次の探索へ引き継がれます。"))


func _update_save_status() -> void:
	if saving_enabled:
		$Hub.show_save_status(store.message, store.alert)
	else:
		$Hub.show_save_status(tr("テストモード：保存は無効です。"), false)


func _enter_tree() -> void:
	# Every word is translated where it is written (tr()), so the controls do
	# not translate their text again by themselves.
	get_tree().root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_load_saves()
	# Route controller UI navigation through the same native focus/press
	# signals; the fight's own actions are in project.godot's InputMap.
	var ui_buttons := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B, "ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT}
	for action: String in ui_buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = ui_buttons[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
