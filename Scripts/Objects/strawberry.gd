extends Area2D

signal collected(strawberry: Area2D)

const STRAWBERRY_GROUP := "strawberries"

enum State { IDLE, FOLLOWING, COLLECTED }

@export_group("跟随")
@export_range(1.0, 40.0, 0.5) var follow_distance := 14.0
@export var follow_height := 7.0
@export_range(1.0, 30.0, 0.5) var spring_frequency := 10.0

@export_group("音频")
@export var sfx_collect: AudioStream

@export_group("正式收集")
## 草莓不在区块内时（例如手搭的测试关卡）用来判定"已离开原处"的水平距离。
@export var leave_distance := 64.0

var state: State = State.IDLE
var _spawn_position := Vector2.ZERO
var _carrier: CharacterBody2D
var _follow_velocity := Vector2.ZERO
## 生成时所在的区块；手搭关卡里可能为 null，此时退化为距离判定。
var _spawn_chunk: Chunk = null


func _ready() -> void:
	_spawn_position = global_position
	_spawn_chunk = _find_own_chunk()
	add_to_group(STRAWBERRY_GROUP)
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

	_check_collect()


## Whether this strawberry is currently trailing the player but not yet collected.
func is_following() -> bool:
	return state == State.FOLLOWING


## Call when game logic confirms that this following strawberry has been collected.
func collect() -> bool:
	if state != State.FOLLOWING:
		return false

	state = State.COLLECTED
	AudioManager.play_sfx(sfx_collect)
	collected.emit(self)
	_report_to_ledger()
	queue_free()
	return true


## 正式收集计入局内草莓账本，供天赋 / 道具商店消费。
func _report_to_ledger() -> void:
	for node in get_tree().get_nodes_in_group("strawberry_ledger"):
		if node is StrawberryLedger:
			node.add(1)
			return


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

	# 草莓罐头：触碰到就正式收集，不必离开原地图块再落地。
	if player.get("strawberry_can_enabled") == true:
		collect()


## 正式收集判定：玩家站在"非草莓原属区块"的地面上时收下草莓。
## 草莓没有所属区块时（手搭关卡）退化为"离开原地足够远 + 落地"。
func _check_collect() -> void:
	if not _carrier.is_on_floor():
		return

	if _spawn_chunk != null:
		var current := Chunk.find_at(get_tree(), _carrier.global_position)
		if current != null and current != _spawn_chunk:
			collect()
		return

	if absf(_carrier.global_position.x - _spawn_position.x) >= leave_distance:
		collect()


## 草莓自身所在的区块：优先看父链，其次按生成坐标查。
func _find_own_chunk() -> Chunk:
	var node := get_parent()
	while node != null:
		if node is Chunk:
			return node
		node = node.get_parent()
	return Chunk.find_at(get_tree(), global_position)


func _on_carrier_died() -> void:
	_return_to_spawn()


func _return_to_spawn() -> void:
	state = State.IDLE
	_carrier = null
	_follow_velocity = Vector2.ZERO
	global_position = _spawn_position
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
