extends CanvasLayer

## 开发者浮动面板。
##
## 目前只提供“立即收集跟随中的草莓”这一调试按钮；后续的天赋、道具、
## 随机地图等调试功能，都可以作为新按钮继续挂到 Window/VBox 下。
## 按 F1 显示/隐藏，拖动面板空白处可以移动窗口位置。

const STRAWBERRY_GROUP := "strawberries"

@onready var window_panel: PanelContainer = $Window
@onready var collect_strawberries_button: Button = $Window/VBox/CollectStrawberriesButton
@onready var status_label: Label = $Window/VBox/Status

var _dragging := false
var _collected_count := 0


func _ready() -> void:
	collect_strawberries_button.pressed.connect(_on_collect_strawberries_pressed)
	window_panel.gui_input.connect(_on_window_gui_input)
	_refresh_status()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()
		return

	# 鼠标在面板之外松开时，同样要结束拖动。
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_dragging = false


func _on_window_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_dragging = true
	elif event is InputEventMouseMotion and _dragging:
		window_panel.position += event.relative


func _on_collect_strawberries_pressed() -> void:
	var amount := _collect_following_strawberries()
	_collected_count += amount

	if amount > 0:
		print("[DevPanel] 收集了 %d 枚跟随中的草莓。" % amount)
	else:
		print("[DevPanel] 当前没有跟随中的草莓。")

	_refresh_status("本局已收集 %d 枚（本次 %d 枚）" % [_collected_count, amount])


## 立即收集场景中所有正在跟随玩家的草莓，返回本次收集的数量。
func _collect_following_strawberries() -> int:
	var amount := 0
	for node in get_tree().get_nodes_in_group(STRAWBERRY_GROUP):
		if not node.has_method("collect"):
			continue
		if node.has_method("is_following") and not node.is_following():
			continue
		if node.collect():
			amount += 1
	return amount


func _refresh_status(message := "") -> void:
	if message.is_empty():
		status_label.text = "本局已收集 %d 枚草莓" % _collected_count
	else:
		status_label.text = message
