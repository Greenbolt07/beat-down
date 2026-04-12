extends CharacterBody2D

# Movement Variables
const SPEED = 200
var SPEEDF :int= 0
var LAST_DIRECTION :float= -1
var IS_DASHING := false
var IS_RUNNING := false
var current_speed = SPEED
const JUMP_VELOCITY = -300.0
var was_on_floor := true
var was_on_wall := true
var wall_past := false
var time = 0
var Hang_time = 1
var Walltime = 1


# Other variables
var CAN_LUNGE := false
var IS_ATTACKING := false
var light_attack_animations = [
	"Melee Attack Light 1",
	"Melee Attack Light 2",
    "Melee Attack Light 3"
]
const wally = -400
const wallx = 250

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_cooldown: Timer = $DashCooldown
@onready var dash_length: Timer = $DashLength
@onready var hitbox: Area2D = $AnimatedSprite2D/Area2D
@onready var past: Timer = $Past

func _ready():
	hitbox.monitoring = false

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor() and !IS_ATTACKING:
		velocity.y = JUMP_VELOCITY

	# Determines player didrection.
	var direction := Input.get_axis("Left", "Right")
	if direction > 0:
		set_player_facing(-1.0)
	elif direction < 0:
		set_player_facing(1.0)
	if direction != 0:
		LAST_DIRECTION = direction
	
	# Detects attack
	if Input.is_action_just_pressed("Light Attack") and !IS_ATTACKING:
		start_light_attack()
	
	# Determines if player is sprinting
	IS_RUNNING = Input.is_action_pressed("Sprint")

	Walltime += delta
	if !is_on_wall():
		Walltime = 1
	
	# Determines 
	if IS_ATTACKING:
		pass
	elif IS_DASHING:
		animated_sprite.play("Dash")
	else:
		if is_on_floor():
			animated_sprite.speed_scale = Walltime
			if direction == 0:
				animated_sprite.play("Idle")
			else:
				if IS_RUNNING:
					animated_sprite.play("Run")
				else:
					animated_sprite.play("Walk")
		else:
			if is_on_wall():
				if velocity.y < 20:
					animated_sprite.play("Hang")
				else:
					animated_sprite.play("Wall Slide")
					animated_sprite.speed_scale = Walltime/3
			else:
				if was_on_floor or was_on_wall:
					animated_sprite.play("Fall Start")
				elif animated_sprite.animation == "Fall Start" and !animated_sprite.is_playing():
					animated_sprite.play("Fall Loop")
				
	was_on_floor = is_on_floor()
	was_on_wall = is_on_wall()
	
	# Dash Ability
	if Input.is_action_just_pressed("Dash") and dash_cooldown.is_stopped():
		direction = LAST_DIRECTION
		SPEEDF = SPEED + 400
		IS_DASHING = true
		animated_sprite.play("Dash")
		dash_cooldown.start()
		dash_length.start()

	# Was on wall????
	if is_on_wall_only():
		wall_past = true
		past.start()
	
	# Time since Jump
	time += delta
	if Input.is_action_just_pressed("Jump"):
		time = 0

	# Slide on wall
	if is_on_wall_only():
		if get_wall_normal().x == -1 and Input.is_action_pressed("Right") or !Input.is_action_pressed("Left"):
			if not is_on_floor():
				if time < Hang_time:
					velocity.y = 0
				else:
					velocity.y = 50 * time - 50
					velocity += get_gravity() * delta
				if Input.is_action_pressed("Jump"):
					velocity.y = wally
					velocity.x = get_wall_normal().x * wallx
		if get_wall_normal().x == 1 and Input.is_action_pressed("Left") or !Input.is_action_pressed("Right"):
			if not is_on_floor():
				if time < Hang_time:
					velocity.y = 0
				else:
					velocity.y = 200 * time - 200
					velocity += get_gravity() * delta
				if Input.is_action_pressed("Jump"):
					velocity.y = wally
					velocity.x = get_wall_normal().x * wallx

	# Movement
	if IS_RUNNING:
		current_speed = SPEED * 1.5
	else:
		current_speed = SPEED
	if IS_ATTACKING:
		if CAN_LUNGE:
			velocity.x = LAST_DIRECTION * 400
		else:
			pass
	else:
		if wall_past:
			pass
		else:
			if IS_DASHING:
				velocity.x = LAST_DIRECTION * SPEEDF
			elif direction:
				velocity.x = direction * current_speed
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
		
	move_and_slide()
	
func _process(_delta):
	if IS_ATTACKING and !CAN_LUNGE:
		if animated_sprite.frame >= 3:
			CAN_LUNGE = true

func set_player_facing(facing_x: float) -> void:
	transform = Transform2D(Vector2(facing_x, 0.0), Vector2(0.0, 1.0), transform.origin)

func start_light_attack():
	CAN_LUNGE = false
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

func _on_past_timeout() -> void:
	wall_past = false
