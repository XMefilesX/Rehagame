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
# Dodatkowe elementy menu
# ===========================================================
var menu_bg: Panel
var label_subtitle: Label

# ===========================================================
# Ekran końca gry (zastępuje panel_wynikow)
# ===========================================================
var results_screen: CanvasLayer
var results_panel: Panel
var result_label_avg: Label
var result_label_hits: Label
var result_label_reps: Label
var result_label_score: Label
var result_label_stars: Label
var result_label_eval: Label

# ===========================================================
# HUD – bieżące dane sesji  (audit R4: brak HUD)
# ===========================================================
var hud_screen: CanvasLayer
var hud_label_time: Label
var hud_label_score: Label
var hud_label_activity: Label
var hud_label_adaptive: Label
var hud_hint_label: Label     # tutorial per sekcja (audit R6)
var hud_miss_label: Label     # feedback za pudło   (audit R5)

# ===========================================================
# CYKL ŻYCIA
# ===========================================================
func _ready() -> void:
	session_timer.wait_time = SESSION_DURATION
	session_timer.one_shot  = true
	session_timer.autostart = false
	spawn_timer.autostart   = false

	panel_wynikow.visible = false
	_create_menu_extras()
	_show_menu_animated()

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
	_create_results_screen()
	_create_hud()
	_apply_theme()
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

func _set_alpha(node: CanvasItem, a: float) -> void:
	var c := node.modulate
	c.a = a
	node.modulate = c

func _show_menu_animated() -> void:
	var vbox: Control = $Menu/VBoxMenuContainer
	_set_alpha(vbox,        0.0)
	_set_alpha(label_tytul, 0.0)
	if menu_bg:        _set_alpha(menu_bg, 0.0)
	if label_subtitle: _set_alpha(label_subtitle, 0.0)
	menu.visible = true
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(vbox,        "modulate:a", 1.0, 0.4).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label_tytul, "modulate:a", 1.0, 0.4).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if menu_bg:
		tween.tween_property(menu_bg,        "modulate:a", 1.0, 0.4).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if label_subtitle:
		tween.tween_property(label_subtitle, "modulate:a", 1.0, 0.4).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _create_menu_extras() -> void:
	# Ciemna karta za przyciskami menu
	menu_bg = Panel.new()
	menu_bg.anchor_left    = 0.5
	menu_bg.anchor_top     = 0.5
	menu_bg.anchor_right   = 0.5
	menu_bg.anchor_bottom  = 0.5
	menu_bg.offset_left    = -155.0
	menu_bg.offset_top     = -168.0
	menu_bg.offset_right   = 155.0
	menu_bg.offset_bottom  = 168.0
	menu_bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_bg.grow_vertical   = Control.GROW_DIRECTION_BOTH
	$Menu.add_child(menu_bg)
	$Menu.move_child(menu_bg, 0)  # za innymi elementami

	# Podtytuł pod tytułem głównym
	label_subtitle = Label.new()
	label_subtitle.text = "Trening refleksu i reakcji"
	label_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_subtitle.anchor_left   = 0.5
	label_subtitle.anchor_top    = 0.0
	label_subtitle.anchor_right  = 0.5
	label_subtitle.anchor_bottom = 0.0
	label_subtitle.offset_left   = -220.0
	label_subtitle.offset_top    = 84.0
	label_subtitle.offset_right  = 220.0
	label_subtitle.offset_bottom = 112.0
	label_subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	$Menu.add_child(label_subtitle)

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
			target.max_time = DifficultyManager.get_timeout_for("target")
			target.set_main(self)
			add_child(target)
			is_activity_active = true
			get_tree().create_timer(0.3).timeout.connect(func(): is_activity_active = false)
		ActivityType.SLICE:
			if is_activity_active or rotational_active:
				return
			activity = slice_scene.instantiate()
			if activity:
				activity.max_time = DifficultyManager.get_timeout_for("slice")
		ActivityType.REACTION:
			if is_activity_active or rotational_active:
				return
			activity = reaction_scene.instantiate()
			if activity:
				activity.max_time = DifficultyManager.get_timeout_for("reaction")
		ActivityType.CIRCLE:
			if is_activity_active or rotational_active:
				return
			activity = circle_scene.instantiate()
			is_rot = true
			rotational_active = true
			if activity:
				activity.max_time = DifficultyManager.get_timeout_for("circle")

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
	# TARGET też aktualizuje multiplier – wcześniej Adaptive ignorował 25% sesji.
	DifficultyManager.report_reaction_time(reaction_time)
	_check_and_advance_section()

func register_miss() -> void:
	_show_miss_feedback()

# ===========================================================
# KONIEC SESJI
# ===========================================================
func _on_session_timer_timeout() -> void:
	session_active = false
	spawn_timer.stop()
	if hud_screen:
		hud_screen.visible = false
	_show_results()

func _show_results() -> void:
	if progress_screen:
		progress_screen.visible = false

	var average: float = _calculate_average()

	# Ocena PRZED zapisem – porównujemy z poprzednią sesją
	var eval_data: Dictionary = _evaluate_progress(average)
	_save_session(average)

	result_label_avg.text   = "⏱  Średni czas reakcji:  %.2f s" % average
	result_label_hits.text  = "🎯  Trafienia:  %d" % hits
	result_label_reps.text  = "🔁  Powtórzenia:  %d" % repetitions
	result_label_score.text = "Wynik:  %d pkt" % score

	var stars: int = 0
	if score >= 200:   stars = 3
	elif score >= 130: stars = 2
	elif score >= 80:  stars = 1
	result_label_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	result_label_stars.modulate = Color(1.0, 0.85, 0.1) if stars > 0 else Color(0.5, 0.5, 0.5)

	result_label_eval.text     = eval_data["msg"]
	result_label_eval.modulate = eval_data["color"]

	if eval_data["sound"] == "win":
		SoundManager.play_win()
	elif eval_data["sound"] == "lose":
		SoundManager.play_lose()
	else:
		SoundManager.play_hit()

	menu.visible           = false
	results_screen.visible = true

func _calculate_average() -> float:
	if reaction_times.is_empty():
		return 0.0
	var total: float = 0.0
	for t: float in reaction_times:
		total += t
	return total / reaction_times.size()

func _evaluate_progress(current_avg: float) -> Dictionary:
	# Próg bezwzględny: 0.05 s (50 ms) – każda 1/10 s ma znaczenie,
	# nie używamy procentów (byłyby niesprawiedliwe przy krótkich czasach).
	const THRESHOLD: float = 0.05

	var sessions: Array = _load_sessions()
	var prev_avg: float = -1.0
	for i: int in range(sessions.size() - 1, -1, -1):
		var s: Dictionary = sessions[i]
		var rt: float = float(s.get("average_reaction", 0.0))
		if rt > 0.0 and int(s.get("hits", 0)) > 0:
			prev_avg = rt
			break

	if prev_avg < 0.0 or current_avg <= 0.0:
		return {
			"msg":   "Pierwszy trening! 🌟\nWynik został zapisany.",
			"color": Color(0.45, 0.80, 1.00, 1.0),
			"sound": "hit"
		}

	# diff > 0 → szybciej (poprawa),  diff < 0 → wolniej (spadek)
	var diff: float = prev_avg - current_avg

	if diff > THRESHOLD:
		return {
			"msg":   "Poprawa umiejętności! 🎯\n%.3f s  →  %.3f s  (−%.0f ms)" % [prev_avg, current_avg, diff * 1000.0],
			"color": Color(0.20, 0.88, 0.42, 1.0),
			"sound": "win"
		}
	elif diff < -THRESHOLD:
		return {
			"msg":   "Spadek umiejętności 📉\n%.3f s  →  %.3f s  (+%.0f ms)" % [prev_avg, current_avg, -diff * 1000.0],
			"color": Color(0.92, 0.30, 0.30, 1.0),
			"sound": "lose"
		}
	else:
		return {
			"msg":   "Trzymasz poziom! 💪\n%.3f s  →  %.3f s  (±%.0f ms)" % [prev_avg, current_avg, absf(diff) * 1000.0],
			"color": Color(1.00, 0.85, 0.20, 1.0),
			"sound": "hit"
		}

func _create_results_screen() -> void:
	results_screen = CanvasLayer.new()
	results_screen.name    = "ResultsScreen"
	results_screen.layer   = 5
	results_screen.visible = false
	add_child(results_screen)

	results_panel = Panel.new()
	results_panel.anchor_left    = 0.5
	results_panel.anchor_top     = 0.5
	results_panel.anchor_right   = 0.5
	results_panel.anchor_bottom  = 0.5
	results_panel.offset_left    = -265.0
	results_panel.offset_top     = -215.0
	results_panel.offset_right   = 265.0
	results_panel.offset_bottom  = 215.0
	results_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	results_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	results_screen.add_child(results_panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_left    = 0.0
	vbox.anchor_top     = 0.0
	vbox.anchor_right   = 1.0
	vbox.anchor_bottom  = 1.0
	vbox.offset_left    = 18.0
	vbox.offset_top     = 18.0
	vbox.offset_right   = -18.0
	vbox.offset_bottom  = -18.0
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical   = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 10)
	results_panel.add_child(vbox)

	var lbl_title := Label.new()
	lbl_title.text = "📊  Wyniki sesji"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.set("theme_override_font_sizes/font_size", 26)
	vbox.add_child(lbl_title)

	vbox.add_child(HSeparator.new())

	result_label_avg = Label.new()
	result_label_avg.set("theme_override_font_sizes/font_size", 19)
	vbox.add_child(result_label_avg)

	result_label_hits = Label.new()
	result_label_hits.set("theme_override_font_sizes/font_size", 19)
	vbox.add_child(result_label_hits)

	result_label_reps = Label.new()
	result_label_reps.set("theme_override_font_sizes/font_size", 19)
	vbox.add_child(result_label_reps)

	result_label_score = Label.new()
	result_label_score.set("theme_override_font_sizes/font_size", 19)
	vbox.add_child(result_label_score)

	# Gwiazdki – gradacja bez zmiany mechanik (wzorzec scoring-tier z MakeUseOf/Godot Forum).
	# 3★ ≥200 pkt (świetna sesja), 2★ ≥130 pkt (dobra), 1★ ≥80 pkt (wygrana), 0★ porażka.
	result_label_stars = Label.new()
	result_label_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label_stars.set("theme_override_font_sizes/font_size", 32)
	vbox.add_child(result_label_stars)

	vbox.add_child(HSeparator.new())

	result_label_eval = Label.new()
	result_label_eval.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label_eval.set("theme_override_font_sizes/font_size", 26)
	result_label_eval.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label_eval.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(result_label_eval)

	vbox.add_child(HSeparator.new())

	var btn_ok := Button.new()
	btn_ok.text = "OK – wróć do menu"
	btn_ok.custom_minimum_size      = Vector2(0, 52)
	btn_ok.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	btn_ok.set("theme_override_font_sizes/font_size", 20)
	btn_ok.pressed.connect(_on_results_ok_pressed)
	vbox.add_child(btn_ok)

func _on_results_ok_pressed() -> void:
	results_screen.visible = false
	if hud_screen:
		hud_screen.visible = false
	btn_start.visible = true
	_show_menu_animated()

# ===========================================================
# HUD – tworzenie i aktualizacja
# Wzorzec "always-visible HUD" z r/godot (GDQuest, 2024):
# CanvasLayer layer=2 zapewnia rysowanie ponad grą, pod menu.
# ===========================================================
func _create_hud() -> void:
	hud_screen        = CanvasLayer.new()
	hud_screen.name   = "HUD"
	hud_screen.layer  = 2
	hud_screen.visible = false
	add_child(hud_screen)

	var bar := Panel.new()
	bar.anchor_left     = 0.0
	bar.anchor_top      = 0.0
	bar.anchor_right    = 1.0
	bar.anchor_bottom   = 0.0
	bar.offset_bottom   = 52.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.04, 0.04, 0.11, 0.82)
	bar.add_theme_stylebox_override("panel", sbox)
	hud_screen.add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.anchor_left     = 0.0
	hbox.anchor_top      = 0.0
	hbox.anchor_right    = 1.0
	hbox.anchor_bottom   = 0.0
	hbox.offset_left     = 18.0
	hbox.offset_top      = 6.0
	hbox.offset_right    = -18.0
	hbox.offset_bottom   = 52.0
	hbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hbox.add_theme_constant_override("separation", 8)
	hud_screen.add_child(hbox)

	hud_label_time = Label.new()
	hud_label_time.text = "⏱  30 s"
	hud_label_time.custom_minimum_size = Vector2(110, 0)
	hud_label_time.set("theme_override_font_sizes/font_size", 22)
	hud_label_time.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	hbox.add_child(hud_label_time)

	hud_label_activity = Label.new()
	hud_label_activity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_label_activity.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	hud_label_activity.set("theme_override_font_sizes/font_size", 20)
	hud_label_activity.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	hbox.add_child(hud_label_activity)

	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(140, 0)
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(right_vbox)

	hud_label_score = Label.new()
	hud_label_score.text = "0 pkt"
	hud_label_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_label_score.set("theme_override_font_sizes/font_size", 22)
	hud_label_score.add_theme_color_override("font_color", Color(1.0, 0.85, 0.18))
	right_vbox.add_child(hud_label_score)

	hud_label_adaptive = Label.new()
	hud_label_adaptive.text = ""
	hud_label_adaptive.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_label_adaptive.set("theme_override_font_sizes/font_size", 13)
	hud_label_adaptive.add_theme_color_override("font_color", Color(0.45, 0.78, 1.0))
	hud_label_adaptive.visible = false
	right_vbox.add_child(hud_label_adaptive)

	# Podpowiedź aktywności – pojawia się na 2 s przy starcie każdej sekcji (tutorial).
	# "Non-blocking hint overlay" polecany przez Godot Accessibility wątek 2024
	# i WCAG 2.1 kryterium 3.3.2 dla użytkowników z zaburzeniami motorycznymi.
	hud_hint_label = Label.new()
	hud_hint_label.anchor_left    = 0.5
	hud_hint_label.anchor_top     = 0.5
	hud_hint_label.anchor_right   = 0.5
	hud_hint_label.anchor_bottom  = 0.5
	hud_hint_label.offset_left    = -350.0
	hud_hint_label.offset_top     = -28.0
	hud_hint_label.offset_right   = 350.0
	hud_hint_label.offset_bottom  = 28.0
	hud_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_hint_label.set("theme_override_font_sizes/font_size", 24)
	hud_hint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.28))
	hud_hint_label.modulate.a = 0.0
	hud_screen.add_child(hud_hint_label)

	# Etykieta PUDŁO – miga 0.7 s gdy aktywność przepada bez kliknięcia.
	# SDT (Signal Detection Theory): brak feedbacku za miss uniemożliwia
	# graczowi kalibrację własnej reaktywności (raport audytu, sekcja R5).
	hud_miss_label = Label.new()
	hud_miss_label.anchor_left    = 0.5
	hud_miss_label.anchor_top     = 0.5
	hud_miss_label.anchor_right   = 0.5
	hud_miss_label.anchor_bottom  = 0.5
	hud_miss_label.offset_left    = -90.0
	hud_miss_label.offset_top     = 55.0
	hud_miss_label.offset_right   = 90.0
	hud_miss_label.offset_bottom  = 100.0
	hud_miss_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud_miss_label.text = "PUDŁO!"
	hud_miss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_miss_label.set("theme_override_font_sizes/font_size", 38)
	hud_miss_label.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
	hud_miss_label.modulate.a = 0.0
	hud_screen.add_child(hud_miss_label)

func _process(_delta: float) -> void:
	if not session_active or not hud_screen or not hud_screen.visible:
		return
	if hud_label_time:
		hud_label_time.text = "⏱  %.0f s" % maxf(0.0, session_timer.time_left)
	if hud_label_score:
		hud_label_score.text = "%d pkt" % score
	if current_section < 4 and hud_label_activity:
		hud_label_activity.text = _activity_display_name(section_order[current_section])
	if hud_label_adaptive:
		var is_adaptive: bool = DifficultyManager.current_difficulty == DifficultyManager.Difficulty.ADAPTIVE
		if is_adaptive:
			hud_label_adaptive.text = "Adaptive %.2f×" % DifficultyManager.adaptive_multiplier
			hud_label_adaptive.visible = true
		else:
			hud_label_adaptive.visible = false

func _activity_display_name(t: ActivityType) -> String:
	match t:
		ActivityType.TARGET:   return "🎯 Cel"
		ActivityType.SLICE:    return "✂ Cięcie"
		ActivityType.REACTION: return "⚡ Reakcja"
		ActivityType.CIRCLE:   return "🔄 Obrót 360°"
	return ""

func _activity_hint(t: ActivityType) -> String:
	match t:
		ActivityType.TARGET:   return "Klikaj pojawiające się kwadraty jak najszybciej!"
		ActivityType.SLICE:    return "Przeciągnij myszą przez kształt wzdłuż przerywianej linii!"
		ActivityType.REACTION: return "Kliknij LMB lub naciśnij SPACJĘ gdy widzisz czerwone kółko!"
		ActivityType.CIRCLE:   return "Obróć mysz o pełne 360° wokół środka ekranu!"
	return ""

func _show_activity_hint(t: ActivityType) -> void:
	if not hud_hint_label:
		return
	hud_hint_label.text = _activity_hint(t)
	var tween := get_tree().create_tween()
	tween.tween_property(hud_hint_label, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.8)
	tween.tween_property(hud_hint_label, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)

func _show_miss_feedback() -> void:
	SoundManager.play_miss()
	if not hud_miss_label:
		return
	hud_miss_label.modulate.a = 1.0
	var tween := get_tree().create_tween()
	tween.tween_property(hud_miss_label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)

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
		if hud_screen:
			hud_screen.visible = false
		_show_menu_animated()
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

func _apply_theme() -> void:
	var t: Theme = ThemeBuilder.theme
	if t == null:
		return
	# CanvasLayer przerywa dziedziczenie – ustawiamy motyw bezpośrednio
	# na pierwszych węzłach-kontrolkach wewnątrz każdej CanvasLayer
	$Menu/VBoxMenuContainer.theme = t
	label_tytul.theme             = t
	panel_wynikow.theme           = t
	if menu_bg:        menu_bg.theme = t
	if label_subtitle: label_subtitle.theme = t
	if progress_panel:
		progress_panel.theme = t
	if difficulty_panel:
		difficulty_panel.theme = t
	if results_panel:
		results_panel.theme = t

func _style_ui() -> void:
	label_tytul.set("theme_override_font_sizes/font_size", 42)

	if label_subtitle:
		label_subtitle.set("theme_override_font_sizes/font_size", 17)
		label_subtitle.modulate = Color(0.62, 0.68, 0.88, 1.0)

	for lbl in [label_sredni, label_trafienia, label_punkty, label_wynik]:
		if lbl:
			lbl.set("theme_override_font_sizes/font_size", 20)

	for btn in [btn_start, btn_restart, btn_progress, btn_reset_adaptive]:
		if btn:
			btn.set("theme_override_font_sizes/font_size", 22)

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

		# Rekord punktowy ze wszystkich sesji (audit: brak zapisu najlepszego wyniku)
		var best_sc: int = 0
		for s: Dictionary in sessions:
			var s_sc: int = int(s.get("score", 0))
			if s_sc > best_sc:
				best_sc = s_sc
		var best_lbl := Label.new()
		best_lbl.text = "🏆  Rekord: %d pkt" % best_sc
		best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best_lbl.set("theme_override_font_sizes/font_size", 17)
		best_lbl.modulate = Color(1.0, 0.82, 0.18, 1)
		progress_list.add_child(best_lbl)
		progress_list.add_child(HSeparator.new())

		for i: int in range(to_show.size()):
			var s: Dictionary = to_show[i]
			var entry := Label.new()
			var date_str: String = String(s.get("date", "brak daty")).substr(0, 16)
			var rt: float  = float(s.get("average_reaction", 0.0))
			var h: int     = int(s.get("hits", 0))
			var sc: int    = int(s.get("score", 0))
			var reps: int  = int(s.get("repetitions", 0))

			# Porównanie z poprzednią sesją (nowszy → to_show[0], starszy → to_show[1]).
			# Próg 0.05 s (50 ms) – taki sam jak w _evaluate_progress, zgodnie z audytem.
			var res_str: String
			var res_color: Color
			if i + 1 < to_show.size():
				var prev_rt: float = float(to_show[i + 1].get("average_reaction", 0.0))
				var diff: float = prev_rt - rt  # > 0 = szybciej = poprawa
				if h == 0:
					res_str   = "—  brak trafień"
					res_color = Color(0.5, 0.5, 0.5, 1)
				elif diff > 0.05:
					res_str   = "⬆ Poprawa"
					res_color = Color(0.20, 0.72, 0.35, 1)
				elif diff < -0.05:
					res_str   = "⬇ Spadek"
					res_color = Color(0.78, 0.28, 0.28, 1)
				else:
					res_str   = "=  Poziom"
					res_color = Color(0.85, 0.78, 0.20, 1)
			else:
				res_str   = "★  Pierwsze"
				res_color = Color(0.45, 0.78, 1.0, 1)

			entry.text = "%s  |  RT: %.2f s  |  Traf.: %d  |  Powt.: %d  |  Pkt: %d  |  %s" % [date_str, rt, h, reps, sc, res_str]
			entry.set("theme_override_font_sizes/font_size", 15)
			entry.modulate = res_color
			progress_list.add_child(entry)

			var sep := HSeparator.new()
			sep.modulate = Color(0.7, 0.7, 0.75, 0.6)
			progress_list.add_child(sep)

	progress_screen.visible = true

func _on_close_progress_pressed() -> void:
	if progress_screen:
		progress_screen.visible = false
	_show_menu_animated()

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
	else:
		_show_miss_feedback()
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
	else:
		_show_miss_feedback()
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
		var sekcja_info: String = str(section_order[current_section]) if current_section < 4 else "KONIEC"
		print("[Rehagame] Sekcja ", current_section, " → ", sekcja_info)
		if current_section < 4:
			_show_activity_hint(section_order[current_section])

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
	btn_easy.custom_minimum_size    = Vector2(420, 55)
	btn_easy.theme_type_variation   = "ButtonEasy"
	btn_easy.pressed.connect(_on_difficulty_selected.bind(DifficultyManager.Difficulty.EASY))
	btn_box.add_child(btn_easy)

	btn_normal = Button.new()
	btn_normal.text = "🟡 NORMAL - Normalny (timeout 1.0s)"
	btn_normal.custom_minimum_size  = Vector2(420, 55)
	btn_normal.theme_type_variation = "ButtonNormal"
	btn_normal.pressed.connect(_on_difficulty_selected.bind(DifficultyManager.Difficulty.NORMAL))
	btn_box.add_child(btn_normal)

	btn_hard = Button.new()
	btn_hard.text = "🔴 HARD - Trudny (timeout 0.7s)"
	btn_hard.custom_minimum_size    = Vector2(420, 55)
	btn_hard.theme_type_variation   = "ButtonHard"
	btn_hard.pressed.connect(_on_difficulty_selected.bind(DifficultyManager.Difficulty.HARD))
	btn_box.add_child(btn_hard)

	btn_adaptive = Button.new()
	btn_adaptive.text = "🔵 ADAPTIVE - Adaptacyjny (uczy się z Twoich reakcji!)"
	btn_adaptive.custom_minimum_size    = Vector2(420, 55)
	btn_adaptive.theme_type_variation   = "ButtonAdaptive"
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
	if hud_screen:
		hud_screen.visible = true
	if section_order.size() > 0:
		_show_activity_hint(section_order[0])

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
