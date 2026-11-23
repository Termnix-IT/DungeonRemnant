extends SceneTree

# A fight played through once, for a film of it: the gates, her walk
# through one and the dark lifting off the area, a fight (foes felled, their
# echo shards gathered, a level gained, its cards dealt and one taken, the
# fight going on), the area cleared and the dark closing on it, its reward
# and the gates again; then a boss's hall (the omen, its entrance, the
# fight, its rage, its fall); then her own fall and the end of the run.
# The runs are real RunDirectors on a fixed seed and the hall a real
# BattleArea; she is steered by a few simple rules (go to the nearest foe,
# strike it, gather what it leaves) and kept on her feet until her fall is
# due. The film is recorded slower than it plays, so the moments the world
# holds still, which are measured on the real clock, are measured on the
# film's frames here (HitStop.clock) and last in it what they last in play.
# Run under the movie writer, which also records the sound, and turn the
# result into a film with ffmpeg:
#   godot --path . --rendering-method gl_compatibility --resolution 1280x720 --fixed-fps 60 --write-movie .godot/combat_movie.avi --script res://tests/capture_combat_movie.gd
#   ffmpeg -y -i .godot/combat_movie.avi -c:v libx264 -pix_fmt yuv420p -crf 20 -c:a aac .godot/combat_movie.mp4

const FRAME := 1.0 / 60.0
const SEED := 12
const Choice := preload("res://ui/ability_choice.gd")
# She strikes a foe within this reach, this often; she is kept above this
# much health until her fall is due.
const REACH := 92.0
const STRIKE_GAP := 0.34
const SKILL_GAP := 4.0
const KEPT := 45

var director: RunDirector
var area: BattleArea
var _strike_left := 0.0
var _skill_left := 2.0
var _side := 1.0
var _kept := KEPT


func _initialize() -> void:
	call_deferred("play")


func play() -> void:
	TranslationServer.set_locale("ja")
	HitStop.clock = func() -> int: return Engine.get_process_frames() * 1000000 / 60
	# The gates, a fight, its level, its clearing, its reward, the gates.
	_start()
	await _wait(2.4)
	director.map_view._choose(director.run.route.nodes(0)[0])
	while director.area == null:
		await process_frame
	area = director.area
	area.hero.controlled = false
	await _fight(9.0)
	# A level, if the fight has not brought one: the shards for it, to gather.
	if area != null and area.run.progression.level == 1:
		var owed: int = area.run.progression.required_exp() - area.run.progression.exp
		for index in 8:
			area.gems.drop(area.hero.global_position + Vector2.RIGHT.rotated(index * TAU / 8.0) * 150.0, ceili(owed / 8.0))
	await _fight(7.0)
	if area != null and is_instance_valid(area):
		if area.data.survive_time > 0.0:
			area.elapsed = area.data.survive_time
		else:
			area.kills = area.data.kill_target
	while director.area != null:
		await _fight(0.2)
	await _wait(1.0)
	if director.choice.visible:
		await _wait(Choice.arm_time(3) + 1.2)
		director.choice._select(1)
	await _wait(3.2)
	director.free()
	director = null
	# The boss's hall.
	var run := RunState.new(SEED)
	for id: StringName in [&"thunder_blade", &"chain_lightning", &"whirlwind"]:
		run.build.take(run.build.find(id))
	area = BattleArea.new()
	area.setup(load("res://data/areas/guardian_hall.tres"), run, SEED)
	root.add_child(area)
	area.hero.controlled = false
	while area.staging:
		await process_frame
	await _fight(6.0)
	var boss := area.boss_foe
	if boss != null and not boss.dying and boss.phase == 1:
		boss.receive(DamageInfo.make(maxf(1.0, boss.health.hp - boss.data.max_hp * 0.45), Vector2.UP, 0.0, area.hero))
	await _fight(6.0)
	if boss != null and is_instance_valid(boss) and not boss.dying:
		boss.receive(DamageInfo.make(1000000.0, Vector2.UP, 0.0, area.hero))
	await _fight(BattleArea.CLEAR_PAUSE + 2.6)
	area.hit_stop.release()
	paused = false
	area.free()
	area = null
	# Her fall, and the end of the run.
	_start()
	await _wait(1.6)
	director.map_view._choose(director.run.route.nodes(0)[0])
	while director.area == null:
		await process_frame
	area = director.area
	area.hero.controlled = false
	await _fight(4.0)
	# No longer kept on her feet: the next blow fells her.
	_kept = 1
	area.hero.health.hp = 1
	while area.hero.health.alive():
		if area.hero.receive(DamageInfo.make(1000.0, Vector2.RIGHT)) == 0:
			await _fight(0.05)
	area = null
	await _wait(RunDirector.FALL_PAUSE + 4.5)
	# The real clock goes back before leaving: a function of this script left
	# in the static variable brings the engine down as it exits.
	HitStop.clock = Time.get_ticks_usec
	quit()


func _start() -> void:
	director = RunDirector.new()
	director.seed_value = SEED
	root.add_child(director)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


# She fights for `seconds` of the film: steered while the world runs, and
# answering the cards a level brings.
func _fight(seconds: float) -> void:
	var frames := roundi(seconds / FRAME)
	while frames > 0:
		await physics_frame
		frames -= 1
		if area == null or not is_instance_valid(area) or not area.is_inside_tree():
			continue
		if area.choice.visible:
			await _answer()
			continue
		if paused or area.choosing() or area.hero == null or not area.hero.health.alive():
			continue
		area.hero.health.hp = maxi(area.hero.health.hp, _kept)
		area.hero.step(_steer(), FRAME)


# A level's cards: looked over, another pointed at, and taken.
func _answer() -> void:
	var choice := area.choice
	await _wait(Choice.arm_time(choice.offers.size()) + 0.9)
	if not choice.visible:
		return
	var pick := mini(1, choice.offers.size() - 1)
	choice.buttons[pick].grab_focus()
	await _wait(0.7)
	if choice.visible:
		choice._select(pick)


# The nearest foe gone to and struck; with none near, the nearest shard
# gathered.
func _steer() -> HeroInput:
	var hero := area.hero
	var at := hero.global_position
	_strike_left -= FRAME
	_skill_left -= FRAME
	var target: Foe = null
	var nearest := INF
	for foe: Foe in area.foes:
		if foe.dying:
			continue
		var far := foe.global_position.distance_to(at)
		if far < nearest:
			nearest = far
			target = foe
	if target != null and nearest < 520.0:
		var toward := (target.global_position - at).normalized()
		if nearest > REACH * 0.8:
			return HeroInput.make(toward, toward)
		if _skill_left <= 0.0:
			_skill_left = SKILL_GAP
			return HeroInput.make(Vector2.ZERO, toward, false, false, false, true)
		if _strike_left <= 0.0:
			_strike_left = STRIKE_GAP
			_side = -_side
			return HeroInput.make(Vector2.ZERO, toward, true)
		# Between blows she circles it.
		return HeroInput.make(toward.orthogonal() * _side * 0.5, toward)
	var shard := Vector2.ZERO
	nearest = INF
	for spot: Vector2 in area.gems.positions:
		var far := spot.distance_to(at)
		if far < nearest:
			nearest = far
			shard = spot
	if nearest < INF and nearest > 6.0:
		return HeroInput.make((shard - at).normalized(), (shard - at).normalized())
	if target != null:
		var toward := (target.global_position - at).normalized()
		return HeroInput.make(toward, toward)
	return HeroInput.new()
