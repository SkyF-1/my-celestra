extends Node2D
class_name ShopBubbleContainer

## 商店泡泡容器：泡泡等间距横向排列，统一处理商店行为。
##
## 排布：原点位于整排中间、间距 36（整排宽 104），关卡里把本节点放在商店位置
## 即可——例如放在 (236, 136)，泡泡就会落在 200 / 236 / 272，与手摆的一致。
##
## 内容：天赋商店在 _ready 时从 Talents 组件重抽，保证区块生成时是随机的。
## 容器是 chunk 的子节点、子节点先 ready，所以「chunk 生成即重抽」；
## 编辑器里不重抽，直接显示泡泡场景的默认数据（坚韧），方便查看排布。
##
## 规则：PICK_ONE（天赋，三选一，选中后其余泡泡直接消失）
##       TAKE_ALL（道具，各买各的，允许全要）

## 成功买走一个泡泡时发出（泡泡上的 talent / item_id 即内容）。
signal purchased(bubble: ShopBubble)
## 商店被买空（PICK_ONE 选完，或 TAKE_ALL 全部买完）时发出。
signal exhausted

enum Mode { PICK_ONE, TAKE_ALL }
enum ContentKind { TALENT, ITEM }

const TALENTS_GROUP := "talents"
const LEDGER_GROUP := "strawberry_ledger"
const BELT_GROUP := "item_belt"

## 道具商店固定价格：每个道具 1 颗草莓。
const ITEM_PRICE := 1
## 道具池，与 ItemDrop 的标识保持一致。
const ITEM_POOL := ["golden_feather", "wind", "pinball"]

## 购买规则。
@export var mode := Mode.PICK_ONE
## 泡泡内容的来源。
@export var content_kind := ContentKind.TALENT
## 天赋组件；留空时自动到 "talents" 分组里找。
@export var talents: Talents

var _bubbles: Array[ShopBubble] = []
var _rng := RandomNumberGenerator.new()
var _interactive := true


func _ready() -> void:
	_collect_bubbles()
	_rng.randomize()
	fill()


# ═══════════════════════════════════════════════════════
# 内容
# ═══════════════════════════════════════════════════════
## 重抽内容并刷新全部泡泡。区块生成时调用即可保证随机。
func fill() -> void:
	_collect_bubbles()
	_interactive = true
	match content_kind:
		ContentKind.TALENT:
			_fill_talents()
		ContentKind.ITEM:
			_fill_items()


## 直接指定每个泡泡的内容，多退少补。调试、存档读取用。
func set_contents(contents: Array[Talent]) -> void:
	_collect_bubbles()
	_interactive = true
	for i in _bubbles.size():
		var bubble := _bubbles[i]
		if i < contents.size() and contents[i] != null:
			bubble.talent = contents[i]
		else:
			_break(bubble)


## 当前可抽取的天赋（已满级的不在内）。
func get_available_talents() -> Array[Talent]:
	var source := _get_talents()
	if source == null:
		return []
	return source.get_available_talents()


func get_bubbles() -> Array[ShopBubble]:
	return _bubbles.duplicate()


# ═══════════════════════════════════════════════════════
# 购买
# ═══════════════════════════════════════════════════════
func _on_bubble_interact(bubble: ShopBubble) -> void:
	if not _interactive or not _bubbles.has(bubble):
		return
	if not _purchase(bubble):
		return

	purchased.emit(bubble)
	_break(bubble)

	if mode == Mode.PICK_ONE:
		# 三选一：其余泡泡一并破裂，商店不再可交互。
		_interactive = false
		for other in _bubbles:
			if other != bubble:
				_break(other)
		exhausted.emit()
	elif not _has_remaining():
		exhausted.emit()


## 完成一次购买。买不起 / 栏位不足 / 缺少组件时返回 false，不产生任何变化。
func _purchase(bubble: ShopBubble) -> bool:
	if bubble.talent != null:
		return _purchase_talent(bubble)
	if not bubble.item_id.is_empty():
		return _purchase_item(bubble)
	return false


func _purchase_talent(bubble: ShopBubble) -> bool:
	var source := _get_talents()
	if source == null:
		push_warning("[ShopBubbleContainer] 关卡中没有 Talents 组件，无法购买。")
		return false
	if not source.can_buy(bubble.talent):
		print("[ShopBubbleContainer] 戳破「%s」失败：草莓不足（需要 %d）或已满级。" % [
			bubble.talent.talent_name, bubble.talent.cost,
		])
		return false
	return source.buy(bubble.talent)


func _purchase_item(bubble: ShopBubble) -> bool:
	var ledger := _get_ledger()
	if ledger == null:
		push_warning("[ShopBubbleContainer] 关卡中没有 StrawberryLedger，无法购买道具。")
		return false
	var belt := _get_belt()
	if belt == null:
		push_warning("[ShopBubbleContainer] 关卡中没有 ItemBelt，无法收纳道具。")
		return false
	if not belt.has_space():
		print("[ShopBubbleContainer] 道具栏已满，无法戳破「%s」。" % _item_name(bubble.item_id))
		return false
	if not ledger.spend(ITEM_PRICE):
		print("[ShopBubbleContainer] 草莓不足，无法戳破「%s」（需要 %d）。" % [
			_item_name(bubble.item_id), ITEM_PRICE,
		])
		return false
	return belt.add(bubble.item_id) >= 0


# ═══════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════
func _fill_talents() -> void:
	var source := _get_talents()
	if source == null:
		# 没有天赋组件（例如单独的演示关卡）时保留泡泡的默认内容。
		push_warning("[ShopBubbleContainer] 关卡中没有 Talents 组件，泡泡保持默认内容。")
		return

	var picks := _pick(source.get_available_talents(), _bubbles.size())
	if picks.is_empty():
		# 天赋已全部满级：不该再出现商店内容，直接清空。
		for bubble in _bubbles:
			_break(bubble)
		exhausted.emit()
		return

	for i in _bubbles.size():
		var talent := picks[i] as Talent if i < picks.size() else null
		if talent != null:
			_bubbles[i].talent = talent
		else:
			_break(_bubbles[i])


func _fill_items() -> void:
	var picks := _pick(ITEM_POOL, _bubbles.size())
	for i in _bubbles.size():
		var bubble := _bubbles[i]
		var item_id: String = picks[i] as String if i < picks.size() else ""
		if item_id.is_empty():
			_break(bubble)
			continue
		bubble.talent = null
		bubble.kind = ShopBubble.Kind.ITEM
		bubble.item_id = item_id
		bubble.price = ITEM_PRICE
		bubble.refresh()


## 从池子里抽 count 个；不足时按策划案允许重复（补满一轮再继续抽）。
func _pick(pool: Array, count: int) -> Array:
	var picks: Array = []
	if pool.is_empty() or count <= 0:
		return picks

	var bag: Array = pool.duplicate()
	for i in count:
		if bag.is_empty():
			bag = pool.duplicate()
		var index := _rng.randi_range(0, bag.size() - 1)
		picks.append(bag[index])
		bag.remove_at(index)
	return picks


func _collect_bubbles() -> void:
	_bubbles.clear()
	for child in get_children():
		if child is ShopBubble:
			_bubbles.append(child)
			if not child.interact_requested.is_connected(_on_bubble_interact):
				child.interact_requested.connect(_on_bubble_interact)


func _break(bubble: ShopBubble) -> void:
	if is_instance_valid(bubble) and not bubble.is_queued_for_deletion():
		bubble.break_apart()


func _has_remaining() -> bool:
	for bubble in _bubbles:
		if is_instance_valid(bubble) and not bubble.is_queued_for_deletion():
			return true
	return false


func _get_talents() -> Talents:
	if is_instance_valid(talents):
		return talents
	for node in get_tree().get_nodes_in_group(TALENTS_GROUP):
		if node is Talents:
			return node
	return null


func _get_ledger() -> StrawberryLedger:
	for node in get_tree().get_nodes_in_group(LEDGER_GROUP):
		if node is StrawberryLedger:
			return node
	return null


func _get_belt() -> ItemBelt:
	for node in get_tree().get_nodes_in_group(BELT_GROUP):
		if node is ItemBelt:
			return node
	return null


func _item_name(item_id: String) -> String:
	return str(ItemDrop.NAMES.get(item_id, item_id))
