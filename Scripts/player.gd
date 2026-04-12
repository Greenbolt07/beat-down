extends CharacterBody2D

const SPEED := 200.0
const JUMP_VELOCITY := -300.0
const DASH_SPEED_BONUS := 400.0
const RUN_SPEED_MULTIPLIER := 1.5
const ATTACK_LUNGE_SPEED := 400.0
const GROUND_ACCELERATION := 1400.0
const GROUND_DECELERATION := 1800.0
const AIR_ACCELERATION := 900.0
const AIR_DECELERATION := 700.0
const DASH_ACCELERATION := 2600.0
const ATTACK_LUNGE_ACCELERATION := 2200.0
const WALL_JUMP_VELOCITY := -400.0
const WALL_JUMP_PUSH := 300.0
const HANG_TIME := 1.0
const LIGHT_ATTACK_ANIMATIONS := [
	"Melee Attack Light 1",
	# "Melee Attack Light 2",
	# "Melee Attack Light 3"
]

var dash_speed := 0.0
var last_direction := -1.0
var is_dashing := false
var is_running := false
var current_speed := SPEED
var was_on_floor := true
var was_on_wall := true
var wall_past := false
var jump_time := 0.0
var wall_time := 1.0
var can_lunge := false
var is_attacking := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_cooldown: Timer = $DashCooldown
@onready var dash_length: Timer = $DashLength
@onready var hitbox: Area2D = $AnimatedSprite2D/Area2D
@onready var past_timer: Timer = $Past

func _ready() -> void:
	hitbox.monitoring = false

func _physics_process(delta: float) -> void:
	# Process state in a fixed order so animation and movement react to the same frame of input.
	_apply_gravity(delta)
	_handle_jump_input()

	var direction := _get_input_direction()
	_handle_attack_input()
	_update_running_state()
	_update_wall_time(delta)
	_update_animation(direction)

	was_on_floor = is_on_floor()
	was_on_wall = is_on_wall()

	direction = _handle_dash_input(direction)
	_update_wall_past_state(direction)
	_update_jump_timer(delta)
	_apply_wall_slide(delta, direction)
	_update_horizontal_velocity(direction, delta)
		
	move_and_slide()

func _process(_delta: float) -> void:
	# Unlock the lunge after the attack animation reaches its active frames.
	if is_attacking and !can_lunge:
		if animated_sprite.frame >= 3:
			can_lunge = true

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("Jump") and is_on_floor() and !is_attacking:
		velocity.y = JUMP_VELOCITY

func _get_input_direction() -> float:
	var direction := Input.get_axis("Left", "Right")

	if direction > 0.0:
		set_player_facing(-1.0)
	elif direction < 0.0:
		set_player_facing(1.0)

	if direction != 0.0:
		last_direction = direction

	return direction

func _handle_attack_input() -> void:
	if Input.is_action_just_pressed("Light Attack") and !is_attacking:
		start_light_attack()

func _update_running_state() -> void:
	is_running = Input.is_action_pressed("Sprint")
	current_speed = SPEED * RUN_SPEED_MULTIPLIER if is_running else SPEED

func _update_wall_time(delta: float) -> void:
	wall_time += delta
	if !is_on_wall():
		wall_time = 1.0

func _update_animation(direction: float) -> void:
	if is_attacking:
		return

	if is_dashing:
		animated_sprite.play("Dash")
		return

	if is_on_floor():
		animated_sprite.speed_scale = wall_time
		if direction == 0.0:
			animated_sprite.play("Idle")
		elif is_running:
			animated_sprite.play("Run")
		else:
			animated_sprite.play("Walk")
		return

	if _can_wall_slide(direction):
		if velocity.y < 20.0:
			animated_sprite.play("Hang")
		else:
			animated_sprite.play("Wall Slide")
			animated_sprite.speed_scale = wall_time / 3.0
		return

	if was_on_floor or was_on_wall:
		# Play the transition once when leaving a stable surface before looping the fall animation.
		animated_sprite.play("Fall Start")
	elif animated_sprite.animation == "Fall Start" and !animated_sprite.is_playing():
		animated_sprite.play("Fall Loop")

func _handle_dash_input(direction: float) -> float:
	if Input.is_action_just_pressed("Dash") and dash_cooldown.is_stopped():
		dash_speed = SPEED + DASH_SPEED_BONUS
		is_dashing = true
		animated_sprite.play("Dash")
		dash_cooldown.start()
		dash_length.start()
		return last_direction

	return direction

func _update_wall_past_state(direction: float) -> void:
	if _can_wall_slide(direction):
		# Preserve wall contact briefly so horizontal movement does not instantly resume on separation.
		wall_past = true
		past_timer.start()
	else:
		wall_past = false
		past_timer.stop()

func _update_jump_timer(delta: float) -> void:
	jump_time += delta
	if Input.is_action_just_pressed("Jump"):
		jump_time = 0.0

func _apply_wall_slide(delta: float, direction: float) -> void:
	if !_can_wall_slide(direction):
		return

	var wall_normal_x := get_wall_normal().x
	if wall_normal_x == -1.0:
		_apply_wall_slide_motion(delta, 50.0, -50.0, wall_normal_x)
	elif wall_normal_x == 1.0:
		_apply_wall_slide_motion(delta, 200.0, -200.0, wall_normal_x)

func _can_wall_slide(direction: float) -> bool:
	if !is_on_wall_only() or is_on_floor():
		return false

	var wall_normal_x := get_wall_normal().x
	if direction == 0.0:
		return true

	return is_equal_approx(direction, -wall_normal_x)

func _apply_wall_slide_motion(delta: float, fall_scale: float, fall_offset: float, wall_normal_x: float) -> void:
	# Hold briefly on contact, then ramp into a slide speed based on time spent off the floor.
	if jump_time < HANG_TIME:
		velocity.y = 0.0
	else:
		velocity.y = fall_scale * jump_time + fall_offset
		velocity += get_gravity() * delta

	if Input.is_action_pressed("Jump"):
		velocity.y = WALL_JUMP_VELOCITY
		velocity.x = wall_normal_x * WALL_JUMP_PUSH

func _update_horizontal_velocity(direction: float, delta: float) -> void:
	if is_attacking:
		if can_lunge:
			velocity.x = move_toward(
				velocity.x,
				last_direction * ATTACK_LUNGE_SPEED,
				ATTACK_LUNGE_ACCELERATION * delta
			)
		return

	if wall_past and !is_on_wall_only():
		wall_past = false

	if wall_past:
		return

	if is_dashing:
		velocity.x = move_toward(velocity.x, last_direction * dash_speed, DASH_ACCELERATION * delta)
		return

	var target_speed := direction * current_speed
	var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var deceleration := GROUND_DECELERATION if is_on_floor() else AIR_DECELERATION

	if direction:
		var rate := acceleration
		if velocity.x != 0.0 and signf(velocity.x) != signf(direction):
			rate = deceleration
		velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

func set_player_facing(facing_x: float) -> void:
	transform = Transform2D(Vector2(facing_x, 0.0), Vector2(0.0, 1.0), transform.origin)

func start_light_attack() -> void:
	can_lunge = false
	is_attacking = true
	var attack_anim = LIGHT_ATTACK_ANIMATIONS.pick_random()
	animated_sprite.play(attack_anim)
	hitbox.monitoring = true

func reset_to_position(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	dash_speed = 0.0
	is_dashing = false
	is_running = false
	wall_past = false
	jump_time = 0.0
	wall_time = 1.0
	can_lunge = false
	is_attacking = false
	hitbox.monitoring = false
	animated_sprite.play("Idle")

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation in LIGHT_ATTACK_ANIMATIONS:
		end_attack()

func end_attack() -> void:
	is_attacking = false
	hitbox.monitoring = false

func _on_dash_cooldown_timeout() -> void:
	dash_speed = SPEED

func _on_dash_length_timeout() -> void:
	is_dashing = false

func _on_past_timeout() -> void:
	wall_past = false
