class_name EndingView
extends CanvasLayer

# The ending, played once after the first clear of the last chapter, as
# small games commonly end: three stills, each with a line or two over a
# darkened foot, moved on with Enter (A) or a click; then the staff roll
# with the works the game uses and their licences, rising up the screen,
# and a last word of thanks. Holding Esc (B) fills a ring and, once full,
# skips the rest, so a stray press never does. `finished` follows the end
# or the skip, once; Main then brings the player home.

signal finished

# [picture, line] for each still.
const SCENES := [
	["res://art/hub/ending/ending_1.png", "残響の主が崩れると、深淵に溜まっていた声が、ひとつずつほどけていった。"],
	["res://art/hub/ending/ending_2.png", "ダンジョンに縛られていた者たちの残響は、\nようやく行き場を見つけて、静かに眠りについた。"],
	["res://art/hub/ending/ending_3.png", "ミオは地上へ戻り、朝の光の中で、一度だけ振り返った。"],
]
# The staff roll: [role, text], role a Theme type variation; "" is a gap.
const CREDITS := [
	["TitleLabel", "Dungeon Remnant"],
	["", ""],
	["MutedLabel", "制作"],
	["HeadingLabel", "Termnix-IT"],
	["", ""],
	["MutedLabel", "音楽"],
	["BodyLabel", "Medieval: Exploration　RandomMind"],
	["BodyLabel", "Battle Theme A　cynicmusic"],
	["BodyLabel", "Epic Boss Battle　Juhani Junkala（SubspaceAudio）"],
	["MutedLabel", "CC0 1.0"],
	["", ""],
	["MutedLabel", "効果音"],
	["BodyLabel", "RPG sound pack　artisticdude"],
	["BodyLabel", "80 CC0 RPG SFX　rubberduck"],
	["BodyLabel", "Impact Sounds・Music Jingles・Interface Sounds　Kenney"],
	["MutedLabel", "CC0 1.0"],
	["", ""],
	["MutedLabel", "書体"],
	["BodyLabel", "しっぽり明朝　The Shippori Mincho Project Authors"],
	["BodyLabel", "BIZ UDPゴシック　The BIZ UDGothic Project Authors"],
	["MutedLabel", "SIL Open Font License 1.1"],
	["", ""],
	["MutedLabel", "ゲームエンジン"],
	["BodyLabel", "Godot Engine　Godot Engine contributors, Juan Linietsky, Ariel Manzur"],
	["MutedLabel", "MIT License"],
	["BodyLabel", "Godot Engine のロゴ　Andrea Calabró"],
	["MutedLabel", "CC BY 4.0"],
	["", ""],
	["MutedLabel", "ライセンスの全文は、ゲームに同梱の THIRD_PARTY_NOTICES.md にあります。"],
]
const THANKS := "遊んでくれて、ありがとう。"
# A still's picture fades in over this; its line follows a beat later, and
# the press that moves on is taken only once both are up.
const STILL_TIME := 0.9
const LINE_DELAY := 0.6
# How fast the roll rises, and how long the thanks stays before it ends.
const ROLL_SPEED := 70.0
const THANKS_TIME := 3.5
# How long Esc (B) is held to skip, and the ring that shows it.
const HOLD_TIME := 1.0
const RING_RADIUS := 18.0

var scene := -1
var rolling := false
var done := false
var art: TextureRect
var line: Label
var roll: VBoxContainer
var thanks: Label
var _root: Control
var _ring: Control
var _ready_at := 0.0
var _hold := 0.0
var _roll_tween: Tween


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = preload("res://ui/theme/dungeon_theme.tres")
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The line sits on a foot of the picture darkened towards the bottom.
	var fade := Gradient.new()
	fade.set_color(0, Color(0, 0, 0, 0))
	fade.set_color(1, Color(0, 0, 0, 0.85))
	var foot := GradientTexture2D.new()
	foot.gradient = fade
	foot.fill_from = Vector2(0.5, 0)
	foot.fill_to = Vector2(0.5, 1)
	var veil := TextureRect.new()
	veil.texture = foot
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)
	veil.anchor_top = 0.62
	veil.anchor_right = 1.0
	veil.anchor_bottom = 1.0
	line = HubUI.label(_root, "", &"HeadingLabel")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.anchor_top = 0.8
	line.anchor_right = 1.0
	line.anchor_bottom = 0.95
	line.offset_left = 80
	line.offset_right = -80
	roll = VBoxContainer.new()
	roll.alignment = BoxContainer.ALIGNMENT_CENTER
	roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(roll)
	# Each entry is one line, so the roll is as wide as its longest.
	for entry: Array in CREDITS:
		var item := HubUI.label(roll, entry[1], entry[0] if not String(entry[0]).is_empty() else &"BodyLabel")
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.autowrap_mode = TextServer.AUTOWRAP_OFF
	roll.hide()
	thanks = HubUI.label(_root, THANKS, &"TitleLabel")
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thanks.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thanks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thanks.hide()
	# The skip: a ring that fills while Esc (B) is held, and what it does.
	var corner := HBoxContainer.new()
	corner.theme_type_variation = &"CompactRow"
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(corner)
	corner.anchor_left = 1.0
	corner.anchor_top = 1.0
	corner.anchor_right = 1.0
	corner.anchor_bottom = 1.0
	corner.offset_left = -260
	corner.offset_top = -64
	corner.offset_right = -40
	corner.offset_bottom = -24
	corner.alignment = BoxContainer.ALIGNMENT_END
	_ring = Control.new()
	_ring.custom_minimum_size = Vector2.ONE * RING_RADIUS * 2.0 + Vector2(4, 4)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	corner.add_child(_ring)
	var hint := HubUI.label(corner, "Esc（B）を長押しで飛ばす", &"MutedLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hide()


func play() -> void:
	done = false
	_hold = 0.0
	show()
	GameMusic.cue(self, &"hub")
	_show_scene(0)


func _show_scene(index: int) -> void:
	scene = index
	art.texture = load(SCENES[index][0]) if ResourceLoader.exists(SCENES[index][0]) else null
	line.text = SCENES[index][1]
	UIMotion.of(art).appear(0.0, STILL_TIME)
	UIMotion.of(line).appear(LINE_DELAY, STILL_TIME)
	_ready_at = _now() + LINE_DELAY + STILL_TIME * 0.5


# Enter (A) or a click: the next still, or from the last one the roll.
func advance() -> void:
	if done or rolling or _now() < _ready_at:
		return
	if scene < SCENES.size() - 1:
		_show_scene(scene + 1)
	else:
		_start_roll()


func _start_roll() -> void:
	rolling = true
	art.hide()
	line.hide()
	roll.show()
	# Its lines measure themselves once shown, so it rises from the next frame.
	await get_tree().process_frame
	if done:
		return
	roll.reset_size()
	var screen := _root.size
	roll.position = Vector2((screen.x - roll.size.x) * 0.5, screen.y)
	var travel := screen.y + roll.size.y
	_roll_tween = create_tween()
	_roll_tween.tween_property(roll, "position:y", -roll.size.y, travel / ROLL_SPEED)
	_roll_tween.tween_callback(_thank)


func _thank() -> void:
	roll.hide()
	thanks.show()
	UIMotion.of(thanks).appear(0.0, STILL_TIME)
	get_tree().create_timer(THANKS_TIME, true, false, true).timeout.connect(finish)


# Ends the ending, once: the rest is skipped if it is still under way.
func finish() -> void:
	if done:
		return
	done = true
	if _roll_tween != null:
		_roll_tween.kill()
	hide()
	finished.emit()


func _process(delta: float) -> void:
	if not visible or done:
		return
	var held := Input.is_action_pressed(&"ui_cancel")
	var before := _hold
	_hold = minf(HOLD_TIME, _hold + delta) if held else 0.0
	if _hold != before:
		_ring.queue_redraw()
	if _hold >= HOLD_TIME:
		finish()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or done:
		return
	var press: bool = (event.is_action_pressed(&"ui_accept") and not event.is_echo()) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if press:
		get_viewport().set_input_as_handled()
		advance()


func _draw_ring() -> void:
	var middle := _ring.size * 0.5
	var rail := _ring.get_theme_color(&"rail", &"HubLobby")
	_ring.draw_arc(middle, RING_RADIUS, 0.0, TAU, 40, Color(rail, 0.25), 2.0, true)
	if _hold > 0.0:
		_ring.draw_arc(middle, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * _hold / HOLD_TIME, 40, rail, 3.0, true)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
