class_name ReactionClickActivity
extends Node2D

signal activity_completed(success: bool, reaction_time: float)

@export var max_time: float = 1.2

var time_left: float = 0.0
var active: bool = false

var center: Vector2

func _ready() -> void:
	center = get_viewport_rect().size / 2.0
	time_left = max_time
	active = true
	set_process(true)
	set_process_input(true)

func _process(delta: float) -> void:
	if not active: return
	time_left -= delta
	if time_left <= 0:
		_complete(false)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active: return
	# NAPRAWIONO: używa is_action_just_pressed (dla akcji "ui_accept") ORAZ mouse click
	# Poprzednio tylko event.pressed - teraz zgodne z wymaganiem używania is_action_just_pressed (a nie is_pressed)
	if Input.is_action_just_pressed("ui_accept"):
		_complete(true)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_complete(true)

func _complete(success: bool) -> void:
	var reaction_time: float = max_time - time_left
	active = false
	set_process(false)
	set_process_input(false)
	activity_completed.emit(success, reaction_time)
	queue_free()

func _draw() -> void:
	draw_circle(center, 55, Color(1.0, 0.25, 0.25, 0.85))
	draw_string(ThemeDB.fallback_font, center + Vector2(-90, -100), "KLIKNIJ SZYBKO!", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color.WHITE)
	draw_string(ThemeDB.fallback_font, center + Vector2(-45, 110), "CZAS: %.1f s" % time_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1, 1, 0))
