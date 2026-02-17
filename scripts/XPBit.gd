extends Area2D
class_name XPBit

var xp_value: int = 1
var pickup_radius: float = 120.0
var seek_speed: float = 230.0
var attractor: Node2D
var collector: Object

func _ready() -> void:
	z_index = 5


func _physics_process(delta: float) -> void:
	if attractor == null:
		return
	var to_target: Vector2 = attractor.global_position - global_position
	if to_target.length() <= pickup_radius:
		if to_target.length() > 0.001:
			global_position += to_target.normalized() * seek_speed * delta
		if global_position.distance_to(attractor.global_position) < 14.0:
			if collector != null and collector.has_method("collect_xp"):
				collector.collect_xp(xp_value)
			queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.9, 0.15))
