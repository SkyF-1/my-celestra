extends Node2D

@onready var finish_flag: Area2D = $FinishFlag

@export var gameplay_loop :AudioStream

func _ready() -> void:
	finish_flag.victory.connect(_on_victory)
	AudioManager.play_music(gameplay_loop)

func _on_victory() -> void:
	print("登顶成功！")
