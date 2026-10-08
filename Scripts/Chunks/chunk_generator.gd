extends Node
class_name ChunkGenerator

## 类型 → 变体场景数组
const CHUNK_POOLS := {
	"ordinary": [
		preload("res://Scenes/Chunks/Ordinary/ordinary_01.tscn"),
		preload("res://Scenes/Chunks/Ordinary/ordinary_02.tscn"),
		preload("res://Scenes/Chunks/Ordinary/ordinary_03.tscn"),
	],
	"danger": [
		preload("res://Scenes/Chunks/Danger/danger_01.tscn"),
	],
	"checkpoint": [
		preload("res://Scenes/Chunks/Checkpoint/checkpoint_01.tscn"),
	],
	"talent_shop": [
		preload("res://Scenes/Chunks/TalentShop/talent_shop_01.tscn"),
	],
	"item_shop": [
		preload("res://Scenes/Chunks/ItemShop/item_shop_01.tscn"),
	],
	"reward": [
		preload("res://Scenes/Chunks/Reward/reward_01.tscn"),
	],
	"finish": [
		preload("res://Scenes/Chunks/Finish/finish_01.tscn"),
	],
	"exit": [
		preload("res://Scenes/Chunks/Exit/exit_01.tscn"),
		preload("res://Scenes/Chunks/Exit/exit_02.tscn"),
	],
}

## 水平走廊可用的类型（都具备左/右开口）。
## 目前按类型等概率抽取，后续再接入权重/节律。
const CORRIDOR_TYPES: Array[String] = ["ordinary", "danger", "talent_shop"]

## 山脚起点场景：稳定的平地，只有左右开口。
const START_SCENE := preload("res://Scenes/Chunks/Starter/starter_01.tscn")

## 方向配对：某方向的开口，需要对接到对侧的开口。
const OPPOSITE_SIDE := {
	OpeningMarker.Side.TOP: OpeningMarker.Side.BOTTOM,
	OpeningMarker.Side.BOTTOM: OpeningMarker.Side.TOP,
	OpeningMarker.Side.LEFT: OpeningMarker.Side.RIGHT,
	OpeningMarker.Side.RIGHT: OpeningMarker.Side.LEFT,
}

## 各方向开口在区块内的规范本地坐标（与 chunk_base 一致）。
## 仅用于落位前探测"目标格是否已被占用"；实际落位以候选场景的真实开口坐标为准。
const MATE_LOCAL := {
	OpeningMarker.Side.TOP: Vector2(160, 0),
	OpeningMarker.Side.BOTTOM: Vector2(160, 184),
	OpeningMarker.Side.LEFT: Vector2(0, 135),
	OpeningMarker.Side.RIGHT: Vector2(320, 135),
}

## 判定两个开口"重合"的容差（像素）。
const MATE_EPSILON := 3.0


# ─────────────────────────────────────────────
# 调试入口
# ─────────────────────────────────────────────

@export_group("生成概率")
## exit 场景的基础概率。
@export var exit_base_chance := 0.2
## 每次未生成 exit 时的概率增量（封顶 1.0）。
@export var exit_chance_increment := 0.05

@export_group("层数")
## 起点层数。
@export var start_depth := 1
## 最高层数；达到后从 exit 向上固定生成 finish，否则生成 checkpoint。
@export var max_depth := 8

@export_group("触发")
## 开口与玩家的距离小于该值（像素，欧氏距离）时，生成其相邻区块。
@export var trigger_distance := 320.0

@export_group("其它")
## 随机种子；为 0 时每次运行随机。
@export var rng_seed := 0
## 起点块内玩家的出生偏移（相对起点块原点，原点位于脚底）；默认山脚正中心。
@export var player_spawn_offset := Vector2(160, 152)

@export_group("场景引用")
@export var chunks_container: Node2D
@export var player: CharacterBody2D

# ─────────────────────────────────────────────
# 图数据
# ─────────────────────────────────────────────

## 节点集合：所有已放置的区块
var placed: Array[Chunk] = []

## 边集合（双向）：OpeningMarker → 对接的 OpeningMarker
var connections := {}

## 未探索的开口队列，元素为 {opening: OpeningMarker, owner: Chunk}
var frontier: Array = []

## 当前 exit 生成概率（命中后回落到 exit_base_chance）
var exit_chance := 0.2

var rng := RandomNumberGenerator.new()


# ─────────────────────────────────────────────
# 入口
# ─────────────────────────────────────────────
func generate() -> void:
	_clear_placed()
	_reset_state()

	if chunks_container == null:
		push_error("ChunkGenerator: 未设置 chunks_container。")
		return

	var start := START_SCENE.instantiate() as Chunk
	if start == null:
		push_error("ChunkGenerator: 起点场景不是 Chunk。")
		return
	chunks_container.add_child(start)
	start.global_position = Vector2.ZERO
	start.depth = start_depth

	placed.append(start)
	_spawn_player_in(start)
	_register_openings(start)


## 每物理帧最多处理一个临近开口，避免瞬时卡顿。
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var index := _next_ready_opening_index()
	if index < 0:
		return
	var entry: Dictionary = frontier[index]
	frontier.remove_at(index)
	generate_neighbor(entry["opening"])


# ─────────────────────────────────────────────
# 相邻生成
# ─────────────────────────────────────────────

## 生成 `opening` 相邻的区块。
##
## opening 所属区块提供方向与层数上下文；落位完成后立即建立双向连接。
## 若目标格已被占用，则只在两个开口 3px 内重合时互连，不重复生成。
func generate_neighbor(opening: OpeningMarker) -> void:
	if not is_instance_valid(opening) or _is_connected(opening):
		return
	# 不向下扩展：塔的底部即起点，下方不存在内容。
	if opening.side == OpeningMarker.Side.BOTTOM:
		return

	var owner_chunk: Chunk = opening.get_chunk()
	if owner_chunk == null:
		return

	var mate_side: OpeningMarker.Side = OPPOSITE_SIDE[opening.side]

	# 目标格已被占用 → 找到对位开口并互连。
	var target_origin: Vector2 = opening.global_position - MATE_LOCAL[mate_side]
	var occupant := _chunk_at(target_origin, owner_chunk.chunk_size)
	if occupant != null:
		var mate := _find_opening_near(occupant, mate_side, opening.global_position)
		if mate != null:
			_connect(opening, mate)
		return

	var is_upward: bool = opening.side == OpeningMarker.Side.TOP
	var new_depth: int = owner_chunk.depth + 1 if is_upward else owner_chunk.depth
	var scene: PackedScene = _pick_scene(_decide_type(is_upward, new_depth))
	if scene == null:
		return

	var new_chunk := scene.instantiate() as Chunk
	if new_chunk == null:
		return

	var mates := new_chunk.get_openings(mate_side)
	if mates.is_empty():
		push_warning("ChunkGenerator: 候选区块没有对位开口（side=%d）。" % mate_side)
		new_chunk.free()
		return
	var mate_opening: OpeningMarker = mates[0]

	chunks_container.add_child(new_chunk)
	# 落位：让候选块的对位开口与当前开口重合。
	# 所有变体共享同一套开口本地坐标，因此对齐是精确的，无需校验宽度。
	new_chunk.global_position = opening.global_position - mate_opening.position
	new_chunk.depth = new_depth

	placed.append(new_chunk)
	_connect(opening, mate_opening)
	_register_openings(new_chunk)


## 决定新块的类型，并推进 exit 概率。
## 向上生成固定为 checkpoint / finish；水平生成按 exit 概率决定。
func _decide_type(is_upward: bool, new_depth: int) -> String:
	if is_upward:
		# 向上生成不会产出 exit，同样计入增量。
		exit_chance = minf(exit_chance + exit_chance_increment, 1.0)
		return "finish" if new_depth >= max_depth else "checkpoint"

	if rng.randf() < exit_chance:
		exit_chance = exit_base_chance
		return "exit"

	exit_chance = minf(exit_chance + exit_chance_increment, 1.0)
	return _pick_corridor_type()


## 抽取水平走廊的类型。天赋全部满级后不再抽到天赋商店。
func _pick_corridor_type() -> String:
	var maxed := _talents_all_maxed()
	var candidates: Array[String] = []
	for candidate in CORRIDOR_TYPES:
		if candidate == "talent_shop" and maxed:
			continue
		candidates.append(candidate)
	if candidates.is_empty():
		return "ordinary"
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## 场上天赋是否已全部满级；没有天赋组件时视为未满级。
func _talents_all_maxed() -> bool:
	for node in get_tree().get_nodes_in_group("talents"):
		if node is Talents:
			return node.all_maxed()
	return false


## 从类型池中随机取一个变体场景。
func _pick_scene(type: String) -> PackedScene:
	var pool: Array = CHUNK_POOLS.get(type, [])
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)] as PackedScene


## 把区块上所有可扩展的开口加入 frontier。
## 已连接的开口（例如 checkpoint 的下开口）与向下的开口不参与扩展。
func _register_openings(chunk: Chunk) -> void:
	for opening in chunk.get_all_openings():
		if opening.side == OpeningMarker.Side.BOTTOM or _is_connected(opening):
			continue
		frontier.append({"opening": opening, "owner": chunk})


## 返回第一个"距离玩家足够近且尚未连接"的 frontier 下标；顺带清理失效项。
func _next_ready_opening_index() -> int:
	var i := 0
	while i < frontier.size():
		var entry: Dictionary = frontier[i]
		var opening = entry.get("opening")
		if not (opening is OpeningMarker) or not is_instance_valid(opening) or _is_connected(opening):
			frontier.remove_at(i)
			continue
		if opening.global_position.distance_to(player.global_position) < trigger_distance:
			return i
		i += 1
	return -1


## 查询落在指定格子（origin + size）内的已放置区块。
func _chunk_at(origin: Vector2, size: Vector2) -> Chunk:
	var center := origin + size * 0.5
	for chunk in placed:
		if is_instance_valid(chunk) and Rect2(chunk.global_position, chunk.chunk_size).has_point(center):
			return chunk
	return null


## 在区块上找指定方向、且与给定世界坐标相距 MATE_EPSILON 以内的开口。
func _find_opening_near(chunk: Chunk, side: OpeningMarker.Side, world_position: Vector2) -> OpeningMarker:
	for opening in chunk.get_openings(side):
		if opening.global_position.distance_to(world_position) <= MATE_EPSILON:
			return opening
	return null


# ─────────────────────────────────────────────
# 起点
# ─────────────────────────────────────────────

## 把玩家放进起点块内（原点位于脚底，默认落在起点块地面上）。
func _spawn_player_in(start: Chunk) -> void:
	if not is_instance_valid(player):
		return
	var target := start.global_position + player_spawn_offset
	if player.has_method("teleport_to"):
		player.teleport_to(target)
	else:
		player.global_position = target
	# 未触碰篝火前的默认存档点即山脚。
	if player.has_method("set_spawn_point"):
		player.set_spawn_point(target)


# ─────────────────────────────────────────────
# 状态
# ─────────────────────────────────────────────

func _reset_state() -> void:
	placed.clear()
	connections.clear()
	frontier.clear()
	exit_chance = exit_base_chance
	if rng_seed == 0:
		rng.randomize()
	else:
		rng.seed = rng_seed


## 释放本生成器此前放置的区块，使 generate() 可重复调用。
func _clear_placed() -> void:
	for chunk in placed:
		if is_instance_valid(chunk):
			chunk.free()
	placed.clear()


# ─────────────────────────────────────────────
# 图操作
# ─────────────────────────────────────────────

## 记录两个开口的连接（双向）。
func _connect(a: OpeningMarker, b: OpeningMarker) -> void:
	connections[a] = b
	connections[b] = a


## 判断开口是否已连接。
func _is_connected(op: OpeningMarker) -> bool:
	return connections.has(op)


## 取开口对接的另一端。
func _get_connected(op: OpeningMarker) -> OpeningMarker:
	return connections.get(op)
