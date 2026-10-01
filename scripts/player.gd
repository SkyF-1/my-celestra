extends CharacterBody2D
class_name Climber

signal jumped
signal dashed
signal landed

const GRAVITY := 1050.0
const JUMP_SPEED := -510.0
const DASH_SPEED := 520.0

var stamina := 100.0
var max_stamina := 100.0
var dash_count := 1
var max_dashes := 1
var move_speed := 195.0
var facing := 1
var dash_timer := 0.0
var wall_jump_lock := 0.0
var was_grounded := false
var anim_time := 0.0
var wind_timer := 0.0
var invulnerable := 0.0
var controls_enabled := true
var sprite: Sprite2D

func _ready() -> void:
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 28)
	collision.shape = rect
	add_child(collision)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position.y = -2
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return
	anim_time += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	wind_timer = maxf(0.0, wind_timer - delta)
	var grounded := is_on_floor()
	if grounded and not was_grounded:
		stamina = max_stamina
		dash_count = max_dashes
		landed.emit()
	was_grounded = grounded
	var horizontal := Input.get_axis("move_left", "move_right")
	var vertical := Input.get_axis("move_up", "move_down")
	var crouch := grounded and Input.is_action_pressed("move_down") and dash_timer <= 0.0
	var wall_dir := 0
	if is_on_wall():
		wall_dir = -1 if get_wall_normal().x > 0.0 else 1
	var grabbing := wall_dir != 0 and Input.is_action_pressed("grab") and stamina > 0.0 and not grounded and dash_timer <= 0.0
	if horizontal != 0.0:
		facing = int(signf(horizontal))
	if Input.is_action_just_pressed("dash") and dash_count > 0 and dash_timer <= 0.0:
		var direction := Vector2(horizontal, vertical)
		if direction == Vector2.ZERO:
			direction = Vector2(facing, 0)
		velocity = direction.normalized() * DASH_SPEED
		dash_count -= 1
		dash_timer = 0.16
		dashed.emit()
	if dash_timer > 0.0:
		dash_timer -= delta
		move_and_slide()
		_animate("Dash", 4, 0.07, "dash")
		return
	wall_jump_lock = maxf(0.0, wall_jump_lock - delta)
	if Input.is_action_just_pressed("jump") and not crouch:
		if grounded:
			velocity.y = JUMP_SPEED
			jumped.emit()
		elif wall_dir != 0 and horizontal == -wall_dir:
			velocity = Vector2(-wall_dir * 290.0, JUMP_SPEED * 0.9)
			wall_jump_lock = 0.14
			jumped.emit()
		elif grabbing and stamina >= 25.0:
			velocity = Vector2(-wall_dir * 110.0, JUMP_SPEED)
			stamina -= 25.0
			wall_jump_lock = 0.12
			jumped.emit()
	if wall_jump_lock <= 0.0:
		velocity.x = 0.0 if crouch else horizontal * move_speed
	if grabbing:
		velocity.y = vertical * 105.0
		stamina = maxf(0.0, stamina - (25.0 if vertical != 0.0 else 12.0) * delta * (0.4 if wind_timer > 0.0 else 1.0))
	else:
		var gravity_scale := 0.42 if wind_timer > 0.0 else 1.0
		velocity.y += GRAVITY * gravity_scale * delta
		if Input.is_action_just_released("jump") and velocity.y < -110.0:
			velocity.y = -110.0
		var falling_limit := 600.0 if Input.is_action_pressed("move_down") else 340.0
		if wall_dir != 0 and horizontal == wall_dir and velocity.y > 0.0:
			falling_limit = 85.0
		velocity.y = minf(velocity.y, falling_limit)
	move_and_slide()
	if crouch:
		_animate("Crouch", 1, 0.1, "duck", false)
	elif grabbing or (wall_dir != 0 and horizontal == wall_dir and not is_on_floor()):
		_animate("Climb", 15, 0.08, "climb")
	elif not is_on_floor():
		if velocity.y < 0.0:
			_animate("Jump", 4, 0.1, "jumpFast")
		elif Input.is_action_pressed("move_down"):
			_animate("FastFall", 11, 0.07, "bigfall")
		else:
			_animate("Fall", 8, 0.08, "fall")
	elif absf(velocity.x) > 1.0:
		_animate("Run", 12, 0.065, "runFast")
	else:
		_animate("Idle", 9, 0.12, "idle")
	sprite.flip_h = facing < 0

func _animate(folder: String, frames: int, frame_time: float, prefix: String, numbered: bool = true) -> void:
	var name := "%s%02d" % [prefix, int(anim_time / frame_time) % frames] if numbered else prefix
	var file := "res://Assets/Graphics/Player/%s/%s.png" % [folder, name]
	if ResourceLoader.exists(file):
		sprite.texture = load(file)
