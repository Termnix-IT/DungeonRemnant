extends SceneTree

# The ends of a run played through once, for a film of them: a chapter's
# last hall (the boss's entrance, the fight, its fall, the word of its
# slaying, the dark closing on the hall) and the result of a run won (the
# dawn out of the door, the word struck, the seal, the echo counted, the way
# on taken); then a fight lost (her fall, the dark, the sword and who felled
# her) and its way on; then a run left from the fight's menu and its result.
# The runs are real RunDirectors on a fixed seed with a progress of their
# own (nothing is saved); she is steered by a few simple rules. The film is
# recorded slower than it plays, so the moments measured on the real clock
# are measured on the film's frames here (HitStop.clock). Run under the
# movie writer, which also records the sound, and turn the result into a
# film with ffmpeg:
#   godot --path . --rendering-method gl_compatibility --resolution 1280x720 --fixed-fps 60 --write-movie .godot/end_movie.avi --script res://tests/capture_end_movie.gd
#   ffmpeg -y -i .godot/end_movie.avi -c:v libx264 -pix_fmt yuv420p -crf 20 -c:a aac .godot/end_movie.mp4

const FRAME := 1.0 / 60.0
const SEED := 31
const REACH := 92.0
const STRIKE_GAP := 0.34
const KEPT := 60

var director: RunDirector
var area: BattleArea
var meta: MetaProgress
var _strike_left := 0.0
var _side := 1.0
var _kept := KEPT


func _initialize() -> void:
	call_deferred("play")


func play() -> void:
	TranslationServer.set_locale("ja")
	HitStop.clock = func() -> int: return Engine.get_process_frames() * 1000000 / 60
	meta = MetaProgress.new()
	meta.echo = 240
	for foe in FoeCatalog.FOES.slice(0, 5):
		meta.met[foe.id] = true
	# The chapter's last hall, and the run won.
	_start()
	await process_frame
	var run := director.run
	var last := run.route.size() - 1
	for layer in last:
		run.taken.append(run.route.nodes(layer)[0])
	run.layer = last
	run.areas_cleared = last
	run.echo = 380
	run.kills = 143
	run.time = 262.0
	# High enough that the boss's shards bring no level: its fall is told whole.
	run.progression.level = 40
	for id: StringName in [&"thunder_blade", &"chain_lightning", &"whirlwind"]:
		run.build.take(run.build.find(id))
	for index in 6:
		var offer := run.build.offer(run.rng, 3)
		if not offer.is_empty():
			run.build.take(offer[0])
	# Straight into the hall (the gates are another film's).
	director.map_view.hide()
	director.enter(run.route.nodes(last)[0])
	area = director.area
	area.hero.controlled = false
	while area.staging:
		await process_frame
	await _fight(4.5)
	var boss := area.boss_foe
	if boss != null and is_instance_valid(boss) and not boss.dying:
		boss.receive(DamageInfo.make(1000000.0, Vector2.UP, 0.0, area.hero))
	while director.area != null:
		await _fight(0.1)
	area = null
	if director.choice.visible:
		await _wait(1.6)
		director.choice._select(0)
	while director.result.is_empty():
		await process_frame
	# The result plays by itself; a boon is looked at, then the way on.
	await _until_settled()
	await _wait(1.6)
	if not director.end_view._boon_cells.is_empty():
		director.end_view._boon_cells[mini(3, director.end_view._boon_cells.size() - 1)].grab_focus()
		await _wait(1.2)
		director.end_view._button.grab_focus()
	await _wait(1.0)
	director.free()
	director = null
	await _wait(0.4)
	# A fight lost.
	_start()
	await _wait(1.4)
	director.run.echo = 55
	director.map_view._choose(director.run.route.nodes(0)[0])
	while director.area == null:
		await process_frame
	area = director.area
	area.hero.controlled = false
	await _fight(5.0)
	_kept = 1
	area.hero.health.hp = 1
	while area != null and is_instance_valid(area) and area.hero.health.alive():
		await _fight(0.05)
	area = null
	while director.result.is_empty():
		await process_frame
	await _until_settled()
	await _wait(2.6)
	director.free()
	director = null
	_kept = KEPT
	await _wait(0.4)
	# A run left from the fight's menu.
	_start()
	await _wait(1.4)
	director.run.echo = 120
	director.map_view._choose(director.run.route.nodes(0)[0])
	while director.area == null:
		await process_frame
	area = director.area
	area.hero.controlled = false
	await _fight(3.0)
	area.open_menu()
	await _wait(0.9)
	area.menu.abort_requested.emit()
	await _wait(1.1)
	area.prompt.confirmed.emit()
	area = null
	while director.result.is_empty():
		await process_frame
	await _until_settled()
	await _wait(2.2)
	# The real clock goes back before leaving: a function of this script left
	# in the static variable brings the engine down as it exits.
	HitStop.clock = Time.get_ticks_usec
	quit()


func _start() -> void:
	director = RunDirector.new()
	director.seed_value = SEED
	director.meta = meta
	director.returns_to_base = true
	root.add_child(director)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _until_settled() -> void:
	for frame in 1200:
		await process_frame
		if director.end_view.settled:
			return


# She fights for `seconds` of the film, kept on her feet until her fall is due.
func _fight(seconds: float) -> void:
	var frames := roundi(seconds / FRAME)
	while frames > 0:
		await physics_frame
		frames -= 1
		if area == null or not is_instance_valid(area) or not area.is_inside_tree():
			continue
		if area.choice.visible and area.choice.armed:
			area.choice._select(0)
			continue
		if paused or area.choosing() or area.hero == null or not area.hero.health.alive():
			continue
		area.hero.health.hp = maxi(area.hero.health.hp, _kept)
		area.hero.step(_steer(), FRAME)


# The nearest foe gone to and struck; with none, she stands.
func _steer() -> HeroInput:
	var hero := area.hero
	var at := hero.global_position
	_strike_left -= FRAME
	var target: Foe = null
	var nearest := INF
	for foe: Foe in area.foes:
		if foe.dying:
			continue
		var far := foe.global_position.distance_to(at)
		if far < nearest:
			nearest = far
			target = foe
	if target == null:
		return HeroInput.make()
	var toward := (target.global_position - at).normalized()
	if nearest > REACH * 0.8:
		return HeroInput.make(toward, toward)
	if _strike_left <= 0.0:
		_strike_left = STRIKE_GAP
		_side = -_side
		return HeroInput.make(Vector2.ZERO, toward, true)
	return HeroInput.make(toward.orthogonal() * _side * 0.5, toward)
