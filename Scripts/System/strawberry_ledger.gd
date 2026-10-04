extends Node
class_name StrawberryLedger

## 局内草莓代币账本。
##
## 记录玩家已正式收集的草莓数量。天赋商店、道具商店通过本节点消费。
## 草莓为局内货币，新开一局时由关卡调用 reset() 清零。
##
## 节点位置：挂载于关卡根节点下，加入组 "strawberry_ledger"。

signal changed(total: int)

var _total := 0


func _enter_tree() -> void:
	add_to_group("strawberry_ledger")


## 增加草莓。
func add(amount := 1) -> void:
	if amount <= 0:
		return
	_total += amount
	changed.emit(_total)


## 尝试消费指定数量的草莓。
## 余额不足时返回 false 且不改变总量；成功则扣除并返回 true。
func spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if _total < amount:
		return false
	_total -= amount
	changed.emit(_total)
	return true


## 当前草莓总数。
func get_total() -> int:
	return _total


## 余额是否足以支付指定数量。
func can_afford(amount: int) -> bool:
	return _total >= amount


## 清空余额。新开一局时调用。
func reset() -> void:
	_total = 0
	changed.emit(_total)
