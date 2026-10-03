extends Control

@export var back: AudioStream

@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back)

func _on_back() -> void:
	AudioManager.play_sfx(back)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
