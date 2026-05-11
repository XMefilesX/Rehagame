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
const MIN_SCORE_FOR_WIN: int   = 80  # Alternatywny próg punktowy (wymaganie PDF)
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
@onready var btn_start: Button       = $Menu/VBoxMenuContainer/Start
@onready var btn_restart: Button     = $Menu/VBoxMenuContainer/Restart

# ===========================================================
# ZASOBY
# ===========================================================
# ZASOBY
var is_activity_active: bool = false
var target_scene: PackedScene = preload("res://target.tscn")
var slice_scene: PackedScene = preload("res://SliceActivity.tscn")
var reaction_scene: PackedScene = preload("res://ReactionClickActivity.tscn")
var circle_scene: PackedScene = preload("res://CircleSpinActivity.tscn")

var rotational_active: bool = false
var current_spawn_timer: Timer

# ===========================================================
# NOWA STRUKTURA: 4 SEKCJE (losowa kolejność)
# ===========================================================
enum ActivityType { TARGET, SLICE, REACTION, CIRCLE }

var section_order: Array[ActivityType] = []
var section_durations: Array[float] = []
var cumulative_section_ends: Array[float] = []
var current_section: int = 0
var section_start_time: float = 0.0

# ===========================================================
# DANE SESJI
# ===========================================================
var reaction_times: Array[float] = []
var hits: int   = 0
var score: int  = 0
var session_active: bool = false

# ===========================================================
# NOWE: dla ekranu "Moje postępy" (wymaganie PDF Etap 6)
# ===========================================================
var btn_progress: Button
var progress_screen: CanvasLayer
var progress_panel: Panel
var progress_list: VBoxContainer
var btn_close_progress: Button

# ===========================================================
# NOWE: ekran wyboru trudności + reset adaptive (NAPRAW A)
# ===========================================================
var btn_reset_adaptive: Button
var difficulty_screen: CanvasLayer
var difficulty_panel: Panel
var btn_easy: Button
var btn_normal: Button
var btn_hard: Button
var btn_adaptive: Button

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

	# Dodaj przycisk "Moje postępy" do menu (tekstowy ekran postępów – wymaganie PDF)
	btn_progress = Button.new()
	btn_progress.text = "📊  Moje postępy"
	btn_progress.custom_minimum_size = Vector2(240, 60)
	$Menu/VBoxMenuContainer.add_child(btn_progress)
	btn_progress.pressed.connect(_on_progress_pressed)

	# NAPRAW A: dodaj przycisk resetu adaptacyjnego
	btn_reset_adaptive = Button.new()
	btn_reset_adaptive.text = "🔄 Reset Adaptive"
	btn_reset_adaptive.custom_minimum_size = Vector2(240, 60)
	$Menu/VBoxMenuContainer.add_child(btn_reset_adaptive)
	btn_reset_adaptive.pressed.connect(_on_reset_adaptive_pressed)

	_create_progress_screen()
	_create_difficulty_screen()
	_style_ui()

# ===========================================================
# MENU
# ===========================================================
func _on_start_pressed() -> void:
	if progress_screen:
		progress_screen.visible = false
	menu.visible = false
	# NAPRAW A: zamiast natychmiastowego startu – pokaż ekran wyboru trudności
	_show_difficulty_screen()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _reset_session_data() -> void:
	reaction_times.clear()
	hits  = 0
	score = 0
	panel_wynikow.visible = false

# ===========================================================
# NOWA LOGIKA: GENEROWANIE 4 SEKCJI (losowa kolejność + min 10% każda)
# ===========================================================
func _generate_sections() -> void:
	section_order.clear()
	section_durations.clear()
	cumulative_section_ends.clear()
	
	var types: Array[ActivityType] = [ActivityType.TARGET, ActivityType.SLICE, ActivityType.REACTION, ActivityType.CIRCLE]
	types.shuffle()
	section_order = types
	
	# Każda sekcja ≥ 10% rozgrywki (min 3s przy 30s)
	var min_section: float = SESSION_DURATION * 0.10
	var remaining: float = SESSION_DURATION - 4 * min_section
	
	var extras: Array[float] = []
	for i in 4:
		extras.append(randf_range(0.0, remaining * 0.6))
	
	var sum_extra: float = 0.0
	for e in extras:
		sum_extra += e
	if sum_extra > 0.001:
		for i in 4:
			extras[i] = extras[i] / sum_extra * remaining
	
	var cum: float = 0.0
	for i in 4:
		var dur = min_section + extras[i]
		section_durations.append(dur)
		cum += dur
		cumulative_section_ends.append(cum)
	
	print("[Rehagame] Wygenerowano 4 sekcje (losowa kolejność): ", section_order)
	print("[Rehagame] Czasy sekcji: ", section_durations, " (suma: ", cum, ")")

# ===========================================================
# SPAWN CELÓW – TERAZ ZGODNIE Z BIEŻĄCĄ SEKCJĄ (tylko 1 typ na sekcję)
# ===========================================================
func _on_spawn_timer_timeout() -> void:
	if not session_active or rotational_active or is_activity_active:
		return

	if current_section >= 4:
		return

	var act_type: ActivityType = section_order[current_section]
	var activity = null
	var is_rot: bool = false

	match act_type:
		ActivityType.TARGET:
			var target = target_scene.instantiate()
			add_child(target)
			is_activity_active = true
			get_tree().create_timer(1.5).timeout.connect(func(): is_activity_active = false)
			return
		ActivityType.SLICE:
			activity = slice_scene.instantiate()
			# Losowa długość aktywności (skalowanie procentowe względem trudności)
			if activity:
				activity.max_time = DifficultyManager.get_base_timeout() * randf_range(0.75, 1.35)
		ActivityType.REACTION:
			activity = reaction_scene.instantiate()
			if activity:
				activity.max_time = DifficultyManager.get_base_timeout() * randf_range(0.7, 1.3)
		ActivityType.CIRCLE:
			activity = circle_scene.instantiate()
			is_rot = true
			rotational_active = true
			if activity:
				activity.max_time = DifficultyManager.get_base_timeout() * randf_range(0.8, 1.4)

	if activity == null:
		return

	add_child(activity)
	is_activity_active = true

	if is_rot:
		activity.activity_completed.connect(_on_rotational_completed.bind(activity))
	else:
		activity.activity_completed.connect(_on_activity_completed.bind(activity))

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
	if progress_screen:
		progress_screen.visible = false
	var average: float = _calculate_average()

	label_sredni.text    = "Średni czas reakcji: %.2f s" % average
	label_trafienia.text = "Trafienia: %d" % hits
	label_punkty.text    = "Wynik: %d pkt" % score

	# Warunek wygranej: niski czas reakcji LUB wysoki wynik punktowy (zgodne z PDF)
	if (hits > 0 and average < WIN_THRESHOLD) or score >= MIN_SCORE_FOR_WIN:
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
		"date": Time.get_datetime_string_from_system(),
		"hits": hits,
		"score": score,
		"average_reaction": snappedf(average, 0.01),
		"duration_s": SESSION_DURATION
	}
	
	var sessions: Array = _load_sessions()
	sessions.append(session)
	
	var file := FileAccess.open("user://sessions.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(sessions, "\t"))
		file.close()
		print("✅ Sesja zapisana do user://sessions.json")
	else:
		var err := FileAccess.get_open_error()
		push_warning("Main: nie można zapisać sesji – " + error_string(err))

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
		if progress_screen:
			progress_screen.visible = false
		if difficulty_screen:
			difficulty_screen.visible = false

# ===========================================================
# NOWE FUNKCJE: EKRAN "MOJE POSTĘPY" (wymaganie PDF – tekstowa lista sesji)
# ===========================================================
func _create_progress_screen() -> void:
	progress_screen = CanvasLayer.new()
	progress_screen.name = "ProgressScreen"
	progress_screen.visible = false
	add_child(progress_screen)
	
	progress_panel = Panel.new()
	progress_panel.anchors_preset = 8
	progress_panel.anchor_left = 0.5
	progress_panel.anchor_top = 0.5
	progress_panel.anchor_right = 0.5
	progress_panel.anchor_bottom = 0.5
	progress_panel.offset_left = -320.0
	progress_panel.offset_top = -220.0
	progress_panel.offset_right = 320.0
	progress_panel.offset_bottom = 220.0
	progress_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	progress_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# Jasne tło panelu dla kontrastu
	progress_panel.modulate = Color(0.95, 0.95, 0.98, 1)
	progress_screen.add_child(progress_panel)
	
	# Tytuł ekranu
	var title := Label.new()
	title.text = "📊 Moje postępy – historia treningów"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set("theme_override_font_sizes/font_size", 26)
	title.modulate = Color(0.1, 0.1, 0.2, 1)
	title.offset_top = 8
	title.offset_bottom = 45
	title.anchors_preset = 10
	progress_panel.add_child(title)
	
	# Kontener przewijany z listą
	var scroll := ScrollContainer.new()
	scroll.anchors_preset = 15
	scroll.anchor_left = 0.04
	scroll.anchor_top = 0.18
	scroll.anchor_right = 0.96
	scroll.anchor_bottom = 0.82
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	progress_panel.add_child(scroll)
	
	progress_list = VBoxContainer.new()
	progress_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	progress_list.add_theme_constant_override("separation", 8)
	scroll.add_child(progress_list)
	
	# Przyciski akcji na dole
	var btn_box := HBoxContainer.new()
	btn_box.anchors_preset = 12
	btn_box.anchor_left = 0.1
	btn_box.anchor_top = 0.85
	btn_box.anchor_right = 0.9
	btn_box.anchor_bottom = 0.96
	btn_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	btn_box.add_theme_constant_override("separation", 20)
	progress_panel.add_child(btn_box)
	
	btn_close_progress = Button.new()
	btn_close_progress.text = "Zamknij"
	btn_close_progress.custom_minimum_size = Vector2(130, 45)
	btn_close_progress.set("theme_override_font_sizes/font_size", 18)
	btn_close_progress.pressed.connect(_on_close_progress_pressed)
	btn_box.add_child(btn_close_progress)
	
	var btn_clear = Button.new()
	btn_clear.text = "🗑 Wyczyść historię"
	btn_clear.custom_minimum_size = Vector2(170, 45)
	btn_clear.set("theme_override_font_sizes/font_size", 18)
	btn_clear.pressed.connect(_on_clear_progress_pressed)
	btn_box.add_child(btn_clear)

func _style_ui() -> void:
	# Wysoki kontrast + duże czcionki dla dostępności (zgodne z PDF)
	# Tytuł główny
	if has_node("Tlo/LabelTytul"):
		var tytul: Label = $Tlo/LabelTytul
		tytul.set("theme_override_font_sizes/font_size", 32)
		tytul.modulate = Color.WHITE
	
	# Etykiety w panelu wyników
	for lbl in [label_sredni, label_trafienia, label_punkty, label_wynik]:
		if lbl:
			lbl.set("theme_override_font_sizes/font_size", 20)
			lbl.modulate = Color(0.1, 0.1, 0.15, 1)  # ciemny tekst na jasnym panelu
	
	# Przyciski w menu (w tym nowy reset)
	for btn in [btn_start, btn_restart, btn_progress, btn_reset_adaptive]:
		if btn:
			btn.set("theme_override_font_sizes/font_size", 22)
			btn.modulate = Color.WHITE
	
	# Przyciski ekranu trudności
	for btn in [btn_easy, btn_normal, btn_hard, btn_adaptive]:
		if btn:
			btn.set("theme_override_font_sizes/font_size", 18)
			btn.modulate = Color.WHITE

func _on_progress_pressed() -> void:
	if progress_screen:
		progress_screen.visible = false
	menu.visible = false
	_show_progress()

func _show_progress() -> void:
	# Wyczyść starą listę
	for child in progress_list.get_children():
		child.queue_free()
	
	var sessions: Array = _load_sessions()
	if sessions.is_empty():
		var empty := Label.new()
		empty.text = "Brak zapisanych sesji treningowych.\nRozpocznij grę, aby zobaczyć swoje postępy!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.set("theme_override_font_sizes/font_size", 18)
		empty.modulate = Color(0.4, 0.4, 0.5, 1)
		progress_list.add_child(empty)
	else:
		# Najnowsze na górze (odwróć tablicę)
		var sorted := sessions.duplicate()
		sorted.reverse()
		var to_show := sorted.slice(0, 12) if sorted.size() > 12 else sorted
		
		for s in to_show:
			var entry := Label.new()
			var date_str: String = String(s.get("date", "brak daty")).substr(0, 16)
			var rt: float = float(s.get("average_reaction", 0.0))
			var h: int = int(s.get("hits", 0))
			var sc: int = int(s.get("score", 0))
			var is_win: bool = (rt < WIN_THRESHOLD and h > 0) or (sc >= MIN_SCORE_FOR_WIN)
			var res_str: String = "✅ WYGRANA" if is_win else "❌ PRZEGRANA"
			
			entry.text = "%s  |  RT: %.2f s  |  Trafienia: %d  |  Punkty: %d  |  %s" % [date_str, rt, h, sc, res_str]
			entry.set("theme_override_font_sizes/font_size", 15)
			entry.modulate = Color(0.2, 0.6, 0.3, 1) if is_win else Color(0.7, 0.3, 0.3, 1)
			progress_list.add_child(entry)
			
			# Separator
			var sep := HSeparator.new()
			sep.modulate = Color(0.7, 0.7, 0.75, 0.6)
			progress_list.add_child(sep)
	
	progress_screen.visible = true

func _on_close_progress_pressed() -> void:
	if progress_screen:
		progress_screen.visible = false
	menu.visible = true

func _on_clear_progress_pressed() -> void:
	var file := FileAccess.open("user://sessions.json", FileAccess.WRITE)
	if file:
		file.store_string("[]")
		file.close()
	# Odśwież widok
	_show_progress()

func _on_rotational_completed(_activity, success: bool) -> void:
	rotational_active = false
	is_activity_active = false
	if success:
		score += 25
	_check_and_advance_section()
	get_tree().create_timer(0.35).timeout.connect(_on_spawn_timer_timeout)

func _on_activity_completed(_activity, success: bool) -> void:
	is_activity_active = false
	if success:
		score += 10
		DifficultyManager.report_reaction_time(0.5)
	_check_and_advance_section()
	get_tree().create_timer(0.35).timeout.connect(_on_spawn_timer_timeout)

# ===========================================================
# SPRAWDZANIE I PRZEJŚCIE DO NASTĘPNEJ SEKCJI
# ===========================================================
func _check_and_advance_section() -> void:
	if current_section >= 3:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - section_start_time
	if elapsed >= cumulative_section_ends[current_section]:
		current_section += 1
		print("[Rehagame] Przejście do sekcji ", current_section, " typ: ", section_order[current_section] if current_section < 4 else "KONIEC")

# ===========================================================
# NAPRAW A: EKRAN WYBORU TRUDNOŚCI (po kliknięciu Start)
# ===========================================================
func _create_difficulty_screen() -> void:
	difficulty_screen = CanvasLayer.new()
	difficulty_screen.name = "DifficultyScreen"
	difficulty_screen.visible = false
	add_child(difficulty_screen)
	
	difficulty_panel = Panel.new()
	difficulty_panel.anchors_preset = 8
	difficulty_panel.anchor_left = 0.5
	difficulty_panel.anchor_top = 0.5
	difficulty_panel.anchor_right = 0.5
	difficulty_panel.anchor_bottom = 0.5
	difficulty_panel.offset_left = -250.0
	difficulty_panel.offset_top = -180.0
	difficulty_panel.offset_right = 250.0
	difficulty_panel.offset_bottom = 180.0
	difficulty_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	difficulty_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	difficulty_panel.modulate = Color(0.95, 0.95, 0.98, 1)
	difficulty_screen.add_child(difficulty_panel)
	
	var title := Label.new()
	title.text = "🎯 Wybierz poziom trudności"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set("theme_override_font_sizes/font_size", 28)
	title.modulate = Color(0.1, 0.1, 0.2, 1)
	title.offset_top = 10
	title.offset_bottom = 50
	title.anchors_preset = 10
	difficulty_panel.add_child(title)
	
	var btn_box := VBoxContainer.new()
	btn_box.anchors_preset = 15
	btn_box.anchor_left = 0.1
	btn_box.anchor_top = 0.25
	btn_box.anchor_right = 0.9
	btn_box.anchor_bottom = 0.85
	btn_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	btn_box.add_theme_constant_override("separation", 12)
	difficulty_panel.add_child(btn_box)
	
	btn_easy = Button.new()
	btn_easy.text = "🟢 EASY - Łatwy (timeout 1.0s)"
	btn_easy.custom_minimum_size = Vector2(420, 55)
	btn_easy.set("theme_override_font_sizes/font_size", 18)
	btn_easy.pressed.connect(_on_difficulty_selected.bind(DifficultyManager.Difficulty.EASY))
	btn_box.add_child(btn_easy)
	
	btn_normal = Button.new()
	btn_normal.text = "🟡 NORMAL - Normalny (timeout 1.0s)"
	btn_normal.custom_minimum_size = Vector2(420, 55)
	btn_normal.set("theme_override_font_sizes/font_size", 18)
	btn_normal.pressed.connect(_on_difficulty_selected.bind(DifficultyManager.Difficulty.NORMAL))
	btn_box.add_child(btn_normal)
	
	btn_hard = Button.new()
	btn_hard.text = "🔴 HARD - Trudny (timeout 0.7s)"
	btn_hard.custom_minimum_size = Vector2(420, 55)
	btn_hard.set("theme_override_font_sizes/font_size", 18)
	btn_hard.pressed.connect(_on_difficulty_selected.bind(DifficultyManager.Difficulty.HARD))
	btn_box.add_child(btn_hard)
	
	btn_adaptive = Button.new()
	btn_adaptive.text = "🔵 ADAPTIVE - Adaptacyjny (uczy się z Twoich reakcji!)"
	btn_adaptive.custom_minimum_size = Vector2(420, 55)
	btn_adaptive.set("theme_override_font_sizes/font_size", 18)
	btn_adaptive.pressed.connect(_on_difficulty_selected.bind(DifficultyManager.Difficulty.ADAPTIVE))
	btn_box.add_child(btn_adaptive)

func _show_difficulty_screen() -> void:
	if difficulty_screen:
		difficulty_screen.visible = true

func _on_difficulty_selected(diff: DifficultyManager.Difficulty) -> void:
	DifficultyManager.set_difficulty(diff)
	if diff == DifficultyManager.Difficulty.ADAPTIVE:
		DifficultyManager.reset_adaptive()
	_reset_session_data()
	
	# === NOWA LOGIKA 4 SEKCJI ===
	_generate_sections()
	section_start_time = Time.get_ticks_msec() / 1000.0
	current_section = 0
	
	session_timer.start()
	spawn_timer.start(0.6)   # pierwsze spawn szybkie
	session_active = true
	if difficulty_screen:
		difficulty_screen.visible = false

func _on_reset_adaptive_pressed() -> void:
	DifficultyManager.reset_adaptive()
	# Prosty komunikat powiadomienia
	var notif := Label.new()
	notif.text = "✅ Adaptive zresetowany do bazowego timeoutu 1.0s"
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.set("theme_override_font_sizes/font_size", 16)
	notif.modulate = Color(0.2, 0.8, 0.2, 1)
	notif.offset_top = 80
	$Menu.add_child(notif)
	get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(notif): notif.queue_free())
