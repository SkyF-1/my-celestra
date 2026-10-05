extends CanvasLayer

## 登顶胜利菜单。做法与暂停菜单一致：暂停游戏、播放按钮音效、提供返回选项。
##
## FinishFlag 通过 "victory_listener" 组广播胜利，因此本菜单放在关卡里的
## 任意位置都能收到，不依赖旗帜何时被生成。

## 监听 FinishFlag 广播的组。
const GROUP := "victory_listener"
## 打开期间占用，避免暂停菜单被同时调出。
const MODAL_GROUP := "modal_menu"
const MENU_SCENE := "res://Scenes/UI/main_menu.tscn"

@export var click_sfx: AudioStream

@onready var stats_label: Label = $CenterContainer/VBoxContainer/Stats
@onready var retry_button: Button = $CenterContainer/VBoxContainer/RetryButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	retry_button.pressed.connect(_on_retry)
	main_menu_button.pressed.connect(_on_main_menu)
	hide()


## FinishFlag 通过组调用。重复触发只生效一次。
func on_victory() -> void:
	if visible:
		return
	_open()


func _open() -> void:
	_refresh_stats()
	show()
	add_to_group(MODAL_GROUP)
	get_tree().paused = true
	AudioManager.set_music_paused(true)


func _close() -> void:
	remove_from_group(MODAL_GROUP)
	hide()
	get_tree().paused = false
	AudioManager.set_music_paused(false)


## 本局统计（当前只有草莓数，后续可扩展）。
func _refresh_stats() -> void:
	var berries := -1
	for node in get_tree().get_nodes_in_group("strawberry_ledger"):
		if node is StrawberryLedger:
			berries = node.get_total()
			break
	stats_label.text = "" if berries < 0 else "本局收集草莓：%d" % berries


func _on_retry() -> void:
	AudioManager.play_sfx(click_sfx)
	var level := get_tree().current_scene
	_close()
	if level != null:
		get_tree().reload_current_scene()


func _on_main_menu() -> void:
	AudioManager.play_sfx(click_sfx)
	_close()
	get_tree().change_scene_to_file(MENU_SCENE)
