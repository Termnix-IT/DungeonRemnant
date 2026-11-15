class_name ProtoMain
extends RefCounted

# The prototypes there are, in the order the launcher and the captures show them.
static func kinds() -> Array[Script]:
	return [ProtoForge, ProtoTome, ProtoStars]


static func names() -> Array[String]:
	return ["forge", "tome", "stars"]
