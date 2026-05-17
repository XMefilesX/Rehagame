extends Node

enum Difficulty { EASY, NORMAL, HARD, ADAPTIVE }

# Czasy życia aktywności (sekundy) wg tabeli z dokumentu badawczego
const _TIMEOUTS: Dictionary = {
	"circle":   {"EASY": 4.0, "NORMAL": 2.5, "HARD": 1.8},
	"slice":    {"EASY": 2.5, "NORMAL": 1.5, "HARD": 1.3},
	"reaction": {"EASY": 1.5, "NORMAL": 0.9, "HARD": 0.7},
	"target":   {"EASY": 2.0, "NORMAL": 1.0, "HARD": 0.7},
}

var current_difficulty: Difficulty = Difficulty.EASY
var adaptive_multiplier: float = 1.0   # ADAPTIVE skaluje wartości Normal

signal difficulty_changed(new_difficulty: Difficulty)

func set_difficulty(new_diff: Difficulty) -> void:
	current_difficulty = new_diff
	difficulty_changed.emit(new_diff)

func get_timeout_for(type: String) -> float:
	var row: Dictionary = _TIMEOUTS.get(type, {})
	match current_difficulty:
		Difficulty.EASY:
			return row.get("EASY", 1.0)
		Difficulty.NORMAL:
			return row.get("NORMAL", 1.0)
		Difficulty.HARD:
			return row.get("HARD", 1.0)
		Difficulty.ADAPTIVE:
			return row.get("NORMAL", 1.0) * adaptive_multiplier
	return 1.0

func report_reaction_time(reaction: float) -> void:
	if current_difficulty == Difficulty.ADAPTIVE:
		# EMA (alfa=0.25) wygładza skoki po pojedynczych outlierach.
		# Zakres 0.7–1.5 zapobiega: (a) timeoutom poniżej fizjologicznego minimum RT
		# (0.7 * 0.9s = 0.63s, margines ~160ms ponad typowe RT+motor), (b) triwialnemu
		# poziomowi (1.5 * 0.9s = 1.35s). Wzorzec EMA dla DDA polecany przez Wayline
		# blog "Dynamic Difficulty in Godot" oraz wątek r/godot o adaptive spawning.
		const EMA_ALPHA: float = 0.25
		var target: float = clamp(reaction * 1.2, 0.7, 1.5)
		adaptive_multiplier = EMA_ALPHA * target + (1.0 - EMA_ALPHA) * adaptive_multiplier

func reset_adaptive() -> void:
	adaptive_multiplier = 1.0
