extends Camera2D
class_name CameraRig

## 关卡相机支架。
##
## 相机不再挂在玩家身上，而是作为关卡下的独立节点存在：默认跟随 "player"
## 分组里的玩家，也可以被开发者工具解绑、自由移动。每个关卡挂一份即可
## （例如 TestLevel/CameraRig）。

const PLAYER_GROUP := "player"
const CAMERA_GROUP := "camera_rig"

## 滚轮每档的缩放倍率与缩放范围。
const ZOOM_STEP := 1.25
const ZOOM_MIN := 1.0
const ZOOM_MAX := 8.0

## 跟随目标。留空时自动到 "player" 分组里找。
@export var target: Node2D
## 是否跟随目标。关闭后相机停在原地，交给外部自由控制。
@export var follow_player := true
## 跟随平滑：0 为硬跟随（每帧对齐目标），数值越大越迟滞。
@export var follow_smoothing := 0.0
## 默认缩放。关闭自由相机时恢复到该值。
@export var default_zoom := Vector2(3, 3)

var _target: Node2D
var _snap_pending := true


func _ready() -> void:
	add_to_group(CAMERA_GROUP)
	# 数值越大越晚执行：保证相机在玩家移动之后再对齐，不会慢一帧。
	process_physics_priority = 100
	make_current()


func _physics_process(delta: float) -> void:
	if not follow_player:
		return
	if not is_instance_valid(_target):
		_resolve_target()
		if _target == null:
			return
		_snap_pending = true

	if _snap_pending or follow_smoothing <= 0.0:
		global_position = _target.global_position
		_snap_pending = false
	else:
		global_position = global_position.lerp(
			_target.global_position,
			1.0 - exp(-follow_smoothing * delta)
		)


## 开关跟随。重新开启时立即对齐目标，避免相机从远处飞回来。
func set_follow_player(value: bool) -> void:
	follow_player = value
	if value:
		_snap_pending = true
		_resolve_target()


## 按屏幕像素平移相机（自动按缩放换算成世界坐标）。
## 手感是"抓住画面拖动"：光标往右拖，画面跟着往右走，因此相机往左移。
func pan_by_screen(screen_delta: Vector2) -> void:
	global_position -= screen_delta / zoom


## 按滚轮档位缩放：steps > 0 放大，steps < 0 缩小。
## 以光标下的世界坐标为锚点，缩放前后光标指着的那个点保持不动。
func zoom_by_steps(steps: float) -> void:
	var old_zoom := zoom
	var new_zoom := (zoom * pow(ZOOM_STEP, steps)).clamp(
		Vector2(ZOOM_MIN, ZOOM_MIN),
		Vector2(ZOOM_MAX, ZOOM_MAX)
	)
	if new_zoom.is_equal_approx(old_zoom):
		return

	var anchor := get_global_mouse_position()
	zoom = new_zoom
	global_position = anchor + (global_position - anchor) * (old_zoom / new_zoom)


## 恢复默认缩放并立即对齐目标（关闭自由相机时调用）。
func reset_view() -> void:
	zoom = default_zoom
	_snap_pending = true
	if not follow_player:
		return
	if not is_instance_valid(_target):
		_resolve_target()
	if is_instance_valid(_target):
		global_position = _target.global_position
		_snap_pending = false


func _resolve_target() -> void:
	if is_instance_valid(target):
		_target = target
		return
	_target = null
	for node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		if node is Node2D:
			_target = node
			break
