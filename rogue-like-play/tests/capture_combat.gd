extends SceneTree

# The fight's great moments drawn for real at 1600x900: her arrival, a
# field a few seconds in, a swing landing, foes falling into echo shards,
# the shards lying and flying to her, a level gained (the beat before the
# cards, the cards being dealt, the hand, a card pointed at, the card taken,
# the fight going on), a boss foretold, its entrance (the view closing on
# it, its roar, its name), its fight, its rage, its fall and the hall
# cleared, her own fall, the parting blessing over the gates, and the hand
# in English and at 1280x720 and 1920x1080. Images go to
# .godot/combat_*.png. Needs a rendering display driver:
#   godot --path . --rendering-method gl_compatibility --log-file .godot/combat-capture.log --script res://tests/capture_combat.gd

const FRAME := 1.0 / 60.0
const Choice := preload("res://ui/ability_choice.gd")
var shots := {}
var area: BattleArea


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display driver.")
		quit(1)
		return
	TranslationServer.set_locale("ja")
	_size(Vector2i(1600, 900))
	await _field()
	await _boss()
	await _defeat()
	await _blessing()
	var result := OK
	for file_name: String in shots:
		result |= (shots[file_name] as Image).save_png("res://.godot/%s.png" % file_name)
	print("Captured the fight: ", ", ".join(shots.keys()))
	quit(0 if result == OK else 1)


# A field: arriving, fighting, shards, a level and its cards.
func _field() -> void:
	_enter("echo_corridor")
	await _real(0.1)
	await _grab("combat_arrive")
	await _real(3.2)
	await _grab("combat_field")
	var hero := area.hero
	await drive(HeroInput.make(Vector2.ZERO, _toward_nearest(), true), 0.1)
	await _grab("combat_swing")
	await drive(HeroInput.new(), 0.4)
	# Foes felled together a little way from her: their motes and shards.
	area.director.running = false
	var rat: FoeData = load("res://data/foes/dashing_rat.tres")
	var fallen: Array[Foe] = []
	for index in 6:
		var at := hero.global_position + Vector2.RIGHT.rotated(index * TAU / 6.0 + 0.3) * 190.0
		fallen.append(area.spawn_foe(rat, at))
	await drive(HeroInput.new(), 0.3)
	for foe: Foe in fallen:
		if is_instance_valid(foe):
			foe.receive(DamageInfo.make(10000.0, (foe.global_position - hero.global_position).normalized()))
	await _real(0.16)
	await _grab("combat_fall")
	# Shards of each worth lying about her, then flying to her.
	for index in 18:
		var at := hero.global_position + Vector2.RIGHT.rotated(index * TAU / 18.0) * (150.0 + 34.0 * (index % 3))
		area.gems.drop(at, [1, 4, 12][index % 3])
	await drive(HeroInput.new(), 0.7)
	await _grab("combat_shards")
	await drive(HeroInput.make(Vector2.RIGHT, Vector2.RIGHT), 0.42)
	await _grab("combat_pull")
	await drive(HeroInput.new(), 0.5)
	while area.choosing():
		area.choice._select(0)
		await _real(0.5)
	# A level: the beat before the cards, the deal, the hand, a card
	# pointed at, the card taken, the fight going on.
	area._on_gems(area.run.progression.required_exp())
	await _real(BattleArea.LEAD_TIME * 0.6)
	await _grab("combat_level")
	await _real(BattleArea.LEAD_TIME * 0.4 + Choice.SHADE_TIME + Choice.DEAL_STAGGER + Choice.TURN_AFTER + 0.07)
	await _grab("combat_deal")
	await _real(Choice.arm_time(3) + 0.4)
	await _grab("combat_cards")
	area.choice.cards[1].get_parent().grab_focus()
	await _real(0.3)
	await _grab("combat_card_focus")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		_size(size)
		await _real(0.3)
		await _grab("combat_cards_%d" % size.y)
	_size(Vector2i(1600, 900))
	await _real(0.2)
	area.choice._select(1)
	await _real(0.12)
	await _grab("combat_card_taken")
	await _real(0.22)
	await _grab("combat_resume")
	await _real(0.8)
	# The same hand in English, at a later level (ranks being raised).
	TranslationServer.set_locale("en")
	for id: StringName in [&"thunder_blade", &"chain_lightning", &"hellfire"]:
		area.run.build.take(area.run.build.find(id))
	area._on_gems(area.run.progression.required_exp())
	await _real(BattleArea.LEAD_TIME + Choice.arm_time(3) + 0.5)
	await _grab("combat_cards_en")
	area.choice._select(0)
	await _real(0.6)
	while area.choosing():
		area.choice._select(0)
		await _real(0.5)
	TranslationServer.set_locale("ja")
	_leave()


# The boss hall, from its omen to the hall cleared.
func _boss() -> void:
	_enter("guardian_hall")
	area.hero.health.max_hp = 100000
	area.hero.health.hp = 100000
	await _real(BattleArea.BOSS_DELAY + BattleArea.BOSS_MARK_TIME * 0.8)
	await _grab("combat_boss_omen")
	while area.get_node_or_null("BossIntro") == null:
		await process_frame
	await _real(BossIntro.PAN_TIME * 0.75)
	await _grab("combat_boss_approach")
	await _real(BossIntro.ROAR_AT - BossIntro.PAN_TIME * 0.75 + 0.1)
	await _grab("combat_boss_roar")
	await _real(BossIntro.NAME_TIME + 0.4)
	await _grab("combat_boss_name")
	while area.staging:
		await process_frame
	await _real(1.2)
	await _grab("combat_boss_fight")
	var boss := area.boss_foe
	boss.receive(DamageInfo.make(boss.data.max_hp * 0.55, Vector2.UP))
	await _real(0.14)
	await _grab("combat_boss_rage")
	await _real(1.6)
	await _grab("combat_boss_second")
	boss.receive(DamageInfo.make(1000000.0, Vector2.UP))
	await _real(0.22)
	await _grab("combat_boss_fall")
	await _real(1.3)
	while area.choosing():
		area.choice._select(0)
		await _real(0.5)
	await _grab("combat_boss_cleared")
	_leave()


# Her fall.
func _defeat() -> void:
	_enter("ember_waste")
	await _real(3.0)
	area.hero.health.hp = 1
	area.hero.receive(DamageInfo.make(1000.0, Vector2.RIGHT))
	await _real(0.5)
	await _grab("combat_defeat")
	await _real(1.0)
	await _grab("combat_defeat_after")
	_leave()


# The parting blessing: the same hand, over the gates.
func _blessing() -> void:
	var director := RunDirector.new()
	director.seed_value = 12
	root.add_child(director)
	await _real(RouteGates.RISE_TIME + RouteGates.RISE_STAGGER * 3.0 + 0.4)
	director._bless(director.run.route.nodes(0)[0])
	await _real(Choice.arm_time(3) + 0.5)
	await _grab("combat_blessing")
	director.free()
	await process_frame


func _enter(name: String) -> void:
	area = BattleArea.new()
	area.setup(load("res://data/areas/%s.tres" % name), RunState.new(9), 9)
	root.add_child(area)
	area.hero.controlled = false


func _leave() -> void:
	area.hit_stop.release()
	paused = false
	area.free()
	area = null


func _size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size


# Real seconds, whatever the world's pace and whether it is stopped.
func _real(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


# Steps the hero by hand for `seconds` of physics frames; a press counts on
# the first frame only.
func drive(input: HeroInput, seconds: float) -> void:
	for index in roundi(seconds / FRAME):
		await physics_frame
		var frame_input := input if index == 0 else HeroInput.make(input.move, input.aim, false, input.strike_held, false)
		area.hero.step(frame_input, FRAME)


func _toward_nearest() -> Vector2:
	var hero := area.hero
	var best := Vector2.RIGHT
	var nearest := INF
	for foe: Foe in area.foes:
		var distance := foe.global_position.distance_to(hero.global_position)
		if distance < nearest:
			nearest = distance
			best = (foe.global_position - hero.global_position).normalized()
	return best


func _grab(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	shots[file_name] = root.get_texture().get_image()
