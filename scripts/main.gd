class_name Main
extends Node2D

# ===========================================================
# STAŁE – żadnych magicznych liczb w kodzie
# ===========================================================
const SESSION_DURATION: float        = 30.0
const SPAWN_MIN_X: float             = 100.0
const SPAWN_MAX_X: float             = 1180.0
const SPAWN_MIN_Y: float             = 100.0
const SPAWN_MAX_Y: float             = 620.0
const WIN_THRESHOLD: float           = 1.0
const MIN_SCORE_FOR_WIN: int         = 80
const POINTS_PER_HIT: int            = 10
const POINTS_BONUS_FAST: int         = 5
const FAST_REACTION_THRESHOLD: float = 0.5

# ===========================================================
# WĘZŁY – @onready z pełnym typowaniem
# ===========================================================
@onready var spawn_timer: Timer     = $SpawnTimer
@onready var session_timer: Timer   = $SessionTimer
@onready var panel_wynikow: Panel   = $UI/Panel
@onready var label_sredni: Label    = $UI/Panel/LabelSredni
@onready var label_trafienia: Label = $UI/Panel/LabelTrafienia
@onready var label_wynik: Label     = $UI/Panel/LabelWynik
@onready var label_punkty: Label    = $UI/Panel/LabelPunkty
@onready var menu: CanvasLayer      = $Menu
@onready var btn_start: Button      = $Menu/VBoxMenuContainer/Start
@onready var btn_restart: Button    = $Menu/VBoxMenuContainer/Restart
@onready var label_tytul: Label     = %LabelTytul   # S3 – Unique Name

# ===========================================================
# ZASOBY (ścieżki zaktualizowane po S5)
# ===========================================================
var is_activity_active: bool  = false
var rotational_active: bool   = false

var target_scene: PackedScene   = preload("res://scenes/target.tscn")
var slice_scene: PackedScene    = preload("res://scenes/SliceActivity.tscn")
var reaction_scene: PackedScene = preload("res://scenes/ReactionClickActivity.tscn")
var circle_scene: PackedScene   = preload("res://scenes/CircleSpinActivity.tscn")

# ===========================================================
# STRUKTURA: 4 SEKCJE (losowa kolejność, jeden ciągły loop)
# ===========================================================
enum ActivityType { TARGET, SLICE, REACTION, CIRCLE }

var section_order: Array[ActivityType]   = []
var section_durations: Array[float]      = []
var cumulative_section_ends: Array[float] = []
var current_section: int    = 0
var section_start_time: float = 0.0

# ===========================================================
# DANE SESJI
# ===========================================================
var reaction_times: Array[float] = []
var hits: int        = 0
var score: int       = 0
var repetitions: int = 0   # W2 – liczba powtórzeń (F11)
var session_active: bool = false

# ===========================================================
# Ekran "Moje postępy"
# ===========================================================
var btn_progress: Button
var progress_screen: CanvasLayer
var progress_panel: Panel
var progress_list: VBoxContainer
var btn_close_progress: Button

# ===========================================================
# Ekran wyboru trudności
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
	session_timer.wait_time = SESSION_DURATION
	session_timer.one_shot  = true
	session_timer.autostart = false
	spawn_timer.autostart   = false

	panel_wynikow.visible = false
	menu.visible          = true

	btn_start.pressed.connect(_on_start_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)

	btn_progress = Button.new()
	btn_progress.text = "📊  Moje postępy"
	btn_progress.custom_minimum_size = Vector2(240, 60)
	$Menu/VBoxMenuContainer.add_child(btn_progress)
	btn_progress.pressed.connect(_on_progress_pressed)

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
	_show_difficulty_screen()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _reset_session_data() -> void:
	reaction_times.clear()
	hits        = 0
	score       = 0
	repetitions = 0
	panel_wynikow.visible = false

# ===========================================================
# GENEROWANIE 4 SEKCJI (losowa kolejność + min 10% każda)
# ===========================================================
func _generate_sections() -> void:
	section_order.clear()
	section_durations.clear()
	cumulative_section_ends.clear()

	var types: Array[ActivityType] = [ActivityType.TARGET, ActivityType.SLICE, ActivityType.REACTION, ActivityType.CIRCLE]
	types.shuffle()
	section_order = types

	var min_section: float = SESSION_DURATION * 0.10
	var remaining: float   = SESSION_DURATION - 4.0 * min_section

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
		var dur := min_section + extras[i]
		section_durations.append(dur)
		cum += dur
		cumulative_section_ends.append(cum)

	print("[Rehagame] Sekcje: ", section_order, " czasy: ", section_durations)

# ===========================================================
# SPAWN – jeden ciągły loop
# ===========================================================
func _on_spawn_timer_timeout() -> void:
	if not session_active:
		return

	_check_and_advance_section()

	if current_section >= 4:
		return

	var act_type: ActivityType = section_order[current_section]
	var activity: Node2D       = null
	var is_rot: bool           = false

	match act_type:
		ActivityType.TARGET:
			var target: Node = target_scene.instantiate()
			target.position = Vector2(
				randf_range(SPAWN_MIN_X, SPAWN_MAX_X),
				randf_range(SPAWN_MIN_Y, SPAWN_MAX_Y)
			)
			target.set_main(self)
			add_child(target)
			is_activity_active = true
			get_tree().create_timer(0.3).timeout.connect(func(): is_activity_active = false)
		ActivityType.SLICE:
			if is_activity_active or rotational_active:
				return
			activity = slice_scene.instantiate()
			if activity:
				activity.max_time = DifficultyManager.get_base_timeout() * randf_range(0.75, 1.35)
		ActivityType.REACTION:
			if is_activity_active or rotational_active:
				return
			activity = reaction_scene.instantiate()
			if activity:
				activity.max_time = DifficultyManager.get_base_timeout() * randf_range(0.7, 1.3)
		ActivityType.CIRCLE:
			if is_activity_active or rotational_active:
				return
			activity = circle_scene.instantiate()
			is_rot = true
			rotational_active = true
			if activity:
				activity.max_time = DifficultyManager.get_base_timeout() * randf_range(0.8, 1.4)

	if activity == null:
		return

	add_child(activity)
	is_activity_active = true

	# K4: usunięto .bind(activity) – parametr _activity był nieużywany i odwracał kolejność
	if is_rot:
		activity.activity_completed.connect(_on_rotational_completed)
	else:
		activity.activity_completed.connect(_on_activity_completed)

# ===========================================================
# REJESTROWANIE TRAFIEŃ (wywoływane przez Target)
# ===========================================================
func register_hit(reaction_time: float) -> void:
	reaction_times.append(reaction_time)
	hits        += 1
	score       += POINTS_PER_HIT
	repetitions += 1
	if reaction_time < FAST_REACTION_THRESHOLD:
		score += POINTS_BONUS_FAST
	SoundManager.play_hit()   # K1
	_check_and_advance_section()

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

	if (hits > 0 and average < WIN_THRESHOLD) or score >= MIN_SCORE_FOR_WIN:
		label_wynik.text     = "WYGRAŁEŚ!"
		label_wynik.modulate = Color.GREEN
		SoundManager.play_win()    # K1
	else:
		label_wynik.text     = "PRZEGRAŁEŚ!"
		label_wynik.modulate = Color.RED
		SoundManager.play_lose()   # K1

	panel_wynikow.visible = true
	menu.visible          = true
	btn_start.visible     = false

	_save_session(average)

func _calculate_average() -> float:
	if reaction_times.is_empty():
		return 0.0
	var total: float = 0.0
	for t: float in reaction_times:
		total += t
	return total / reaction_times.size()

# ===========================================================
# ZAPIS DO JSON (Etap 6 – F9, F11)
# ===========================================================
func _save_session(average: float) -> void:
	var session: Dictionary = {
		"date":             Time.get_datetime_string_from_system(),
		"hits":             hits,
		"score":            score,
		"repetitions":      repetitions,
		"average_reaction": snappedf(average, 0.01),
		"duration_s":       SESSION_DURATION
	}

	var sessions: Array = _load_sessions()
	sessions.append(session)

	var file := FileAccess.open("user://sessions.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(sessions, "\t"))
		file.close()
		print("✅ Sesja zapisana do user://sessions.json")
	else:
		push_warning("Main: nie można zapisać sesji – " + error_string(FileAccess.get_open_error()))

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
# WEJŚCIE – pauza ESC
# ===========================================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and session_active:
		session_active = false
		spawn_timer.stop()
		session_timer.stop()
		menu.visible        = true
		btn_start.visible   = true
		btn_restart.visible = true
		if progress_screen:
			progress_screen.visible = false
		if difficulty_screen:
			difficulty_screen.visible = false

# ===========================================================
# EKRAN "MOJE POSTĘPY"
# ===========================================================
func _create_progress_screen() -> void:
	progress_screen = CanvasLayer.new()
	progress_screen.name = "ProgressScreen"   # K2: usunięto \n
	progress_screen.visible = false
	add_child(progress_screen)

	progress_panel = Panel.new()
	progress_panel.anchors_preset    = 8
	progress_panel.anchor_left       = 0.5
	progress_panel.anchor_top        = 0.5
	progress_panel.anchor_right      = 0.5
	progress_panel.anchor_bottom     = 0.5
	progress_panel.offset_left       = -320.0
	progress_panel.offset_top        = -220.0
	progress_panel.offset_right      = 320.0
	progress_panel.offset_bottom     = 220.0
	progress_panel.grow_horizontal   = Control.GROW_DIRECTION_BOTH
	progress_panel.grow_vertical     = Control.GROW_DIRECTION_BOTH
	progress_panel.modulate          = Color(0.95, 0.95, 0.98, 1)
	progress_screen.add_child(progress_panel)

	var title := Label.new()
	title.text                   = "📊 Moje postępy – historia treningów"
	title.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	title.set("theme_override_font_sizes/font_size", 26)
	title.modulate               = Color(0.1, 0.1, 0.2, 1)
	title.offset_top             = 8
	title.offset_bottom          = 45
	title.anchors_preset         = 10
	progress_panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.anchors_preset  = 15
	scroll.anchor_left     = 0.04
	scroll.anchor_top      = 0.18
	scroll.anchor_right    = 0.96
	scroll.anchor_bottom   = 0.82
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical   = Control.GROW_DIRECTION_BOTH
	progress_panel.add_child(scroll)

	progress_list = VBoxContainer.new()
	progress_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_list.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	progress_list.add_theme_constant_override("separation", 8)
	scroll.add_child(progress_list)

	var btn_box := HBoxContainer.new()
	btn_box.anchors_preset  = 12
	btn_box.anchor_left     = 0.1
	btn_box.anchor_top      = 0.85
	btn_box.anchor_right    = 0.9
	btn_box.anchor_bottom   = 0.96
	btn_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_box.grow_vertical   = Control.GROW_DIRECTION_BOTH
	btn_box.add_theme_constant_override("separation", 20)
	progress_panel.add_child(btn_box)

	btn_close_progress = Button.new()
	btn_close_progress.text = "Zamknij"
	btn_close_progress.custom_minimum_size = Vector2(130, 45)
	btn_close_progress.set("theme_override_font_sizes/font_size", 18)
	btn_close_progress.pressed.connect(_on_close_progress_pressed)
	btn_box.add_child(btn_close_progress)

	var btn_clear := Button.new()
	btn_clear.text = "🗑 Wyczyść historię"
	btn_clear.custom_minimum_size = Vector2(170, 45)
	btn_clear.set("theme_override_font_sizes/font_size", 18)
	btn_clear.pressed.connect(_on_clear_progress_pressed)
	btn_box.add_child(btn_clear)

func _style_ui() -> void:
	label_tytul.set("theme_override_font_sizes/font_size", 32)   # S3
	label_tytul.modulate = Color.WHITE

	for lbl in [label_sredni, label_trafienia, label_punkty, label_wynik]:
		if lbl:
			lbl.set("theme_override_font_sizes/font_size", 20)
			lbl.modulate = Color(0.1, 0.1, 0.15, 1)

	for btn in [btn_start, btn_restart, btn_progress, btn_reset_adaptive]:
		if btn:
			btn.set("theme_override_font_sizes/font_size", 22)
			btn.modulate = Color.WHITE

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
		var sorted := sessions.duplicate()
		sorted.reverse()
		var to_show: Array = sorted.slice(0, 12) if sorted.size() > 12 else sorted

		for s in to_show:
			var entry := Label.new()
			var date_str: String = String(s.get("date", "brak daty")).substr(0, 16)
			var rt: float   = float(s.get("average_reaction", 0.0))
			var h: int      = int(s.get("hits", 0))
			var sc: int     = int(s.get("score", 0))
			var reps: int   = int(s.get("repetitions", 0))   # W2
			var is_win: bool = (rt < WIN_THRESHOLD and h > 0) or (sc >= MIN_SCORE_FOR_WIN)
			var res_str: String = "✅ WYGRANA" if is_win else "❌ PRZEGRANA"

			entry.text = "%s  |  RT: %.2f s  |  Traf.: %d  |  Powt.: %d  |  Pkt: %d  |  %s" % [date_str, rt, h, reps, sc, res_str]
			entry.set("theme_override_font_sizes/font_size", 15)
			entry.modulate = Color(0.2, 0.6, 0.3, 1) if is_win else Color(0.7, 0.3, 0.3, 1)
			progress_list.add_child(entry)

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
	_show_progress()

# ===========================================================
# HANDLERY AKTYWNOŚCI – K4/K5/S4
# Sygnał activity_completed(success, reaction_time) – poprawna sygnatura
# ===========================================================
func _on_rotational_completed(success: bool, reaction_time: float) -> void:
	rotational_active  = false
	is_activity_active = false
	repetitions += 1
	if success:
		score += 25
		reaction_times.append(reaction_time)
		DifficultyManager.report_reaction_time(reaction_time)
		SoundManager.play_hit()
	_check_and_advance_section()
	get_tree().create_timer(0.35).timeout.connect(_on_spawn_timer_timeout)

func _on_activity_completed(success: bool, reaction_time: float) -> void:
	is_activity_active = false
	repetitions += 1
	if success:
		score += 10
		reaction_times.append(reaction_time)
		DifficultyManager.report_reaction_time(reaction_time)
		SoundManager.play_hit()
	_check_and_advance_section()
	get_tree().create_timer(0.35).timeout.connect(_on_spawn_timer_timeout)

# ===========================================================
# ZMIANA SEKCJI
# ===========================================================
func _check_and_advance_section() -> void:
	if current_section >= 3:
		return
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - section_start_time
	if elapsed >= cumulative_section_ends[current_section]:
		current_section += 1
		print("[Rehagame] Sekcja ", current_section, " → ", section_order[current_section] if current_section < 4 else "KONIEC")

# ===========================================================
# EKRAN WYBORU TRUDNOŚCI
# ===========================================================
func _create_difficulty_screen() -> void:
	difficulty_screen = CanvasLayer.new()
	difficulty_screen.name    = "DifficultyScreen"
	difficulty_screen.visible = false
	add_child(difficulty_screen)

	difficulty_panel = Panel.new()
	difficulty_panel.anchors_preset  = 8
	difficulty_panel.anchor_left     = 0.5
	difficulty_panel.anchor_top      = 0.5
	difficulty_panel.anchor_right    = 0.5
	difficulty_panel.anchor_bottom   = 0.5
	difficulty_panel.offset_left     = -250.0
	difficulty_panel.offset_top      = -180.0
	difficulty_panel.offset_right    = 250.0
	difficulty_panel.offset_bottom   = 180.0
	difficulty_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	difficulty_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	difficulty_panel.modulate        = Color(0.95, 0.95, 0.98, 1)
	difficulty_screen.add_child(difficulty_panel)

	var title := Label.new()
	title.text               = "🎯 Wybierz poziom trudności"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set("theme_override_font_sizes/font_size", 28)
	title.modulate           = Color(0.1, 0.1, 0.2, 1)
	title.offset_top         = 10
	title.offset_bottom      = 50
	title.anchors_preset     = 10
	difficulty_panel.add_child(title)

	var btn_box := VBoxContainer.new()
	btn_box.anchors_preset  = 15
	btn_box.anchor_left     = 0.1
	btn_box.anchor_top      = 0.25
	btn_box.anchor_right    = 0.9
	btn_box.anchor_bottom   = 0.85
	btn_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_box.grow_vertical   = Control.GROW_DIRECTION_BOTH
	btn_box.add_theme_constant_override("separation", 12)
	difficulty_panel.add_child(btn_box)

	btn_easy = Button.new()
	btn_easy.text = "🟢 EASY - Łatwy (timeout 2.0s)"   # W5
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

	_generate_sections()
	section_start_time = Time.get_ticks_msec() / 1000.0
	current_section    = 0

	session_timer.start()
	spawn_timer.start(0.6)
	session_active = true
	if difficulty_screen:
		difficulty_screen.visible = false

func _on_reset_adaptive_pressed() -> void:
	DifficultyManager.reset_adaptive()
	var notif := Label.new()
	notif.text = "✅ Adaptive zresetowany do bazowego timeoutu 1.0s"
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.set("theme_override_font_sizes/font_size", 16)
	notif.modulate   = Color(0.2, 0.8, 0.2, 1)
	notif.offset_top = 80
	$Menu.add_child(notif)
	get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(notif): notif.queue_free())
