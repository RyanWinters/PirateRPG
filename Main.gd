extends Control

@export var game_state_path: NodePath = NodePath("/root/GameState")
@export var event_bus_path: NodePath = NodePath("/root/EventBus")


func _ready() -> void:
	if get_node_or_null(game_state_path) == null:
		push_error("Main scene missing GameState autoload at %s" % game_state_path)
	if get_node_or_null(event_bus_path) == null:
		push_error("Main scene missing EventBus autoload at %s" % event_bus_path)
