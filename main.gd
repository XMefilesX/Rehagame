extends Node2D

@onready var spawn_timer = $SpawnTimer
@onready var session_timer = $SessionTimer   # ← dodane

var target_scene = preload("res://target.tscn")
var reaction_times: Array[float] = []
var hits: int = 0

func _ready():
	# Ustawienia timerów
	session_timer.wait_time = 30.0
	session_timer.one_shot = true
	session_timer.autostart = true
	
	spawn_timer.wait_time = 1.0
	spawn_timer.autostart = true

# Tworzenie nowych celów
func _on_spawn_timer_timeout():
	var target = target_scene.instantiate()
	target.position = Vector2(randf_range(100, 1180), randf_range(100, 620))
	add_child(target)
	spawn_timer.wait_time = randf_range(0.8, 1.5)

# Rejestracja trafienia (wywoływane z target.gd)
func register_hit(reaction_time: float):
	reaction_times.append(reaction_time)
	hits += 1

# Koniec sesji 30 sekund
func _on_session_timer_timeout():
	spawn_timer.stop()
	show_results()

# Pokazanie wyników na końcu
func show_results():
	var average = 0.0
	if reaction_times.size() > 0:
		for t in reaction_times:
			average += t
		average /= reaction_times.size()
	
	print("=== KONIEC GRY ===")
	print("Średni czas reakcji: ", average, " sekund")
	print("Trafienia: ", hits)
	
	if average < 1.0:
		print("WYGRAŁEŚ!")
	else:
		print("PRZEGRAŁEŚ!")
