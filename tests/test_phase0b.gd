extends GutTest

# Phase 0-B: minimal smoke test for GUT on Godot 4.7.2.
# No game logic.


func test_one_plus_one_equals_two() -> void:
	assert_eq(1 + 1, 2)
