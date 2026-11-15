class_name ProtoMain
extends RefCounted

# The prototypes there are, in the order the launcher and the captures show them.
static func kinds() -> Array[Script]:
	return [ProtoPlaces, ProtoMarquee, ProtoDeck]


static func names() -> Array[String]:
	return ["places", "marquee", "deck"]
