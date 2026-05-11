class_name ReactionClickActivity
extends Node2D

signal activity_completed(success: bool)

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
	if not active or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	_complete(true)

func _complete(success: bool) -> void:
	active = false
	set_process(false)
	set_process_input(false)
	emit_signal("activity_completed", success)
	queue_free()

func _draw() -> void:
	draw_circle(center, 55, Color(1.0, 0.25, 0.25, 0.85))
	draw_string(ThemeDB.fallback_font, center + Vector2(-90, -100), "KLIKNIJ SZYBKO!", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color.WHITE)
	draw_string(ThemeDB.fallback_font, center + Vector2(-45, 110), "CZAS: %.1f s" % time_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1, 1, 0))
