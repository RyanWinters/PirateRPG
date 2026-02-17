extends CharacterBody2D
class_name Enemy

signal killed(world_position: Vector2, xp_value: int)

var speed: float = 90.0
var health: float = 6.0
var touch_damage_per_second: float = 10.0
var xp_drop: int = 1
var target: Node2D

func _ready() -> void:
	z_index = 10


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() > 0.001:
		velocity = to_target.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	var player := target as Player
	if player != null and global_position.distance_to(player.global_position) < 22.0:
		player.apply_damage(touch_damage_per_second * delta)


func apply_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		killed.emit(global_position, xp_drop)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.2, 0.2))
