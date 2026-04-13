extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var void_reset_zone: Area2D = $VoidResetZone

func _ready() -> void:
	void_reset_zone.body_entered.connect(_on_void_reset_zone_body_entered)

func _on_void_reset_zone_body_entered(body: Node2D) -> void:
	if body != player:
		return

	if body.has_method("reset_to_position"):
		body.reset_to_position(spawn_point.global_position)
		return

	player.global_position = spawn_point.global_position
	player.velocity = Vector2.ZERO
