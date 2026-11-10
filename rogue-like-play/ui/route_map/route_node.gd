class_name RouteNode
extends Button

# One area on the route map, drawn as a stage: an oval platform of the
# chapter's ground seen a little from above, with what waits there standing
# on it, the way a diorama map shows its places. On a fight's stage its
# leading foe (the boss, the field's elite, the arena's last wave's first)
# stands in its fight's rig facing her, braced to strike, with one of its
# company smaller behind; an event's stage holds its object (the altar, the
# merchant's cart...). Under the stage's front edge a small badge shows what
# clearing it gives (a boon's light, a heart, an echo coin) and under that
# its difficulty as stars; the map's card tells the rest. A stage she has
# cleared stands empty.
# Open (where the paths from her lead now) it is bright and takes focus;
# taken, it keeps a gold rim; still ahead, it is dimmed; passed by or out of
# her reach, dimmed further and its figures stand still. The selected stage
# wears the gold rim and a soft glow round it, the focused one a light edge.
# The boss's stage is larger and breathes a red glow; until her way reaches
# it the boss is veiled, a dark shape on a dark stage, and reveal() brings
# it out.
# Its origin is the button's corner; ground() is where the figures stand
# and the roads meet it, the middle of the stage's top.

# The stage's width, the boss's larger, and the room kept above the ground
# for the figures.
const PLATE_WIDTH := 190.0
const BOSS_SCALE := 1.15
const FIGURE_ROOM := 170.0
# Where the top's middle lies down the stage picture, and the top's half
# height and half width, as shares of the picture (measured by
# `python tools/build_route_stages.py --measure`).
const PLATE_TOP := 0.37
const TOP_HALF_HEIGHT := 0.35
const TOP_HALF_WIDTH := 0.48
# Figures stand this many times their fight height (64 world px for most),
# no taller than FIGURE_TALLEST (the boss's BOSS_TALLEST); the one behind at
# COMPANY_SCALE of that, up and to the right.
const FIGURE_SCALE := 1.7
const FIGURE_TALLEST := 150.0
const BOSS_TALLEST := 200.0
const COMPANY_SCALE := 0.72
const COMPANY_PLACE := Vector2(0.24, -0.1)
const FIGURE_PLACE := Vector2(-0.08, 0.05)
# An event's object, this tall, standing at the ground.
const PROP_HEIGHT := 128.0
const BADGE := 44.0
const CAPTION_HEIGHT := 26.0
const BACK := Color(0.05, 0.055, 0.065, 0.96)
const EDGE := Color(0.32, 0.32, 0.31)
const GOLD := Color("d6b77b")
const FOCUS := Color(0.94, 0.92, 0.86)
const GLOW := Color(1.0, 0.82, 0.48, 0.3)
# The emblem showing each reward.
const REWARD_EMBLEMS := {AreaData.Reward.BOON: "attack", AreaData.Reward.HEAL: "max_hp"}
const PASSED := Color(1, 1, 1, 0.32)
const AHEAD := Color(1, 1, 1, 0.62)
# The boss's glow and how long one breath takes; veiled, its figure is this
# dark and its stage this dim.
const BOSS_GLOW := Color(0.72, 0.16, 0.12, 0.32)
const BOSS_BEAT := 1.8
const VEIL := Color(0.04, 0.035, 0.05)
const VEIL_PLATE := Color(0.42, 0.4, 0.44)
# The chapter's stage, and each event's object (built by
# tools/build_route_stages.py).
const PLATES := "res://art/ui/route/plate_%s.png"
const PROPS := "res://art/ui/route/prop_%s.png"

enum Mark { OPEN, TAKEN, PASSED, AHEAD }

var waypoint: RouteMap.Waypoint
var mark := Mark.OPEN
var selected := false:
	set(value):
		selected = value
		queue_redraw()
# Veiled: the boss still hidden in the dark.
var veiled := false
var plate: Texture2D
var figure: Node2D
var _icon: Texture2D
var _caption: Label
var _width := PLATE_WIDTH
var _veil := 0.0


# The chapter's stage picture, or null when it has none.
static func plate_for(chapter: StringName) -> Texture2D:
	var path := PLATES % chapter
	return load(path) if ResourceLoader.exists(path) else null


# An event's object, or the start's signpost (`sign`).
static func prop_for(id: StringName) -> Texture2D:
	var path := PROPS % id
	return load(path) if ResourceLoader.exists(path) else null


# The foe standing at the front of an area's stage, so the kind of fight
# reads at a glance: the boss; a field's horde by the kind met most; an
# arena by its last wave's first, the one the waves build up to. Every fight
# of a chapter shares its elite, so a field showing it would make them all
# look alike.
static func leader(area: AreaData) -> FoeData:
	if area.boss != null:
		return area.boss
	if area.spawn_table != null:
		var kinds := _by_weight(area.spawn_table)
		return kinds[0] if not kinds.is_empty() else area.spawn_table.elite
	for index in range(area.waves.size() - 1, -1, -1):
		if not area.waves[index].foes.is_empty():
			return area.waves[index].foes[0]
	return null


# The one standing behind it: a field's next most met kind, else the first
# other kind it comes with.
static func company(area: AreaData) -> FoeData:
	var first := leader(area)
	if area.boss != null or first == null:
		return null
	var kinds: Array[FoeData] = []
	if area.spawn_table != null:
		kinds = _by_weight(area.spawn_table)
	for wave in area.waves:
		kinds.append_array(wave.foes)
	for kind in kinds:
		if kind != null and kind != first:
			return kind
	return null


# A field's kinds, the most met first (a tie keeps the table's order).
static func _by_weight(table: SpawnTable) -> Array[FoeData]:
	var entries := table.entries.filter(func(entry: SpawnEntry) -> bool: return entry != null and entry.foe != null)
	var order := range(entries.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return entries[a].weight > entries[b].weight or (entries[a].weight == entries[b].weight and a < b))
	var kinds: Array[FoeData] = []
	for index in order:
		kinds.append(entries[index].foe)
	return kinds


# How a stage of this width lies: the picture's height and the ground.
static func plate_height(texture: Texture2D, width: float) -> float:
	if texture == null:
		return width * 0.5
	return width * texture.get_height() / texture.get_width()


func setup(point: RouteMap.Waypoint, state: Mark, stage: Texture2D = null, hidden: bool = false) -> void:
	waypoint = point
	mark = state
	plate = stage
	veiled = hidden
	_veil = 1.0 if hidden else 0.0
	theme_type_variation = &"RouteNode"
	text = ""
	var boss := point.area.boss != null
	_width = PLATE_WIDTH * (BOSS_SCALE if boss else 1.0)
	var high := plate_height(plate, _width)
	custom_minimum_size = Vector2(_width, FIGURE_ROOM * (BOSS_SCALE if boss else 1.0) + high * (1.0 - PLATE_TOP) + CAPTION_HEIGHT)
	size = custom_minimum_size
	if point.area.is_event():
		_icon = null
	elif not boss:
		_icon = EmblemIcons.texture(REWARD_EMBLEMS.get(point.reward, ""))
	focus_mode = Control.FOCUS_ALL if state == Mark.OPEN else Control.FOCUS_NONE
	modulate = {Mark.OPEN: Color.WHITE, Mark.TAKEN: Color.WHITE, Mark.PASSED: PASSED, Mark.AHEAD: AHEAD}[state]
	_caption = Label.new()
	_caption.theme_type_variation = &"MutedLabel" if state != Mark.OPEN else &"BodyLabel"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The boss needs no stars under it: its size, glow and place say it; an
	# event has none.
	_caption.text = "" if boss else point.area.stars()
	add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.offset_top = -CAPTION_HEIGHT
	_caption.offset_bottom = 0
	_stand(state)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	set_process(boss)


# What stands on the stage: nothing once cleared, an event's object, or the
# foes, facing her (left) and braced.
func _stand(state: Mark) -> void:
	figure = Node2D.new()
	figure.position = ground()
	add_child(figure)
	var area := waypoint.area
	if state == Mark.TAKEN:
		return
	if area.is_event():
		var texture := prop_for(area.event)
		if texture != null:
			var prop := Sprite2D.new()
			prop.texture = texture
			prop.centered = false
			prop.scale = Vector2.ONE * PROP_HEIGHT / texture.get_height()
			prop.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
			prop.position = Vector2(0.0, _top_half() * 0.3)
			figure.add_child(prop)
		return
	var boss := area.boss != null
	var behind := company(area)
	if behind != null:
		_foe(behind, COMPANY_SCALE, Vector2(COMPANY_PLACE.x * _width, COMPANY_PLACE.y * plate_height(plate, _width)), false)
	var front := leader(area)
	if front != null:
		_foe(front, 1.0, Vector2(FIGURE_PLACE.x * _width, FIGURE_PLACE.y * plate_height(plate, _width)), boss)
	# Passed by or out of reach, they stand still.
	if state == Mark.PASSED:
		figure.process_mode = Node.PROCESS_MODE_DISABLED
	_apply_veil()


func _foe(foe: FoeData, share: float, at: Vector2, boss: bool) -> void:
	var holder := foe_figure(foe, BOSS_TALLEST if boss else FIGURE_TALLEST, share)
	holder.position = at
	figure.add_child(holder)


# A foe standing braced and facing her (on the left; the fight draws them
# facing right), `grow` times its size in the fight but no taller than
# `tallest`, then `share` of that: its rig, else its picture.
static func foe_figure(foe: FoeData, tallest: float, share: float = 1.0, grow: float = FIGURE_SCALE) -> Node2D:
	var holder := Node2D.new()
	holder.scale = Vector2(-1.0, 1.0)
	var path := EnemySprites.rig_path(foe.visual_id)
	if ResourceLoader.exists(path):
		var rig: CharacterRig = (load(path) as PackedScene).instantiate()
		var fight := float(rig.get_meta(&"world_height", 64.0)) * foe.size_scale
		rig.world_height = minf(fight * grow, tallest) * share
		rig.modulate = foe.tint
		holder.add_child(rig)
		# Its stance is played once the rig is ready to play it.
		if rig.is_node_ready():
			rig.braced = true
		else:
			rig.ready.connect(func(): rig.braced = true, CONNECT_ONE_SHOT)
		return holder
	var picture := HubCodex.tile_picture(foe.visual_id, true, foe.tint)
	if picture != null:
		var sprite := Sprite2D.new()
		sprite.texture = picture
		sprite.centered = false
		sprite.offset = Vector2(-picture.get_width() * 0.5, -picture.get_height())
		sprite.scale = Vector2.ONE * tallest * 0.7 * share / picture.get_height()
		holder.add_child(sprite)
	return holder


# Where the figures stand and the roads meet: the middle of the stage's top.
func ground() -> Vector2:
	return Vector2(_width * 0.5, FIGURE_ROOM * (BOSS_SCALE if _is_boss() else 1.0))


func _is_boss() -> bool:
	return waypoint != null and waypoint.area.boss != null


func _plate_rect() -> Rect2:
	var high := plate_height(plate, _width)
	return Rect2(Vector2(0.0, ground().y - high * PLATE_TOP), Vector2(_width, high))


func _top_half() -> float:
	return plate_height(plate, _width) * TOP_HALF_HEIGHT


# The boss coming out of the dark: its figure and stage lighten over
# `time` seconds.
func reveal(time: float) -> Tween:
	veiled = false
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_method(func(value: float):
		_veil = value
		_apply_veil(), 1.0, 0.0, time)
	return tween


# Out of the dark at once (the coming out cut short).
func unveil() -> void:
	veiled = false
	_veil = 0.0
	_apply_veil()


func _apply_veil() -> void:
	if figure != null:
		figure.modulate = Color.WHITE.lerp(VEIL, _veil)
	queue_redraw()


# Only the stage and its figures take the pointer, not the room above them.
func _has_point(point: Vector2) -> bool:
	var rect := _plate_rect()
	var middle := rect.get_center()
	var reach := (point - middle) / (rect.size * 0.5)
	if reach.length() <= 1.0:
		return true
	var feet := ground()
	return absf(point.x - feet.x) <= _width * 0.28 and point.y >= feet.y - FIGURE_ROOM * 0.85 and point.y <= feet.y


# The boss's stage breathes a red glow, slow, like a heartbeat ahead.
func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := _plate_rect()
	var feet := ground()
	var top := Vector2(_width * TOP_HALF_WIDTH, _top_half())
	if _is_boss():
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / BOSS_BEAT)
		var glow := Color(BOSS_GLOW, BOSS_GLOW.a * (0.35 + 0.65 * beat) * (1.0 - _veil * 0.6))
		_ellipse(feet + Vector2(0.0, rect.size.y * 0.12), top * (1.25 + beat * 0.08), glow)
	if selected:
		_ellipse(feet + Vector2(0.0, rect.size.y * 0.1), top * 1.22, GLOW)
	var shade := Color.WHITE.lerp(VEIL_PLATE, _veil)
	if plate != null:
		draw_texture_rect(plate, rect, false, shade)
	else:
		_ellipse(feet, top, BACK * shade)
	var gold_rim := selected or mark == Mark.TAKEN
	var edge := GOLD if gold_rim else EDGE
	if mark == Mark.OPEN and is_hovered() and not gold_rim:
		edge = GOLD.darkened(0.25)
	if gold_rim or (mark == Mark.OPEN and is_hovered()):
		_ring(feet, top, edge, 3.0)
	if has_focus():
		_ring(feet, top + Vector2(7.0, 5.0), FOCUS, 1.5)
	if _icon != null or (waypoint != null and waypoint.reward == AreaData.Reward.ECHO and not waypoint.area.is_event() and not _is_boss()):
		var badge := Vector2(feet.x, rect.end.y - BADGE * 0.35)
		draw_circle(badge, BADGE * 0.5, BACK)
		if _icon != null:
			draw_texture_rect(_icon, Rect2(badge - Vector2.ONE * BADGE * 0.43, Vector2.ONE * BADGE * 0.86), false)
		else:
			_draw_coin(badge, BADGE * 0.3)
		draw_arc(badge, BADGE * 0.5, 0.0, TAU, 40, GOLD if mark == Mark.OPEN else EDGE, 2.0, true)


func _ellipse_points(center: Vector2, radii: Vector2, count: int = 48) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in count:
		var angle := TAU * step / count
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(center, radii), color)


func _ring(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := _ellipse_points(center, radii)
	points.append(points[0])
	draw_polyline(points, color, width, true)


# The echo's coin, as the hub's purse draws it.
func _draw_coin(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, GOLD.darkened(0.45))
	draw_circle(center, radius - 2.0, GOLD)
	draw_arc(center, radius - 5.0, 0, TAU, 32, GOLD.darkened(0.35), 1.5, true)
	draw_circle(center + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.18, Color(1, 1, 1, 0.45))
