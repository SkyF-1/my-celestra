extends CharacterBody2D

@export var move_speed := 142
@export var dash_speed := 200
@export var jump_strength := 230
@export var gravity := 1000
@export var max_fall := 400

var direction_x := 0.0
var facing := 1

func _physics_process(delta: float) -> void:
	direction_x = Input.get_axis("left", "right")
	facing = sign(direction_x) if direction_x != 0 else facing
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = -jump_strength
	if Input.is_action_just_pressed("dash"):
		print("dash")
	velocity.x = direction_x * move_speed
	
	velocity.y += gravity * delta
	velocity.y = minf(velocity.y, max_fall)
	
	if Input.is_action_pressed("grab"):
		if is_on_wall():
			velocity.y = 0
	animation()
	move_and_slide()

func animation():
	if direction_x:
		$AnimatedSprite2D.flip_h = direction_x < 0
	
	if is_on_floor():
		$AnimatedSprite2D.animation = "run" if direction_x else "idle"
	else:
		pass
	
	if Input.is_action_just_pressed("jump"):
		$AnimatedSprite2D.animation = "jump"
