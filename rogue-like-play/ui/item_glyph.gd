class_name ItemGlyph
extends RefCounted

static func main_effect(item: ItemData) -> String:
	if item.kind == ItemData.Kind.WEAPON:
		return "ダメージ %+d  /  射程 %d" % [item.weapon.damage_bonus, item.weapon.reach]
	if item.kind == ItemData.Kind.SCROLL:
		return "消費MP %d" % item.weapon.mana_cost
	return item.description().split(" / ")[0]

# Shapes use a 32-unit canvas; size and color belong to the consuming Theme.
static func category(item: ItemData) -> String:
	if not item.effect_id.is_empty():
		return "護符・消費型"
	match item.kind:
		ItemData.Kind.WEAPON:
			return ["剣", "槍", "ハンマー", "斧", "杖"][item.weapon.kind]
		ItemData.Kind.ARMOR: return "防具"
		ItemData.Kind.ACCESSORY: return "装飾品"
		ItemData.Kind.SCROLL: return "魔法の巻物"
		_: return "MP回復" if item.restore_mp > 0 else "HP回復"


static func paint(canvas: Control, rect: Rect2, item: ItemData, color: Color) -> void:
	canvas.draw_set_transform(rect.position, 0, rect.size / 32.0)
	if not item.effect_id.is_empty():
		_outline(canvas, [Vector2(9, 3), Vector2(23, 3), Vector2(23, 29), Vector2(16, 25), Vector2(9, 29), Vector2(9, 3)], color)
		_outline(canvas, [Vector2(16, 8), Vector2(20, 14), Vector2(16, 20), Vector2(12, 14), Vector2(16, 8)], color)
	elif item.kind == ItemData.Kind.WEAPON:
		_weapon(canvas, item.weapon.kind, color)
	elif item.kind == ItemData.Kind.ARMOR:
		_outline(canvas, [Vector2(5, 5), Vector2(16, 8), Vector2(27, 5), Vector2(25, 21), Vector2(16, 29), Vector2(7, 21), Vector2(5, 5)], color)
		_outline(canvas, [Vector2(16, 10), Vector2(16, 24)], color)
	elif item.kind == ItemData.Kind.ACCESSORY:
		_outline(canvas, [Vector2(9, 3), Vector2(12, 11), Vector2(20, 11), Vector2(23, 3)], color)
		_outline(canvas, [Vector2(16, 11), Vector2(25, 20), Vector2(16, 29), Vector2(7, 20), Vector2(16, 11)], color)
		canvas.draw_circle(Vector2(16, 20), 2, color)
	elif item.kind == ItemData.Kind.SCROLL:
		_outline(canvas, [Vector2(6, 4), Vector2(25, 4), Vector2(25, 25), Vector2(22, 28), Vector2(6, 28), Vector2(6, 4)], color)
		_outline(canvas, [Vector2(10, 4), Vector2(10, 23), Vector2(25, 23)], color)
		_outline(canvas, [Vector2(14, 10), Vector2(21, 10)], color)
		_outline(canvas, [Vector2(14, 15), Vector2(21, 15)], color)
	else:
		_outline(canvas, [Vector2(11, 3), Vector2(21, 3), Vector2(21, 7), Vector2(19, 7), Vector2(19, 12), Vector2(25, 18), Vector2(25, 27), Vector2(7, 27), Vector2(7, 18), Vector2(13, 12), Vector2(13, 7), Vector2(11, 7), Vector2(11, 3)], color)
		if item.restore_mp > 0:
			_outline(canvas, [Vector2(18, 15), Vector2(13, 21), Vector2(19, 21), Vector2(15, 25)], color)
		else:
			_outline(canvas, [Vector2(11, 21), Vector2(21, 21)], color)
			_outline(canvas, [Vector2(16, 16), Vector2(16, 26)], color)
	canvas.draw_set_transform(Vector2.ZERO)


static func _weapon(canvas: Control, kind: WeaponData.Kind, color: Color) -> void:
	if kind == WeaponData.Kind.SWORD:
		_outline(canvas, [Vector2(14, 21), Vector2(14, 7), Vector2(18, 2), Vector2(22, 7), Vector2(18, 21), Vector2(14, 21)], color)
		_outline(canvas, [Vector2(8, 20), Vector2(24, 23)], color)
		_outline(canvas, [Vector2(16, 23), Vector2(14, 30)], color)
	elif kind == WeaponData.Kind.SPEAR:
		_outline(canvas, [Vector2(16, 2), Vector2(22, 12), Vector2(16, 10), Vector2(10, 12), Vector2(16, 2)], color)
		_outline(canvas, [Vector2(16, 10), Vector2(16, 30)], color)
	elif kind == WeaponData.Kind.STAFF:
		canvas.draw_arc(Vector2(18, 9), 6, -PI, PI / 2, 20, color, 2, true)
		_outline(canvas, [Vector2(18, 15), Vector2(13, 30)], color)
	else:
		_outline(canvas, [Vector2(16, 9), Vector2(16, 30)], color)
		if kind == WeaponData.Kind.HAMMER:
			_outline(canvas, [Vector2(5, 4), Vector2(27, 4), Vector2(27, 13), Vector2(5, 13), Vector2(5, 4)], color)
		else:
			_outline(canvas, [Vector2(16, 4), Vector2(28, 7), Vector2(28, 17), Vector2(16, 13), Vector2(16, 4)], color)


static func _outline(canvas: Control, points: PackedVector2Array, color: Color) -> void:
	canvas.draw_polyline(points, color, 2, true)
