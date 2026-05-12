extends Node

enum Difficulty { EASY, NORMAL, HARD, ADAPTIVE }

var current_difficulty: Difficulty = Difficulty.EASY
var current_timeout: float = 1.0

signal difficulty_changed(new_difficulty: Difficulty)

func set_difficulty(new_diff: Difficulty) -> void:
	current_difficulty = new_diff
	difficulty_changed.emit(new_diff)
	if new_diff != Difficulty.ADAPTIVE:
		current_timeout = get_base_timeout()

func get_base_timeout() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 2.0
		Difficulty.NORMAL:
			return 1.0
		Difficulty.HARD:
			return 0.7
		Difficulty.ADAPTIVE:
			return current_timeout
	return 1.0

func get_timeout() -> float:
	return get_base_timeout()

func get_spawn_delay(lifetime: float) -> float:
	match current_difficulty:
		Difficulty.EASY:
			return lifetime
		Difficulty.NORMAL:
			return 0.5
		Difficulty.HARD:
			return 0.4
		Difficulty.ADAPTIVE:
			return lifetime * 0.7
	return 0.5

func report_reaction_time(reaction: float) -> void:
	if current_difficulty == Difficulty.ADAPTIVE:
		current_timeout = clamp(reaction * 1.2, 0.4, 2.0)

func reset_adaptive() -> void:
	current_timeout = 1.0
