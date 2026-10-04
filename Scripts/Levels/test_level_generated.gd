extends Node2D

@export var gameplay_loop: AudioStream

@onready var generator: ChunkGenerator = %ChunkGenerator


func _ready() -> void:
	if gameplay_loop != null:
		AudioManager.play_music(gameplay_loop)
	generator.generate()
