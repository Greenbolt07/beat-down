extends CharacterBody2D

@onready var hurtbox: CollisionShape2D = $EnemyCollision/Area2D/Hurtbox

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const Health = 100

func _physics_process(delta: float) -> void:

	_update_gravity(delta)
	_update_movement()
	
	_handle_health()
	
func _update_gravity(delta: float):
	if not is_on_floor():
		velocity += get_gravity() * delta

func _update_movement():
	# var direction := Input.get_axis("ui_left", "ui_right")
	# if direction:
		# velocity.x = direction * SPEED
	# else:
		# velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _handle_health():
	
	if Health <= 0:
		queue_free()

func receive_hit() -> void:
	print("hit")

func _on_area_2d_area_shape_entered(area_rid: RID, area: Area2D, area_shape_index: int, local_shape_index: int) -> void:
	pass
