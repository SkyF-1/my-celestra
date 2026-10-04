extends Node
class_name ItemBelt

## 道具栏：三个独立栏位，不可堆叠。
##
## 戳破道具商店的红泡泡会往这里放道具；以后拾取掉落的道具也走这里。
## 道具本身的效果（金羽毛 / 风 / 弹球）与背包菜单属于道具系统，尚未实装。
##
## 节点位置：挂载于关卡根节点下，加入组 "item_belt"。

signal changed

const GROUP := "item_belt"
const SLOT_COUNT := 3

## 空栏位用空字符串表示。
var _slots: Array[String] = ["", "", ""]


func _enter_tree() -> void:
	add_to_group(GROUP)


## 三个栏位的内容快照，空栏位为 ""。
func get_slots() -> Array[String]:
	return _slots.duplicate()


func get_slot(index: int) -> String:
	if index < 0 or index >= _slots.size():
		return ""
	return _slots[index]


## 是否还有空栏位。
func has_space() -> bool:
	return _slots.has("")


## 放入一个道具，返回所在栏位号；栏位已满或 id 为空时返回 -1。
func add(item_id: String) -> int:
	if item_id.is_empty():
		return -1
	var index := _slots.find("")
	if index < 0:
		return -1
	_slots[index] = item_id
	changed.emit()
	return index


## 直接设定某个栏位（用于替换），下标越界时忽略。
func set_slot(index: int, item_id: String) -> void:
	if index < 0 or index >= _slots.size():
		return
	_slots[index] = item_id
	changed.emit()


## 清空某个栏位。
func clear_slot(index: int) -> void:
	set_slot(index, "")


## 已持有的道具数量。
func count() -> int:
	var total := 0
	for item_id in _slots:
		if not item_id.is_empty():
			total += 1
	return total


## 清空所有栏位。新开一局时调用。
func reset() -> void:
	_slots.fill("")
	changed.emit()
