class_name Target
extends Area2D

# Czas pojawienia się celu (w sekundach od uruchomienia)
var spawn_time: float = 0.0
# Referencja do węzła Main – ustawiana przez Main.spawn_target()
var main_node: Node = null

func _ready() -> void:
	spawn_time = Time.get_ticks_msec() / 1000.0

## Ustawia referencję do węzła Main (wywoływane przez Main po add_child)
func set_main(node: Node) -> void:
	main_node = node

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		var reaction_time: float = (Time.get_ticks_msec() / 1000.0) - spawn_time
		if is_instance_valid(main_node):
			main_node.register_hit(reaction_time)
		queue_free()

## Efekt wizualny hover – podświetl cel na jaśniejszy odcień
func _on_mouse_entered() -> void:
	$ColorRect.color = Color(1.0, 0.4, 0.4, 1.0)

## Przywróć kolor po opuszczeniu
func _on_mouse_exited() -> void:
	$ColorRect.color = Color(1.0, 0.0, 0.0, 1.0)
