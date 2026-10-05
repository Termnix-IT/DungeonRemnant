class_name UIFormat
extends RefCounted

# How numbers read across the hub (docs/MVP_SPEC.md, 個別画面のUI文法):
# thousands grouped, the unit after the number.


# 1280 -> "1,280".
static func amount(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped


# 1280 -> "1,280 G".
static func gold(value: int) -> String:
	return "%s G" % amount(value)
