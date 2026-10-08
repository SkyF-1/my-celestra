extends Area2D

@export var texture_inactive: Texture2D
@export var texture_active: Texture2D
@export var sfx_checkpoint: AudioStream
@export var respawn_offset := Vector2(0, -8)

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt: Label = $Prompt

var _player_inside: Node2D = null
var _activated := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.texture = texture_inactive
	prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _activated or _player_inside == null:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_activate()

func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_inside = body
	if not _activated:
		prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body != _player_inside:
		return
	_player_inside = null
	prompt.visible = false

func _activate() -> void:
	_activated = true
	prompt.visible = false
	sprite.texture = texture_active
	AudioManager.play_sfx(sfx_checkpoint)

	if _player_inside and _player_inside.has_method("set_spawn_point"):
		_player_inside.set_spawn_point(global_position + respawn_offset)

	# 存档后相机下边界上移到本区块底部：从这里往下坠落会判定死亡。
	var chunk := _find_own_chunk()
	var rig := get_tree().get_first_node_in_group(CameraRig.CAMERA_GROUP)
	if chunk != null and rig != null and rig.has_method("set_bottom_limit"):
		rig.set_bottom_limit(chunk.global_position.y + chunk.chunk_size.y)


## 篝火自身所在的区块。
func _find_own_chunk() -> Chunk:
	var node := get_parent()
	while node != null:
		if node is Chunk:
			return node
		node = node.get_parent()
	return null

func _is_player(body: Node2D) -> bool:
	return body is CharacterBody2D and body.has_method("die")
