class_name ProtoMain
extends RefCounted

# The prototypes there are, in the order the launcher and the captures show them.
static func kinds() -> Array[Script]:
	return [ProtoIndex, ProtoScroll, ProtoPlates]


static func names() -> Array[String]:
	return ["index", "scroll", "plates"]
