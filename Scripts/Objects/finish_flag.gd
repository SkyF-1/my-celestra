extends Area2D

signal victory

## 宣告胜利时通过该组广播，避免与具体关卡耦合。
const VICTORY_LISTENER_GROUP := "victory_listener"

@export var sfx_victory: AudioStream

@onready var prompt: Label = $Prompt

var _player_inside := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_trigger_victory()

func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_inside = false
	prompt.visible = false

func _trigger_victory() -> void:
	_player_inside = false
	prompt.visible = false
	AudioManager.play_sfx(sfx_victory)
	victory.emit()
	get_tree().call_group(VICTORY_LISTENER_GROUP, "on_victory")

func _is_player(body: Node2D) -> bool:
	return body is CharacterBody2D and body.has_method("die")
