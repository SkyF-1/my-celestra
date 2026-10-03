extends CanvasLayer

@export var click_sfx: AudioStream
@export var pause_sfx: AudioStream
@export var resume_sfx: AudioStream
@export var back_sfx: AudioStream

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	main_menu_button.pressed.connect(_on_main_menu)
	hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_on_resume()
		else:
			_open()
		get_viewport().set_input_as_handled()

func _open() -> void:
	show()
	get_tree().paused = true
	AudioManager.play_sfx(pause_sfx)
	AudioManager.set_music_paused(true)

func _on_resume() -> void:
	AudioManager.play_sfx(resume_sfx)
	AudioManager.set_music_paused(false)
	get_tree().paused = false
	hide()

func _on_settings() -> void:
	AudioManager.play_sfx(click_sfx)
	# 设置页以后再接，先留空
	pass

func _on_main_menu() -> void:
	AudioManager.play_sfx(back_sfx)
	get_tree().paused = false
	AudioManager.set_music_paused(false)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
