class_name Main
extends Node2D

# ===========================================================
# STAŁE – żadnych magicznych liczb w kodzie
# ===========================================================
const SESSION_DURATION: float  = 30.0
const MIN_SPAWN_DELAY: float   = 0.8
const MAX_SPAWN_DELAY: float   = 1.5
const SPAWN_MIN_X: float       = 100.0
const SPAWN_MAX_X: float       = 1180.0
const SPAWN_MIN_Y: float       = 100.0
const SPAWN_MAX_Y: float       = 620.0
# Próg średniego czasu reakcji decydujący o wygranej (sekundy)
const WIN_THRESHOLD: float     = 1.0
# Punkty za trafienie; bonus za szybką reakcję (poniżej 0.5 s)
const POINTS_PER_HIT: int      = 10
const POINTS_BONUS_FAST: int   = 5
const FAST_REACTION_THRESHOLD: float = 0.5

# ===========================================================
# WĘZŁY – cache @onready z pełnym typowaniem
# ===========================================================
@onready var spawn_timer: Timer      = $SpawnTimer
@onready var session_timer: Timer    = $SessionTimer
@onready var panel_wynikow: Panel    = $UI/Panel
@onready var label_sredni: Label     = $UI/Panel/LabelSredni
@onready var label_trafienia: Label  = $UI/Panel/LabelTrafienia
@onready var label_wynik: Label      = $UI/Panel/LabelWynik
@onready var label_punkty: Label     = $UI/Panel/LabelPunkty
@onready var menu: CanvasLayer       = $Menu
@onready var btn_start: Button       = $Menu/Start
@onready var btn_restart: Button     = $Menu/Restart

# ===========================================================
# ZASOBY
# ===========================================================
var target_scene: PackedScene = preload("res://target.tscn")

# ===========================================================
# DANE SESJI
# ===========================================================
var reaction_times: Array[float] = []
var hits: int   = 0
var score: int  = 0
var session_active: bool = false

# ===========================================================
# CYKL ŻYCIA
# ===========================================================
func _ready() -> void:
	# Konfiguracja timerów (właściwości ustawiane z kodu dla pewności)
	session_timer.wait_time = SESSION_DURATION
	session_timer.one_shot  = true
	# Timery NIE startują automatycznie – gracz musi kliknąć Start
	session_timer.autostart = false
	spawn_timer.autostart   = false

	# Stan początkowy UI
	panel_wynikow.visible = false
	menu.visible          = true

	# Podłącz sygnały przycisków menu
	btn_start.pressed.connect(_on_start_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)

# ===========================================================
# MENU
# ===========================================================
func _on_start_pressed() -> void:
	menu.visible = false
	_reset_session_data()
	session_timer.start()
	spawn_timer.start(MIN_SPAWN_DELAY)
	session_active = true

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _reset_session_data() -> void:
	reaction_times.clear()
	hits  = 0
	score = 0
	panel_wynikow.visible = false

# ===========================================================
# SPAWN CELÓW
# ===========================================================
func _on_spawn_timer_timeout() -> void:
	if not session_active:
		return
	_spawn_target()
	spawn_timer.start(randf_range(MIN_SPAWN_DELAY, MAX_SPAWN_DELAY))

func _spawn_target() -> void:
	var target: Target = target_scene.instantiate()
	target.position = Vector2(
		randf_range(SPAWN_MIN_X, SPAWN_MAX_X),
		randf_range(SPAWN_MIN_Y, SPAWN_MAX_Y)
	)
	target.set_main(self)   # Wstrzyknięcie referencji – rozwiązuje Błąd #2
	add_child(target)

# ===========================================================
# REJESTROWANIE TRAFIEŃ (wywoływane przez Target)
# ===========================================================
func register_hit(reaction_time: float) -> void:
	reaction_times.append(reaction_time)
	hits += 1
	# System punktów: base + bonus za szybką reakcję (Poprawka #10)
	score += POINTS_PER_HIT
	if reaction_time < FAST_REACTION_THRESHOLD:
		score += POINTS_BONUS_FAST

# ===========================================================
# KONIEC SESJI
# ===========================================================
func _on_session_timer_timeout() -> void:
	session_active = false
	spawn_timer.stop()
	_show_results()

func _show_results() -> void:
	var average: float = _calculate_average()

	label_sredni.text    = "Średni czas reakcji: %.2f s" % average
	label_trafienia.text = "Trafienia: %d" % hits
	label_punkty.text    = "Wynik: %d pkt" % score

	if hits > 0 and average < WIN_THRESHOLD:
		label_wynik.text     = "WYGRAŁEŚ!"
		label_wynik.modulate = Color.GREEN
	else:
		label_wynik.text     = "PRZEGRAŁEŚ!"
		label_wynik.modulate = Color.RED

	panel_wynikow.visible = true
	menu.visible          = true
	btn_start.visible     = false   # Tylko Restart po zakończeniu sesji

	_save_session(average)

func _calculate_average() -> float:
	if reaction_times.is_empty():
		return 0.0
	var total: float = 0.0
	for t: float in reaction_times:
		total += t
	return total / reaction_times.size()

# ===========================================================
# ZAPIS WYNIKÓW DO PLIKU JSON (Poprawka #4 – wymaganie PDF)
# ===========================================================
func _save_session(average: float) -> void:
	var session: Dictionary = {
		"date":              Time.get_datetime_string_from_system(),
		"hits":              hits,
		"score":             score,
		"average_reaction":  snappedf(average, 0.01),
		"duration_s":        SESSION_DURATION
	}

	var sessions: Array = _load_sessions()
	sessions.append(session)

	var file := FileAccess.open("user://sessions.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(sessions, "\t"))
		file.close()
	else:
		push_warning("Main: nie można zapisać sesji – " + FileAccess.get_open_error_description(FileAccess.get_open_error()))

func _load_sessions() -> Array:
	if not FileAccess.file_exists("user://sessions.json"):
		return []
	var file := FileAccess.open("user://sessions.json", FileAccess.READ)
	if not file:
		return []
	var content: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed is Array:
		return parsed
	return []

# ===========================================================
# WEJŚCIE – pauza przez ESC (Poprawka #14)
# ===========================================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and session_active:
		# Zatrzymaj sesję i pokaż menu pauzy
		session_active = false
		spawn_timer.stop()
		session_timer.stop()
		menu.visible = true
		btn_start.visible   = true
		btn_restart.visible = true
