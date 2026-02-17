extends CharacterBody2D
class_name Player

signal died

var move_speed: float = 260.0
var max_health: float = 100.0
var health: float = 100.0

func _ready() -> void:
	z_index = 20


func _physics_process(_delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * move_speed
	move_and_slide()


func apply_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	queue_redraw()
	if health <= 0.0:
		died.emit()


func heal_full() -> void:
	health = max_health
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-12, -12), Vector2(24, 24)), Color(0.2, 0.5, 1.0))
	var hp_ratio: float = 0.0 if max_health <= 0.0 else health / max_health
	draw_rect(Rect2(Vector2(-15, -22), Vector2(30, 4)), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(Vector2(-15, -22), Vector2(30 * hp_ratio, 4)), Color(0.1, 0.95, 0.45))
