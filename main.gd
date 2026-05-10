extends Node2D

# === STAŁE – zero magicznych liczb ===
const SESSION_DURATION: float = 30.0
const MIN_SPAWN_DELAY: float = 0.8
const MAX_SPAWN_DELAY: float = 1.5
const SPAWN_MIN_X: float = 100.0
const SPAWN_MAX_X: float = 1180.0
const SPAWN_MIN_Y: float = 100.0
const SPAWN_MAX_Y: float = 620.0
const WIN_THRESHOLD: float = 1.0

@onready var spawn_timer = $SpawnTimer
@onready var session_timer = $SessionTimer

var target_scene = preload("res://target.tscn")
var reaction_times: Array[float] = []
var hits: int = 0

func _ready():
	# Inicjalizacja timerów
	session_timer.wait_time = SESSION_DURATION
	session_timer.one_shot = true
	session_timer.autostart = true
	
	spawn_timer.wait_time = 1.0
	spawn_timer.autostart = true
	
	# Ukryj panel wyników na początku
	$UI/Panel.visible = false

func _on_spawn_timer_timeout():
	var target = target_scene.instantiate()
	target.position = Vector2(
		randf_range(SPAWN_MIN_X, SPAWN_MAX_X),
		randf_range(SPAWN_MIN_Y, SPAWN_MAX_Y)
	)
	add_child(target)
	spawn_timer.wait_time = randf_range(MIN_SPAWN_DELAY, MAX_SPAWN_DELAY)

func register_hit(reaction_time: float):
	reaction_times.append(reaction_time)
	hits += 1

func _on_session_timer_timeout():
	spawn_timer.stop()
	show_results()

func show_results():
	var average = 0.0
	if reaction_times.size() > 0:
		for t in reaction_times:
			average += t
		average /= reaction_times.size()
	
	# Wyświetlenie wyników na ekranie (UI)
	$UI/Panel/LabelSredni.text = "Średni czas reakcji: %.2f s" % average
	$UI/Panel/LabelTrafienia.text = "Trafienia: %d" % hits
	
	if average < WIN_THRESHOLD:
		$UI/Panel/LabelWynik.text = "WYGRAŁEŚ!"
		$UI/Panel/LabelWynik.modulate = Color.GREEN
	else:
		$UI/Panel/LabelWynik.text = "PRZEGRAŁEŚ!"
		$UI/Panel/LabelWynik.modulate = Color.RED
	
	$UI/Panel.visible = true

# Restart gry klawiszem ESC
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().reload_current_scene()
