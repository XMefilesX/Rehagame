class_name Target
extends Area2D

# Czas pojawienia się celu (w sekundach od uruchomienia)
@onready var color_rect: ColorRect = $ColorRect

var spawn_time: float = 0.0
var main_node: Node = null
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	spawn_time = Time.get_ticks_msec() / 1000.0
	# Losowy ruch w lewo/prawo i góra/dół – gracz musi śledzić cel
	velocity = Vector2(randf_range(-45.0, 45.0), randf_range(-35.0, 35.0))

## Ustawia referencję do węzła Main (wywoływane przez Main po add_child)
func set_main(node: Node) -> void:
	main_node = node

func _process(delta: float) -> void:
	position += velocity * delta
	# Odbicie od krawędzi ekranu (proste bounce)
	if position.x < 60 or position.x > 1220:
		velocity.x = -velocity.x * 0.95  # Lekkie tłumienie
	if position.y < 60 or position.y > 660:
		velocity.y = -velocity.y * 0.95

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
	color_rect.color = Color(1.0, 0.4, 0.4, 1.0)

func _on_mouse_exited() -> void:
	color_rect.color = Color(1.0, 0.0, 0.0, 1.0)
