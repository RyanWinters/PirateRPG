extends Area2D
class_name Bullet

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: float = 3.0
var lifetime: float = 1.5

func _ready() -> void:
	z_index = 15


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(0.3, 1.0, 1.0))
