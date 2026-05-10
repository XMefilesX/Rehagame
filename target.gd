extends Area2D

var spawn_time: float = 0.0

func _ready():
	spawn_time = Time.get_ticks_msec() / 1000.0

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var reaction_time = (Time.get_ticks_msec() / 1000.0) - spawn_time
		
		# Poprawione wywołanie - idziemy dwa poziomy w górę do Main
		var main_node = get_parent().get_parent()
		if main_node.has_method("register_hit"):
			main_node.register_hit(reaction_time)
		
		queue_free()
