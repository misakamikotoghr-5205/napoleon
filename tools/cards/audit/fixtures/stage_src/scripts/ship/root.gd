extends Node
class_name ShipRoot
const Child = preload("res://scripts/ship/child.gd")
func _ready():
	var x = ShipOther.new()
	x.go()
