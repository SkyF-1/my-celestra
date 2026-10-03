extends Area2D

signal collected(strawberry: Area2D)

enum State { IDLE, FOLLOWING, COLLECTED }

@export_group("跟随")
@export_range(1.0, 40.0, 0.5) var follow_distance := 14.0
@export var follow_height := 7.0
@export_range(1.0, 30.0, 0.5) var spring_frequency := 10.0

@export_group("音频")
@export var sfx_collect: AudioStream

var state: State = State.IDLE
var _spawn_position := Vector2.ZERO
var _carrier: CharacterBody2D
var _follow_velocity := Vector2.ZERO


func _ready() -> void:
	_spawn_position = global_position
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if state != State.FOLLOWING:
		return
	if not is_instance_valid(_carrier):
		_return_to_spawn()
		return

	var direction := signf(_carrier.velocity.x)
	if direction == 0.0:
		direction = float(_carrier.get("facing"))
	var target := _carrier.global_position + Vector2(-direction * follow_distance, -follow_height)

	# Critically damped spring integration keeps the trail smooth at different frame rates.
	var offset := global_position - target
	var spring_delta := (_follow_velocity + spring_frequency * offset) * delta
	var decay := exp(-spring_frequency * delta)
	global_position = target + (offset + spring_delta) * decay
	_follow_velocity = (_follow_velocity - spring_frequency * spring_delta) * decay


## Call when game logic confirms that this following strawberry has been collected.
func collect() -> bool:
	if state != State.FOLLOWING:
		return false

	state = State.COLLECTED
	AudioManager.play_sfx(sfx_collect)
	collected.emit(self)
	queue_free()
	return true


func _on_body_entered(body: Node2D) -> void:
	if state != State.IDLE or not (body is CharacterBody2D):
		return

	var player := body as CharacterBody2D
	if not player.has_method("die"):
		return

	_carrier = player
	_follow_velocity = Vector2.ZERO
	state = State.FOLLOWING
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if player.has_signal("died"):
		player.connect("died", _on_carrier_died, CONNECT_ONE_SHOT)


func _on_carrier_died() -> void:
	_return_to_spawn()


func _return_to_spawn() -> void:
	state = State.IDLE
	_carrier = null
	_follow_velocity = Vector2.ZERO
	global_position = _spawn_position
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
