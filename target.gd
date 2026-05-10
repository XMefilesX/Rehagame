extends Area2D

var spawn_time: float = 0.0   # tu zapiszemy moment pojawienia się

func _ready():
	spawn_time = Time.get_ticks_msec() / 1000.0   # aktualny czas w sekundach
	print("Cel się pojawił!")

# To jest funkcja, która odpala się gdy klikniesz na Area2D
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var reaction_time = (Time.get_ticks_msec() / 1000.0) - spawn_time
		print("Czas reakcji: ", reaction_time, " sekund")
		queue_free()   # usuwa kwadrat z ekranu
