class_name ProtoMain
extends RefCounted

# The prototypes there are, in the order the launcher and the captures show them.
static func kinds() -> Array[Script]:
	return [ProtoChart, ProtoGates, ProtoBoard]


static func names() -> Array[String]:
	return ["chart", "gates", "board"]
