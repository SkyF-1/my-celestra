extends Node
class_name Talents

## 玩家天赋组件。
##
## 记录每个天赋的等级，负责扣费、升级、等级上限判定，并把效果写回玩家的
## 天赋修正字段：run_bonus / stamina_bonus / dashes_bonus /
## strawberry_can_enabled，随后调用 player.recalc_stats() 重算实际属性。
## 修正值是每次全量重算的，因此重复结算、调整天赋池都不会算错。
##
## 节点位置：挂载于关卡根节点下，加入组 "talents"。
## 依赖玩家提供 recalc_stats() 与上述修正字段（见 Scripts/Entities/player.gd），
## 依赖草莓账本消费（见 Scripts/System/strawberry_ledger.gd，加入组 "strawberry_ledger"）。

## 某个天赋升级后发出。
signal level_changed(talent: Talent, level: int)
## 任意等级变化后发出，供 UI 刷新。
signal changed

const PLAYER_GROUP := "player"
const LEDGER_GROUP := "strawberry_ledger"
const GROUP := "talents"

## 内置天赋池；在编辑器里给 talent_pool 赋值即可覆盖。
const DEFAULT_POOL: Array = [
	preload("res://Assets/Talents/toughness.tres"),
	preload("res://Assets/Talents/haste.tres"),
	preload("res://Assets/Talents/more_dash.tres"),
	preload("res://Assets/Talents/strawberry_can.tres"),
]

## 天赋池。留空时使用 DEFAULT_POOL。
@export var talent_pool: Array[Talent] = []

## 玩家节点；留空时自动到 "player" 分组里找。
@export var player: CharacterBody2D

## 草莓账本；留空时自动到 "strawberry_ledger" 分组里找。
@export var ledger: StrawberryLedger

## talent_name → 等级
var _levels := {}
var _player: CharacterBody2D
var _ledger: StrawberryLedger


func _enter_tree() -> void:
	# 入树即入组：保证同场景里更早 ready 的商店容器也能找到本组件。
	add_to_group(GROUP)


func _ready() -> void:
	if talent_pool.is_empty():
		talent_pool.assign(DEFAULT_POOL)
	_resolve_player()
	_resolve_ledger()
	apply_to_player()


func _physics_process(_delta: float) -> void:
	# 玩家可能比组件更晚实例化；拿到之后把已获得的天赋补应用一次。
	if not is_instance_valid(_player):
		_resolve_player()
		if is_instance_valid(_player):
			apply_to_player()


# ═══════════════════════════════════════════════════════
# 查询
# ═══════════════════════════════════════════════════════
## 该天赋当前等级，未获得时为 0。
func get_level(talent: Talent) -> int:
	if talent == null:
		return 0
	return int(_levels.get(talent.talent_name, 0))


## 该天赋是否已到等级上限。
func is_maxed(talent: Talent) -> bool:
	return talent != null and get_level(talent) >= talent.max_level


## 现在能否购买：未满级，且账本余额足够。
func can_buy(talent: Talent) -> bool:
	if talent == null or is_maxed(talent):
		return false
	var ledger := _get_ledger()
	return ledger != null and ledger.can_afford(talent.cost)


## 商店可刷新的天赋（已满级的会被排除）。
func get_available_talents() -> Array[Talent]:
	var result: Array[Talent] = []
	for talent in talent_pool:
		if not is_maxed(talent):
			result.append(talent)
	return result


## 是否全部天赋都已满级。满级后不应再生成天赋商店地块。
func all_maxed() -> bool:
	return get_available_talents().is_empty()


## 当前已有的天赋等级快照：talent_name → 等级。
func get_levels() -> Dictionary:
	return _levels.duplicate()


# ═══════════════════════════════════════════════════════
# 升级
# ═══════════════════════════════════════════════════════
## 尝试购买并升级该天赋。草莓不足或已满级时返回 false 且不产生任何变化。
func buy(talent: Talent) -> bool:
	if not can_buy(talent):
		return false
	var ledger := _get_ledger()
	if ledger == null or not ledger.spend(talent.cost):
		return false
	set_level(talent, get_level(talent) + 1)
	return true


## 直接提升等级、不扣草莓。供调试、奖励与存档读取使用。
func grant(talent: Talent, amount := 1) -> void:
	set_level(talent, get_level(talent) + amount)


## 直接设定等级，会自动钳制到 [0, max_level]。
func set_level(talent: Talent, level: int) -> void:
	if talent == null:
		return
	var clamped := clampi(level, 0, maxi(talent.max_level, 0))
	if clamped == get_level(talent):
		return

	_levels[talent.talent_name] = clamped
	apply_to_player()
	level_changed.emit(talent, clamped)
	changed.emit()


## 清空全部天赋等级。新开一局时调用。
func reset() -> void:
	if _levels.is_empty():
		return
	_levels.clear()
	apply_to_player()
	changed.emit()


# ═══════════════════════════════════════════════════════
# 生效
# ═══════════════════════════════════════════════════════
## 依据天赋池与当前等级，全量重算玩家身上的天赋修正并刷新属性。
func apply_to_player() -> void:
	if not is_instance_valid(_player):
		_resolve_player()
		if not is_instance_valid(_player):
			return

	var run_bonus := 0.0
	var stamina_bonus := 0.0
	var dashes_bonus := 0
	var strawberry_can := false

	for talent in talent_pool:
		var level := get_level(talent)
		if level <= 0:
			continue
		match talent.effect_key:
			"stamina":
				stamina_bonus += talent.per_level * level
			"speed":
				run_bonus += talent.per_level * level
			"dash":
				dashes_bonus += roundi(talent.per_level * level)
			"special":
				# 目前 special 只有草莓罐头一个，共用玩家身上的同一个开关。
				strawberry_can = true

	_player.run_bonus = run_bonus
	_player.stamina_bonus = stamina_bonus
	_player.dashes_bonus = dashes_bonus
	_player.strawberry_can_enabled = strawberry_can
	_player.recalc_stats()


# ═══════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════
func _resolve_player() -> void:
	_player = null
	if is_instance_valid(player) and player.has_method("recalc_stats"):
		_player = player
		return
	for node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		if node is CharacterBody2D and node.has_method("recalc_stats"):
			_player = node
			return


func _resolve_ledger() -> void:
	_ledger = null
	if is_instance_valid(ledger):
		_ledger = ledger
		return
	for node in get_tree().get_nodes_in_group(LEDGER_GROUP):
		if node is StrawberryLedger:
			_ledger = node
			return


func _get_ledger() -> StrawberryLedger:
	if not is_instance_valid(_ledger):
		_resolve_ledger()
	return _ledger
