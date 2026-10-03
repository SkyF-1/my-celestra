extends Node2D
class_name Chunk

## 区块类型：ordinary / danger / checkpoint / talent_shop / item_shop / reward / finish
@export var chunk_type: String = "ordinary"

## 区块尺寸（统一 320×180）
@export var chunk_size := Vector2(320, 180)

## 拿到指定方向的开口（"top" / "bottom" / "left" / "right"）
func get_opening(side: String) -> Marker2D:
	return $Openings.get_node_or_null(side.capitalize())

## 拿到所有开口
func get_all_openings() -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	for child in $Openings.get_children():
		if child is Marker2D:
			result.append(child)
	return result