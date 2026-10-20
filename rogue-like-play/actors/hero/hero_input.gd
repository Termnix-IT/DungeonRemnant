class_name HeroInput
extends RefCounted

# One physics frame of the player's intent, read from the devices by Hero or
# made up by a test.

var move := Vector2.ZERO
# Where to swing (unit), or zero to keep the way she faces.
var aim := Vector2.ZERO
var strike_pressed := false
var strike_held := false
var dash_pressed := false


static func make(move_value: Vector2 = Vector2.ZERO, aim_value: Vector2 = Vector2.ZERO, strike_press: bool = false, strike_hold: bool = false, dash_press: bool = false) -> HeroInput:
	var input := HeroInput.new()
	input.move = move_value
	input.aim = aim_value
	input.strike_pressed = strike_press
	input.strike_held = strike_hold or strike_press
	input.dash_pressed = dash_press
	return input
