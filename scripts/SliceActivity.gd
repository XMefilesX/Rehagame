class_name SliceActivity
extends Node2D

signal activity_completed(success: bool, reaction_time: float)

@export var max_time: float = 2.0

var time_left: float = 0.0
var active: bool = false
var is_drawing: bool = false
var cut_points: Array[Vector2] = []
var shape_center: Vector2
var shape_size: float = 120.0
var is_circle: bool = false
var cut_direction: String = "horizontal"
var has_succeeded: bool = false          # <-- ZMIENIONA NAZW A (unikamy konfliktu)
var _grace_used: bool = false
# Dodatkowy czas przyznawany jednorazowo gdy gracz zaczyna przeciągać (mousedown).
# "Input forgiveness / grace period" – wzorzec polecany przez społeczność Godot
# (forum.godotengine.org, wątek o mobile swipe UX, 2024) dla użytkowników
# ze spowolnieniem psychomotorycznym: nagradzamy inicjację ruchu, nie tylko tempo.
const _GRACE_SECONDS: float = 0.45

func _ready() -> void:
	var viewport_size = get_viewport_rect().size
	shape_center = Vector2(
		randf_range(200, viewport_size.x - 200),
		randf_range(150, viewport_size.y - 150)
	)
	is_circle = randf() > 0.5
	cut_direction = "horizontal" if randf() > 0.5 else "vertical"
	time_left = max_time
	active = true
	set_process(true)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if not active: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_drawing = true
			cut_points.clear()
			cut_points.append(event.position)
			if not _grace_used:
				_grace_used = true
				time_left += _GRACE_SECONDS
		else:
			is_drawing = false
			_check_cut()

	if event is InputEventMouseMotion and is_drawing:
		cut_points.append(event.position)
		queue_redraw()

func _process(delta: float) -> void:
	if not active: return
	time_left -= delta
	if time_left <= 0 and not has_succeeded:
		_complete(false)
	queue_redraw()

func _check_cut() -> void:
	if cut_points.size() < 3:
		_complete(false)
		return

	var start = cut_points[0]
	var end = cut_points[cut_points.size() - 1]
	var dx = end.x - start.x
	var dy = end.y - start.y
	var angle = rad_to_deg(atan2(dy, dx))

	var required = 0.0 if cut_direction == "horizontal" else 90.0
	var diff = abs(angle - required)
	if diff > 180: diff = 360 - diff

	var is_straight = diff <= 25.0 or (180 - diff) <= 25.0

	var crosses = false
	if is_circle:
		crosses = _line_intersects_circle(start, end, shape_center, shape_size)
	else:
		crosses = _line_intersects_rect(start, end, shape_center, shape_size)

	if is_straight and crosses:
		has_succeeded = true
		_complete(true)
	else:
		_complete(false)

func _line_intersects_circle(p1: Vector2, p2: Vector2, c: Vector2, r: float) -> bool:
	var d = p2 - p1
	var f = p1 - c
	var a = d.dot(d)
	var b = 2 * f.dot(d)
	var disc = b*b - 4*a*(f.dot(f) - r*r)
	return disc >= 0

func _line_intersects_rect(p1: Vector2, p2: Vector2, c: Vector2, s: float) -> bool:
	var half = s / 2.0
	if cut_direction == "horizontal":
		return (min(p1.x, p2.x) < c.x - half and max(p1.x, p2.x) > c.x + half)
	else:
		return (min(p1.y, p2.y) < c.y - half and max(p1.y, p2.y) > c.y + half)

func _complete(success: bool) -> void:
	var reaction_time: float = max_time - time_left
	active = false
	set_process(false)
	set_process_input(false)
	activity_completed.emit(success, reaction_time)
	queue_free()

func _draw() -> void:
	if is_circle:
		draw_circle(shape_center, shape_size, Color(0.9, 0.3, 0.3, 0.85))
	else:
		draw_rect(Rect2(shape_center - Vector2(shape_size, shape_size), Vector2(shape_size*2, shape_size*2)), Color(0.3, 0.7, 0.9, 0.85))

	var guide_color = Color(1, 1, 0, 0.6)
	if cut_direction == "horizontal":
		draw_dashed_line(shape_center - Vector2(shape_size + 40, 0), shape_center + Vector2(shape_size + 40, 0), guide_color, 3.0, 10.0)
	else:
		draw_dashed_line(shape_center - Vector2(0, shape_size + 40), shape_center + Vector2(0, shape_size + 40), guide_color, 3.0, 10.0)

	if cut_points.size() > 1:
		for i in range(cut_points.size() - 1):
			draw_line(cut_points[i], cut_points[i+1], Color(1, 1, 1, 0.95), 5.0)

	draw_string(ThemeDB.fallback_font, get_viewport_rect().size / 2 + Vector2(-130, -220), "PRZECIĄĆ KSZTAŁT!", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
	draw_string(ThemeDB.fallback_font, get_viewport_rect().size / 2 + Vector2(-100, -185), "Kierunek: %s" % cut_direction.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1, 0.95, 0.4))
	draw_string(ThemeDB.fallback_font, get_viewport_rect().size / 2 + Vector2(-45, 210), "CZAS: %.1f s" % time_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.YELLOW)
