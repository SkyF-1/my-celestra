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
}

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

var rng := RandomNumberGenerator.new()


# ─────────────────────────────────────────────
# 入口
# ─────────────────────────────────────────────
func generate() -> void:
	pass


func _process(_delta: float) -> void:
	pass


# ─────────────────────────────────────────────
# 图操作
# ─────────────────────────────────────────────

## 记录两个开口的连接（双向）。
func _connect(a: OpeningMarker, b: OpeningMarker) -> void:
	pass


## 判断开口是否已连接。
func _is_connected(op: OpeningMarker) -> bool:
	return false


## 取开口对接的另一端。
func _get_connected(op: OpeningMarker) -> OpeningMarker:
	return null
