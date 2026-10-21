class_name Status
extends RefCounted

# The statuses a blow can leave on a foe, and what each does while it lasts.
# A foe keeps them (Foe.apply_status) and its view tints by the strongest.

const SHOCK := &"shock"
const BURN := &"burn"

# Seconds each lasts; a new one only renews the time.
const DURATION := {SHOCK: 4.0, BURN: 3.0}
# Shocked: walks this much slower.
const SHOCK_SLOW := 0.3
# Burning: loses this share of the hero's power every BURN_TICK seconds.
const BURN_TICK := 0.5
const BURN_SHARE := 0.3
const TINT := {SHOCK: Color(0.75, 0.9, 1.6), BURN: Color(1.6, 0.9, 0.6)}
const NAMES := {SHOCK: "感電", BURN: "燃焼"}


static func duration(id: StringName) -> float:
	return float(DURATION.get(id, 0.0))
