class_name ProtoMain
extends RefCounted

# The prototypes there are, in the order the launcher and the captures show them.
static func kinds() -> Array[Script]:
	return [ProtoShaft, ProtoVista, ProtoChart]


static func names() -> Array[String]:
	return ["shaft", "vista", "chart"]
