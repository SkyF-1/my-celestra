extends Marker2D
class_name OpeningMarker

enum Side { TOP, BOTTOM, LEFT, RIGHT }

@export var side := Side.TOP
@export var width := 40.0


## 返回承载本开口的区块。
func get_chunk() -> Chunk:
	return get_parent().get_parent() as Chunk
