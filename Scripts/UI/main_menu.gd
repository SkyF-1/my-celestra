extends Control

@export var menu_loop: AudioStream
@export var click: AudioStream

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)

	# 播放菜单音乐
	AudioManager.play_music_fade(menu_loop)

func _on_start() -> void:
	AudioManager.play_sfx(click)
	get_tree().change_scene_to_file("res://Scenes/Levels/test_level.tscn")

func _on_settings() -> void:
	AudioManager.play_sfx(click)
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")

func _on_quit() -> void:
	get_tree().quit()
