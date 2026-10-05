class_name HeroStats
extends Control

# The right of the hub's screens: the heroine from the knees up, cut by the
# page's foot and the screen's right edge (the lobby shows her whole), with
# her next run's stats laid over her legs. show() gives them before and
# after a change, the changed ones in green or red with an arrow.

# Her height in screen pixels, the share of it from the texture's top down to
# her knees, and where her face sits across.
const HERO_HEIGHT := 960.0
const HERO_KNEES := 0.72
const HERO_FACE_X := 0.4
# The page leaves this much of the screen on its right.
const SCREEN_MARGIN := 80.0
const STATS := [["hp", "最大HP"], ["attack", "攻撃力"], ["defense", "防御力"], ["reach", "射程"]]

var hero: LobbyHero
var specs: StatBars
var swap_label: Label
var _frame: Control
var _band: PanelContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_frame = Control.new()
	_frame.clip_contents = true
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	hero = LobbyHero.new()
	hero.texture = HubLobby.HERO_TEXTURE
	hero.modulate = get_theme_color(&"hero_tint", &"HubLobby")
	_frame.add_child(hero)
	resized.connect(_place)
	_band = PanelContainer.new()
	_band.theme_type_variation = &"ShopHeroBand"
	add_child(_band)
	_band.anchor_right = 1.0
	_band.anchor_top = 1.0
	_band.anchor_bottom = 1.0
	_band.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"CompactStack"
	_band.add_child(stack)
	HubUI.label(stack, "次の冒険の能力", &"NoteLabel")
	swap_label = HubUI.label(stack, "", &"NoteLabel")
	specs = StatBars.new()
	stack.add_child(specs)


func _place() -> void:
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(size.x + SCREEN_MARGIN, size.y)
	var texture := hero.texture
	var width := HERO_HEIGHT * texture.get_width() / texture.get_height()
	hero.size = Vector2(width, HERO_HEIGHT)
	# Knees on the page's foot, her face over the middle of the column.
	hero.position = Vector2(size.x * 0.5 - width * HERO_FACE_X, size.y - HERO_HEIGHT * HERO_KNEES)
	hero.pivot_offset = Vector2(width * 0.5, HERO_HEIGHT)


# Opening a page: she steps in from the screen's right edge after delay,
# her stats a beat later.
func play_entrance(delay: float) -> void:
	UIMotion.of(_frame).enter(delay, Vector2(UIMotion.ENTER_DISTANCE * 2, 0), UIMotion.ENTER_TIME)
	UIMotion.of(_band).appear(delay + UIMotion.STAGGER_TIME)


# Her stats as they are, or before and after a change; swap names the slot
# and what she wears there now, or is empty.
func show_stats(before: Dictionary, after: Dictionary = {}, swap: String = "") -> void:
	swap_label.text = swap
	swap_label.visible = not swap.is_empty()
	var shown := []
	for stat: Array in STATS:
		var next: int = after.get(stat[0], before[stat[0]])
		# Bars leave room for the change against her current value.
		shown.append([stat[1], before[stat[0]], next, maxi(before[stat[0]], next) * 1.25 + 1])
	specs.show_rows(shown)


# The swap line for wearing goods in a slot.
static func swap_text(slot: int, current: ItemData) -> String:
	return "%sと入れ替え（今：%s）" % [Equipment.SLOT_NAMES[slot], current.label() if current != null else "なし"]
