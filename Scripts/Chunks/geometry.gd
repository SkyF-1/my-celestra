extends RefCounted
class_name ChunkGeometry

## 两个矩形是否重叠
static func aabb_overlap(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b)

## 从多边形计算AABB
static func polygon_aabb(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var min_p := poly[0]
	var max_p := poly[0]
	for p in poly:
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
	return Rect2(min_p, max_p - min_p)
