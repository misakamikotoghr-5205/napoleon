# Contract 1.3 visible scene state, staged cards and expanded night offers.
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Cases = preload("res://scripts/tests/cards/G02/test_cases.gd")
func _initialize() -> void:
	var t := T.new(self, "G02_stage_view")
	Cases.run(t, "stage_view")
	t.finish()
