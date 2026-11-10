class_name RunJourney
extends Control

# The way a run went, drawn as the route map draws it, small: from the
# start's stage along the chapter's road to each stage she reached (the ones
# she cleared stand empty), then the rest of the way to the boss, faint. The
# stage where it ended tells how: she stands on the boss's (won), the foe
# that felled her stands braced on its own (fallen; the area's foe when no
# blow named one), or she stands where she turned back (left); a line under
# that stage says it in words.

const WIDTH := 1080.0
const HEIGHT := 172.0
# Where the stages' tops' middles stand, and the room at either end.
const LINE_Y := 112.0
const MARGIN := 72.0
const STAGE_WIDTH := 124.0
const START_SCALE := 0.8
const ROAD_WIDTH := 22.0
const AHEAD_ALPHA := 0.24
const HERO_HEIGHT := 84.0
const HERO_OFFSET := Vector2(-10.0, 2.0)
const FOE_TALLEST := 104.0
const FOE_GROW := 1.25
const SIGN_HEIGHT := 62.0
const SIGN_PLACE := Vector2(20.0, 2.0)
const CAPTION_GAP := 4.0

# Where each stage's top's middle stands: the start, then each layer.
var spots: Array[Vector2] = []
# The stage it ended on (an index into spots), and who stands there.
var ended_at := 0
var figure: Node2D
var caption: Label
var _scene: Node2D


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene = Node2D.new()
	add_child(_scene)
	caption = HubUI.label(self, "", &"BodyLabel")
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# The result's {cleared, abandoned, chapter_id, layers, path, fallen_to,
# moveset}.
func show_run(result: Dictionary) -> void:
	for child in _scene.get_children():
		child.free()
	figure = null
	caption.text = ""
	var won: bool = result.cleared
	var left: bool = result.get("abandoned", false)
	var path: Array = result.get("path", [])
	var layers := maxi(int(result.get("layers", path.size())), path.size())
	var chapter := StringName(result.get("chapter_id", ""))
	var stage := RouteNode.plate_for(chapter)
	spots.clear()
	for index in layers + 1:
		spots.append(Vector2(MARGIN + (WIDTH - MARGIN * 2.0) * index / layers, LINE_Y))
	ended_at = path.size()
	# The way walked, then the way she never reached, faint.
	var road := RouteMapView.road_for(chapter)
	var ahead := CanvasGroup.new()
	ahead.self_modulate.a = AHEAD_ALPHA
	_scene.add_child(ahead)
	var walked := Node2D.new()
	_scene.add_child(walked)
	for index in layers:
		_road(ahead if index >= ended_at else walked, road, spots[index], spots[index + 1])
	# The stages: the start's, smaller, with its signpost; each layer's.
	_stage(stage, spots[0], STAGE_WIDTH * START_SCALE, 1.0)
	var post := RouteNode.prop_for(&"sign")
	if post != null:
		var sign := Sprite2D.new()
		sign.texture = post
		sign.centered = false
		sign.scale = Vector2.ONE * SIGN_HEIGHT / post.get_height()
		sign.offset = Vector2(-post.get_width() * 0.5, -post.get_height())
		sign.position = spots[0] + SIGN_PLACE
		_scene.add_child(sign)
	for index in range(1, layers + 1):
		var boss := index == layers
		var shade := 1.0 if index <= ended_at else AHEAD_ALPHA
		_stage(stage, spots[index], STAGE_WIDTH * (RouteNode.BOSS_SCALE if boss else 1.0), shade)
	# Who stands where it ended, and the line under it.
	var last: AreaData = path[-1] if not path.is_empty() else null
	if not won and not left and last != null:
		var foe: FoeData = result.get("fallen_to")
		if foe == null:
			foe = RouteNode.leader(last)
		if foe != null:
			figure = RouteNode.foe_figure(foe, FOE_TALLEST, 1.0, FOE_GROW)
			caption.text = "%sに倒された" % foe.display_name
		else:
			caption.text = "%sで倒れた" % last.display_name
	else:
		figure = RouteMapView.MIO_RIG.instantiate()
		figure.world_height = HERO_HEIGHT
		figure.facing = RouteMapView.IDLE_FACING
		var moveset: Moveset = result.get("moveset")
		if moveset != null and moveset.art != null:
			WeaponMount.hold(figure, moveset)
		if won:
			caption.text = "%sを倒した" % last.boss.display_name if last != null and last.boss != null else "最奥まで踏破した"
		else:
			caption.text = "%sで引き返した" % last.display_name if last != null else "出発点で引き返した"
	if figure != null:
		figure.position = spots[ended_at] + (HERO_OFFSET if figure is DirectionalRig else Vector2.ZERO)
		_scene.add_child(figure)
	var room := caption.get_minimum_size()
	caption.size = room
	caption.position = Vector2(clampf(spots[ended_at].x - room.x * 0.5, 0.0, WIDTH - room.x), HEIGHT - room.y - CAPTION_GAP)


# A stage laid with its top's middle on `at`.
func _stage(texture: Texture2D, at: Vector2, width: float, shade: float) -> void:
	if texture == null:
		return
	var plate := Sprite2D.new()
	plate.texture = texture
	plate.centered = false
	plate.scale = Vector2.ONE * width / texture.get_width()
	var high := RouteNode.plate_height(texture, width)
	plate.position = at - Vector2(width * 0.5, high * RouteNode.PLATE_TOP)
	plate.modulate.a = shade
	_scene.add_child(plate)


func _road(layer: Node2D, road: Texture2D, from: Vector2, to: Vector2) -> void:
	for middle in [false, true]:
		var line := Line2D.new()
		line.width = ROAD_WIDTH * (RouteMapView.MIDDLE_SHARE if middle else 1.0)
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		var texture := RouteMapView.middle_of(road) if middle else road
		if texture != null:
			line.texture = texture
			line.texture_mode = Line2D.LINE_TEXTURE_TILE
			line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		else:
			line.default_color = RouteMapView.ROAD_PLAIN
		line.points = PackedVector2Array([from, to])
		layer.add_child(line)
