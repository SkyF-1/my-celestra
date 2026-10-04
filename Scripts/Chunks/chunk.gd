extends Node2D
class_name Chunk

## 区块类型标识。生成器依据此字段决定区块的分池归属。
## 取值：ordinary / danger / checkpoint / talent_shop / item_shop / reward / finish
@export var chunk_type := "ordinary"

## 区块的标准尺寸（宽 × 高，像素）。
@export var chunk_size := Vector2(320, 180)

## 从起点到本区块的向上深度。
## 起点为 0，向上每层 +1，横向扩展不变。
var depth := 0

## 返回指定方向上的所有开口。
## 支持同一方向存在多个开口的情形。
func get_openings(side: OpeningMarker.Side) -> Array[OpeningMarker]:
	var result: Array[OpeningMarker] = []
	for child in $Openings.get_children():
		if child is OpeningMarker and child.side == side:
			result.append(child)
	return result


## 返回所有开口，不区分方向。
func get_all_openings() -> Array[OpeningMarker]:
	var result: Array[OpeningMarker] = []
	for child in $Openings.get_children():
		if child is OpeningMarker:
			result.append(child)
	return result


## 返回区块在本地坐标系下的轴对齐包围盒。
## 当前实现以整块矩形近似；后续接入 Bounds 多边形后，
## 将改为从 $Shape/Bounds 读取并计算 AABB。
func get_local_aabb() -> Rect2:
	return Rect2(Vector2.ZERO, chunk_size)


## 返回区块在世界坐标系下的轴对齐包围盒。
func get_world_aabb() -> Rect2:
	return Rect2(to_global(Vector2.ZERO), chunk_size)


## 判断当前区块与另一区块的包围盒是否相交。
## 采用 AABB 近似检测，适用于标准尺寸区块的垂直堆叠场景。
func overlaps_with(other: Chunk) -> bool:
	return ChunkGeometry.aabb_overlap(get_world_aabb(), other.get_world_aabb())
