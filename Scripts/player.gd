extends CharacterBody2D

const SPEED := 200.0
const JUMP_VELOCITY := -300.0
const DASH_SPEED_BONUS := 400.0
const RUN_SPEED_MULTIPLIER := 1.5
const ATTACK_LUNGE_SPEED := 200.0
const GROUND_ACCELERATION := 1400.0
const GROUND_DECELERATION := 1800.0
const SNEAK_DEBUFF := 1.5
const AIR_ACCELERATION := 900.0
const AIR_DECELERATION := 700.0
const DASH_ACCELERATION := 2600.0
const ATTACK_LUNGE_ACCELERATION := 2200.0
const ATTACK_GROUND_BRAKE := 600.0
const ATTACK_AIR_BRAKE := 300.0
const ATTACK_CHARGE_SPEED_MULTIPLIER := 0.45
const ATTACK_CHARGE_JUMP_MULTIPLIER := 0.65
const WALL_JUMP_VELOCITY := -400.0
const WALL_JUMP_PUSH := 300.0
const HANG_TIME := 1.0
const ATTACK_CHARGE_FRAME := 2
const LIGHT_ATTACK_ANIMATIONS := [
	"Melee Attack Light 1",
	# "Melee Attack Light 2",
	# "Melee Attack Light 3"
]

var target_wspeed :float= 0
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
var is_attack_charging := false
var can_enter_attack_charge := false
var is_attack_input_locked := false
var is_attacking := false
var is_crouching := false
var is_sliding = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_cooldown: Timer = $DashCooldown
@onready var dash_length: Timer = $DashLength
@onready var hitbox: Area2D = $AnimatedSprite2D/Area2D
@onready var past_timer: Timer = $Past
@onready var player_physics: CollisionShape2D = $"Player Physics"

func _ready() -> void:
	hitbox.monitoring = false
	player_physics.scale = Vector2(1,1)

func _input(event: InputEvent) -> void:
	if event.is_action_released("Light Attack"):
		is_attack_input_locked = false
		_resume_attack_charge()

func _physics_process(delta: float) -> void:
	# Process state in a fixed order so animation and movement react to the same frame of input.
	_apply_gravity(delta)
	_handle_jump_input()

	var direction := _get_input_direction()
	_handle_attack_input()
	_update_running_state()
	_handle_crouch_input()
	_update_wall_time(delta)
	_update_animation(direction)
	_update_playerphysics_hitbox()

	was_on_floor = is_on_floor()
	was_on_wall = is_on_wall()

	direction = _handle_dash_input(direction)
	_update_wall_past_state(direction)
	_update_jump_timer(delta)
	_apply_wall_slide(delta, direction)
	_update_is_sliding()
	_update_horizontal_velocity(direction, delta)
		
	move_and_slide()

func _process(_delta: float) -> void:
	_update_attack_input_lock()
	_update_attack_charge()

func _update_attack_input_lock() -> void:
	if is_attack_input_locked and !Input.is_action_pressed("Light Attack"):
		is_attack_input_locked = false

func _update_attack_charge() -> void:
	if !is_attacking or animated_sprite.animation not in LIGHT_ATTACK_ANIMATIONS:
		return

	if can_enter_attack_charge and !is_attack_charging and Input.is_action_pressed("Light Attack") and animated_sprite.frame >= ATTACK_CHARGE_FRAME:
		is_attack_charging = true
		can_lunge = false
		animated_sprite.frame = ATTACK_CHARGE_FRAME
		animated_sprite.pause()
		return

	if is_attack_charging and !Input.is_action_pressed("Light Attack"):
		_resume_attack_charge()

	# Unlock the lunge after the charge frame has been released and the attack continues.
	if !is_attack_charging and !can_lunge and animated_sprite.frame > ATTACK_CHARGE_FRAME:
		can_lunge = true

func _resume_attack_charge() -> void:
	if !is_attack_charging:
		return

	is_attack_charging = false
	can_enter_attack_charge = false
	animated_sprite.play()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_jump_input() -> void:
	if !Input.is_action_pressed("Jump") or !is_on_floor():
		return

	if is_attack_charging:
		velocity.y = JUMP_VELOCITY * ATTACK_CHARGE_JUMP_MULTIPLIER
		return

	if !is_attacking:
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
	if Input.is_action_just_pressed("Light Attack") and !is_attacking and !is_attack_input_locked:
		start_light_attack()

func _update_running_state() -> void:
	is_running = Input.is_action_pressed("Sprint")
	current_speed = SPEED * RUN_SPEED_MULTIPLIER if is_running and !is_crouching else SPEED

func _handle_crouch_input() -> void:
	if Input.is_action_pressed("Crouch") and is_on_floor():
		is_crouching = true
		return
	else:
		is_crouching = false

func _update_wall_time(delta: float) -> void:
	wall_time += delta
	if !is_on_wall():
		wall_time = 1.0

func _update_animation(direction: float) -> void:
	if is_attacking:
		animated_sprite.speed_scale = 1.0
		return

	if is_dashing:
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("Dash")
		return

	if is_sliding:
		animated_sprite.play("Floor Slide")
		return

	if is_crouching and !is_sliding:
		if velocity.x > -5 and velocity.x < 5:
			animated_sprite.play("Crouching")
			return
		else:
			animated_sprite.play("Sneaking")
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
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("Fall Start")
	elif animated_sprite.animation == "Fall Start" and !animated_sprite.is_playing():
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("Fall Loop")

func _handle_dash_input(direction: float) -> float:
	if Input.is_action_just_pressed("Dash") and dash_cooldown.is_stopped() and !is_attacking and !is_dashing:
		dash_speed = SPEED + DASH_SPEED_BONUS
		is_dashing = true
		animated_sprite.speed_scale = 1.0
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
		elif is_attack_charging:
			var charge_target_speed := direction * current_speed * ATTACK_CHARGE_SPEED_MULTIPLIER
			var charge_acceleration := ATTACK_GROUND_BRAKE if is_on_floor() else ATTACK_AIR_BRAKE
			velocity.x = move_toward(velocity.x, charge_target_speed, charge_acceleration * delta)
		else:
			var attack_deceleration := ATTACK_GROUND_BRAKE if is_on_floor() else ATTACK_AIR_BRAKE
			velocity.x = move_toward(velocity.x, 0.0, attack_deceleration * delta)
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
		if is_sliding:
			rate = deceleration/5
		if is_crouching:
			target_wspeed = target_speed / SNEAK_DEBUFF
		else:
			target_wspeed = target_speed
		velocity.x = move_toward(velocity.x, target_wspeed, rate * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

func set_player_facing(facing_x: float) -> void:
	transform = Transform2D(Vector2(facing_x, 0.0), Vector2(0.0, 1.0), transform.origin)

func start_light_attack() -> void:
	_stop_dash()
	can_lunge = false
	is_attack_charging = false
	can_enter_attack_charge = true
	is_attack_input_locked = true
	is_attacking = true
	var attack_anim = LIGHT_ATTACK_ANIMATIONS.pick_random()
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(attack_anim)
	hitbox.monitoring = true

func stop_attack() -> void:
	can_lunge = false
	is_attack_charging = false
	can_enter_attack_charge = false
	is_attacking = false
	hitbox.monitoring = false

func _stop_dash() -> void:
	dash_speed = 0.0
	is_dashing = false
	if !dash_length.is_stopped():
		dash_length.stop()
	_play_post_dash_animation()

func _play_post_dash_animation() -> void:
	if is_on_floor():
		return

	animated_sprite.speed_scale = 1.0
	if was_on_floor or was_on_wall:
		animated_sprite.play("Fall Start")
	else:
		animated_sprite.play("Fall Loop")

func reset_to_position(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_stop_dash()
	is_running = false
	wall_past = false
	jump_time = 0.0
	wall_time = 1.0
	can_lunge = false
	is_attack_charging = false
	can_enter_attack_charge = false
	is_attack_input_locked = false
	is_attacking = false
	hitbox.monitoring = false
	animated_sprite.speed_scale = 1.0
	animated_sprite.play("Idle")

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "Dash":
		_stop_dash()
		return

	if animated_sprite.animation in LIGHT_ATTACK_ANIMATIONS:
		end_attack()

func end_attack() -> void:
	is_attacking = false
	is_attack_charging = false
	can_enter_attack_charge = false
	hitbox.monitoring = false

func _on_dash_cooldown_timeout() -> void:
	dash_speed = SPEED

func _on_dash_length_timeout() -> void:
	_stop_dash()

func _on_past_timeout() -> void:
	wall_past = false

func _update_playerphysics_hitbox() -> void:
	if Input.is_action_pressed("Crouch"):
		if velocity.x > 150 or velocity.x < -150:
			player_physics.scale = Vector2(1,0.6)
			player_physics.position= Vector2(0,-25)
		else:
			player_physics.scale = Vector2(1,0.8)
			player_physics.position= Vector2(0,-25)
	else:
		player_physics.scale = Vector2(1,1)
		player_physics.position= Vector2(0,-30)

func _update_is_sliding():
	if is_crouching and is_on_floor_only() and (velocity.x > 150 or velocity.x < -150):
		is_sliding = true
	else:
		is_sliding = false
