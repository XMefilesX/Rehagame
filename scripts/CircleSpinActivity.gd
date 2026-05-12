class_name CircleSpinActivity
extends Node2D

signal activity_completed(success: bool, reaction_time: float)

@export var max_time: float = 2.0
@export var required_rotation: float = 2.0 * PI
@export var min_angular_speed: float = 1.5

var center: Vector2
var current_angle: float = 0.0
var total_rotation: float = 0.0
var time_left: float = 0.0
var active: bool = false
var last_mouse_pos: Vector2

func _ready() -> void:
	center = get_viewport_rect().size / 2.0
	last_mouse_pos = get_viewport().get_mouse_position()
	current_angle = _get_angle(last_mouse_pos)
	time_left = max_time
	active = true
	set_process(true)
	set_process_input(true)

func _get_angle(pos: Vector2) -> float:
	var rel = pos - center
	return atan2(rel.y, rel.x)

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventMouseMotion:
		return
	var new_angle = _get_angle(event.position)
	var delta = new_angle - current_angle
	while delta > PI: delta -= 2 * PI
	while delta < -PI: delta += 2 * PI
	if abs(delta) < min_angular_speed * get_process_delta_time(): return
	total_rotation += delta
	current_angle = new_angle
	if total_rotation >= required_rotation:
		_complete(true)

func _process(delta: float) -> void:
	if not active: return
	time_left -= delta
	if time_left <= 0: _complete(false)
	queue_redraw()

func _complete(success: bool) -> void:
	var reaction_time: float = max_time - time_left
	active = false
	set_process(false)
	set_process_input(false)
	activity_completed.emit(success, reaction_time)
	queue_free()

func _draw() -> void:
	draw_circle(center, 160, Color(0.2, 0.6, 1.0, 0.4))
	draw_arc(center, 160, 0, 2 * PI, 128, Color.WHITE, 4.0, true)
	var progress = clamp(total_rotation / required_rotation * 100, 0, 100)
	draw_string(ThemeDB.fallback_font, center + Vector2(-80, -200), "OBRÓĆ 360°: %.0f%%" % progress, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
	draw_string(ThemeDB.fallback_font, center + Vector2(-60, 200), "CZAS: %.1f s" % time_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(1, 0.8, 0))
