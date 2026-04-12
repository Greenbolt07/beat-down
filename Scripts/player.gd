extends CharacterBody2D

# Movement Variables
const SPEED = 200
var SPEEDF :int= 0
var LAST_DIRECTION :int= -1
var IS_DASHING := false
var IS_RUNNING := false
var current_speed = SPEED
const JUMP_VELOCITY = -300.0
var was_on_floor := true

# Other variables
var IS_ATTACKING := false
var light_attack_animations = [
	"Melee Attack Light 1",
	"Melee Attack Light 2",
    "Melee Attack Light 3"
]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_cooldown: Timer = $DashCooldown
@onready var dash_length: Timer = $DashLength
@onready var hitbox: Area2D = $Area2D

func _ready():
	hitbox.monitoring = false

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Determines player didrection.
	var direction := Input.get_axis("Left", "Right")
	if direction > 0:
		animated_sprite.flip_h = true
	elif direction < 0:
		animated_sprite.flip_h = false
	if direction != 0:
		LAST_DIRECTION = direction
	
	# Detects attack
	if Input.is_action_just_pressed("Light Attack") and !IS_ATTACKING:
		start_light_attack()
		
	
	# Determins if player is sprinting
	IS_RUNNING = Input.is_action_pressed("Sprint")
	
	# Determins player action resulting in correct animation
	if IS_ATTACKING:
		pass
	elif IS_DASHING:
		animated_sprite.play("Dash")
	else:
		if is_on_floor():
			if direction == 0:
				animated_sprite.play("Idle")
			else:
				if IS_RUNNING:
					animated_sprite.play("Run")
				else:
					animated_sprite.play("Walk")
		else:
			if was_on_floor:
				animated_sprite.play("Fall Start")
			elif animated_sprite.animation == "Fall Start" and !animated_sprite.is_playing():
				animated_sprite.play("Fall Loop")
				
	was_on_floor = is_on_floor()
	
	# Dash Ability
	if Input.is_action_just_pressed("Dash") and dash_cooldown.is_stopped():
		direction = LAST_DIRECTION
		SPEEDF = SPEED + 400
		IS_DASHING = true
		animated_sprite.play("Dash")
		dash_cooldown.start()
		dash_length.start()
	
	# Movement
	if IS_RUNNING:
		current_speed = SPEED * 1.5
	else:
		current_speed = SPEED
	
	if IS_ATTACKING:
		velocity.x = LAST_DIRECTION * 250
	else:
		if IS_DASHING:
			velocity.x = LAST_DIRECTION * SPEEDF
		elif direction:
			velocity.x = direction * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func start_light_attack():
	IS_ATTACKING = true
	var attack_anim = light_attack_animations.pick_random()
	animated_sprite.play(attack_anim)
	hitbox.monitoring = true

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation in light_attack_animations:
		end_attack()

func end_attack():
	IS_ATTACKING = false
	hitbox.monitoring = false

func _on_dash_cooldown_timeout() -> void:
	SPEEDF = SPEED

func _on_dash_length_timeout() -> void:
	IS_DASHING = false
