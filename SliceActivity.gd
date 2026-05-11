class_name SliceActivity
extends Node2D

signal activity_completed(success: bool)

@export var max_time: float = 1.5

var time_left: float = 0.0
var active: bool = false
var last_mouse_pos: Vector2
var swipe_detected: bool = false

func _ready() -> void:
	time_left = max_time
	active = true
	last_mouse_pos = get_viewport().get_mouse_position()
	set_process(true)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventMouseMotion:
		return
	var current_pos = event.position
	# Proste wykrycie swipe: ruch w poziomie > 120px przy małej zmianie Y
	if abs(current_pos.x - last_mouse_pos.x) > 120 and abs(current_pos.y - last_mouse_pos.y) < 80:
		swipe_detected = true
		_complete(true)
	last_mouse_pos = current_pos

func _process(delta: float) -> void:
	if not active: return
	time_left -= delta
	if time_left <= 0:
		_complete(false)
	queue_redraw()

func _complete(success: bool) -> void:
	active = false
	set_process(false)
	set_process_input(false)
	emit_signal("activity_completed", success)
	queue_free()

func _draw() -> void:
	var center = get_viewport_rect().size / 2.0
	draw_rect(Rect2(center - Vector2(160, 25), Vector2(320, 50)), Color(0.2, 0.85, 0.3, 0.7))
	draw_string(ThemeDB.fallback_font, center + Vector2(-120, -120), "PRZESUŃ MYSZĄ W PRAWO! (SLICE)", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)
	draw_string(ThemeDB.fallback_font, center + Vector2(-50, 140), "CZAS: %.1f s" % time_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.YELLOW)
