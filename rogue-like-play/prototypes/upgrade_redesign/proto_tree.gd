class_name ProtoTree
extends RefCounted

# The lasting upgrades for the three redesign prototypes: the game's own
# upgrades (MetaProgress.UPGRADES) and its own rules for buying them
# (MetaProgress.can_buy and buy), on a MetaProgress of its own that is never
# saved. What each prototype shows of an upgrade (its figure now and next,
# what it does, what it waits for, its price) is worked out here once, the
# same way the shipped page does, so the three differ only in how they show
# it.

enum State { FULL, BUY, SHORT, LOCKED }

const BRANCHES: Array[StringName] = [&"body", &"skill", &"weapon", &"growth", &"special"]
const BRANCH_NAMES := {&"": "中央", &"body": "身体", &"growth": "成長", &"skill": "スキル", &"special": "必殺技", &"weapon": "武器"}
const START_ECHO := 400
const START_RANKS := {
	"echo_lantern": 1, "sturdy_body": 2, "firm_guard": 1, "double_dash": 1, "learn_thunder_flash": 1,
	"parting_blessing": 1, "quick_study": 1, "learn_echo_burst": 1,
}

var meta: MetaProgress
# The upgrade bought last, for the prototypes' moment.
var bought: StringName = &""


func _init() -> void:
	reset()


func reset() -> void:
	meta = MetaProgress.new()
	meta.echo = START_ECHO
	meta.ranks = START_RANKS.duplicate()
	bought = &""


static func root() -> MetaUpgrade:
	return MetaProgress.find(MetaProgress.ROOT)


func rank(upgrade: MetaUpgrade) -> int:
	return meta.rank(upgrade.id)


func state(upgrade: MetaUpgrade) -> State:
	if upgrade.price(rank(upgrade)) < 0:
		return State.FULL
	if not meta.unlocked(upgrade.id):
		return State.LOCKED
	return State.BUY if meta.can_buy(upgrade.id) else State.SHORT


# The price of its next rank, or -1 when it is full.
func price(upgrade: MetaUpgrade) -> int:
	return upgrade.price(rank(upgrade))


# How much echo is missing for its next rank (0: none).
func missing(upgrade: MetaUpgrade) -> int:
	return maxi(0, price(upgrade) - meta.echo)


func parent(upgrade: MetaUpgrade) -> MetaUpgrade:
	return MetaProgress.find(upgrade.parent)


func children(upgrade: MetaUpgrade) -> Array[MetaUpgrade]:
	var grown: Array[MetaUpgrade] = []
	for other in MetaProgress.UPGRADES:
		if other.parent == upgrade.id:
			grown.append(other)
	return grown


# A branch's upgrades, each after the one it grows from (depth first).
func members(branch: StringName) -> Array[MetaUpgrade]:
	var listed: Array[MetaUpgrade] = []
	for first in children(root()):
		if first.branch == branch:
			_gather(first, listed)
	return listed


func _gather(upgrade: MetaUpgrade, into: Array[MetaUpgrade]) -> void:
	into.append(upgrade)
	for grown in children(upgrade):
		_gather(grown, into)


# Steps from the root (the root: 0).
func depth(upgrade: MetaUpgrade) -> int:
	var steps := 0
	var at := upgrade
	while at != null and not at.parent.is_empty():
		steps += 1
		at = parent(at)
	return steps


# The figure now and next ("最大HP 115 → 130（+15）"), or nothing.
func figure(upgrade: MetaUpgrade) -> String:
	return upgrade.figure_line(rank(upgrade))


# What it does, left off when it only says the figure again.
func note(upgrade: MetaUpgrade) -> String:
	return "" if upgrade.description_restates_figure(rank(upgrade)) else tr(upgrade.description)


# What it waits for, or nothing.
func waits(upgrade: MetaUpgrade) -> String:
	if meta.unlocked(upgrade.id):
		return ""
	return tr("「%s」を習得すると解放") % tr(parent(upgrade).display_name)


# The word for buying its next rank.
func verb(upgrade: MetaUpgrade) -> String:
	return tr("習得") if rank(upgrade) == 0 else tr("強化")


func buy(upgrade: MetaUpgrade) -> bool:
	if not meta.buy(upgrade.id):
		return false
	bought = upgrade.id
	return true


# [ranks held, ranks in all] of a branch.
func tally(branch: StringName) -> Array[int]:
	var held := 0
	var all := 0
	for upgrade in members(branch):
		held += rank(upgrade)
		all += upgrade.max_rank()
	return [held, all]


# How many of a branch's upgrades the echo held can buy a rank of.
func open_count(branch: StringName) -> int:
	var count := 0
	for upgrade in members(branch):
		count += 1 if state(upgrade) == State.BUY else 0
	return count
