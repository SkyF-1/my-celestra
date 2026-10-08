extends Camera2D
class_name CameraRig

## 关卡相机支架。
##
## 相机不再挂在玩家身上，而是作为关卡下的独立节点存在：默认跟随 "player"
## 分组里的玩家，也可以被开发者工具解绑、自由移动。每个关卡挂一份即可
## （例如 TestLevel/CameraRig）。
##
## 相机下边界：相机不会把视野移到该边界以下，玩家越过该边界即判定坠落死亡。
## 边界在关卡开始时取"玩家初始所在区块"的底部（山脚），此后每激活一个篝火
## 存档点就上移到该篝火所在区块的底部。上移不是瞬移：生效下界以
## bottom_limit_rise_speed 的速度追上新目标，期间相机不会被允许下移。

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
## 默认缩放。视野 = 视口尺寸 / 缩放，4 倍对应 320x180，与一个区块
## （320x184）大小基本相同。关闭自由相机时恢复到该值。
@export var default_zoom := Vector2(4, 4)
## 下边界上升速度（像素/秒）。激活篝火后生效下界按此速度追上目标下界，
## 相机随之平滑上移；设为 0 表示立即到位。
@export var bottom_limit_rise_speed := 180.0

var _target: Node2D
var _snap_pending := true
## 相机下边界的目标值（世界 y）。INF 表示尚未确定（还没找到玩家所在区块）。
var bottom_limit := INF
## 当前生效的下边界：只向上追赶目标，用于钳制相机与判定坠落。
var _active_limit := INF


func _ready() -> void:
	add_to_group(CAMERA_GROUP)
	# 数值越大越晚执行：保证相机在玩家移动之后再对齐，不会慢一帧。
	process_physics_priority = 100
	# 以导出值为准，避免场景里残留的 zoom 覆盖 default_zoom。
	zoom = default_zoom
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

	_update_bottom_limit(delta)


## 设定相机下边界的目标值（世界 y）。激活篝火时由存档点调用。
## 生效下界从"当前画面下沿"起步，向上追到目标：既不会瞬移，
## 也不会让相机在过渡期间继续下移。
func set_bottom_limit(world_y: float) -> void:
	bottom_limit = world_y
	if _active_limit >= INF:
		_active_limit = world_y
		return
	var half_height := get_viewport_rect().size.y * 0.5 / maxf(zoom.y, 0.001)
	_active_limit = clampf(global_position.y + half_height, world_y, _active_limit)


## 清除下边界限制（重新开局等场合）。
func reset_bottom_limit() -> void:
	bottom_limit = INF
	_active_limit = INF


## 维护下边界：首次取玩家初始所在区块的底部；之后让生效下界向上追赶目标，
## 钳制相机，并判定坠落死亡。
func _update_bottom_limit(delta: float) -> void:
	if bottom_limit >= INF:
		var chunk := Chunk.find_at(get_tree(), _target.global_position)
		if chunk == null:
			return
		bottom_limit = chunk.global_position.y + chunk.chunk_size.y
		# 开局第一次直接到位，避免关卡开始时相机从无穷远处飘上来。
		_active_limit = bottom_limit

	# 生效下界只向上（y 减小方向）追赶：相机因此不会瞬移，也不会向下越过它。
	if _active_limit > bottom_limit:
		_active_limit = maxf(bottom_limit, _active_limit - bottom_limit_rise_speed * delta)

	_clamp_to_bottom_limit()

	# 脚底越过（生效）下边界 = 已经掉出画面底部。
	if _target.has_method("die") and _target.global_position.y > _active_limit:
		_target.die()


## 限制相机不向下越过下边界。
func _clamp_to_bottom_limit() -> void:
	if _active_limit >= INF:
		return
	var half_height := get_viewport_rect().size.y * 0.5 / maxf(zoom.y, 0.001)
	global_position.y = minf(global_position.y, _active_limit - half_height)


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
