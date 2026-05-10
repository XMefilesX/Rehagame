extends Area2D

var spawn_time: float = 0.0

@onready var main_node = get_tree().get_first_node_in_group("main")

func _ready():
	spawn_time = Time.get_ticks_msec() / 1000.0

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var reaction_time = (Time.get_ticks_msec() / 1000.0) - spawn_time
		
		if main_node and main_node.has_method("register_hit"):
			main_node.register_hit(reaction_time)
		
		queue_free()
