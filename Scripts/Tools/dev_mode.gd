extends CanvasLayer

## 开发者模式工具。
##
## 用法：把 Scenes/Tools/DevMode.tscn 实例挂到关卡节点下即可（例如 TestLevel/DevMode）。
## 挂载后出现浮动面板，按 F1 显示/隐藏，按住面板空白处可以拖动。
##
## 提供的开关：
##   无敌            —— 屏蔽一切死亡（含 R 键自尽）
##   飞行            —— 无视重力，用 WASD 直接飞
##   无限体力        —— 抓墙不会力竭
##   鼠标左键点击传送 —— 开启后在场景中点击，把玩家瞬移到该处
##   自由移动相机    —— 相机解除与玩家的绑定：滚轮拖动平移、缩放
##   收集跟随中的草莓 —— 调试草莓收集流程
## 面板还会实时显示玩家的体力条与冲刺次数。
##
## 依赖玩家脚本提供以下接口（见 Scripts/Entities/player.gd），且玩家需加入 "player" 分组：
##   invincible / flying / infinite_stamina 属性，teleport_to(pos) 方法。
## 依赖关卡里存在 CameraRig（"camera_rig" 分组）。

const PLAYER_GROUP := "player"
const STRAWBERRY_GROUP := "strawberries"
const CAMERA_GROUP := "camera_rig"
const TALENTS_GROUP := "talents"
const LEDGER_GROUP := "strawberry_ledger"
const BELT_GROUP := "item_belt"

## 传送落点被占用时，向上逐格寻找空位的步长与上限（像素）。
const TELEPORT_SCAN_STEP := 8.0
const TELEPORT_SCAN_LIMIT := 160.0

## 挂载后是否直接显示面板。
@export var start_visible := true

@onready var window_panel: PanelContainer = $Window
@onready var invincible_check: CheckButton = $Window/VBox/InvincibleCheck
@onready var fly_check: CheckButton = $Window/VBox/FlyCheck
@onready var stamina_check: CheckButton = $Window/VBox/StaminaCheck
@onready var teleport_check: CheckButton = $Window/VBox/TeleportCheck
@onready var free_camera_check: CheckButton = $Window/VBox/FreeCameraCheck
@onready var collect_button: Button = $Window/VBox/CollectStrawberriesButton
@onready var status_label: Label = $Window/VBox/Status
@onready var stamina_label: Label = $Window/VBox/StaminaLabel
@onready var stamina_bar: ProgressBar = $Window/VBox/StaminaBar
@onready var dash_label: Label = $Window/VBox/DashLabel
@onready var dash_bar: ProgressBar = $Window/VBox/DashBar
@onready var talent_label: Label = $Window/VBox/TalentLabel
@onready var grant_talent_button: Button = $Window/VBox/GrantTalentButton
@onready var add_strawberry_button: Button = $Window/VBox/AddStrawberryButton
@onready var item_label: Label = $Window/VBox/ItemLabel

var _player: CharacterBody2D = null
var _camera_rig: CameraRig = null
var _talents: Talents = null
var _ledger: StrawberryLedger = null
var _belt: ItemBelt = null
var _dragging := false
var _panning := false
var _collected_count := 0

# 读数缓存，只在数值真的变化时才写控件，避免每帧重排版。
var _shown_stamina := -1
var _shown_max_stamina := -1
var _shown_dashes := -1
var _shown_max_dashes := -1


func _ready() -> void:
	visible = start_visible
	invincible_check.toggled.connect(_on_flag_toggled)
	fly_check.toggled.connect(_on_flag_toggled)
	stamina_check.toggled.connect(_on_flag_toggled)
	teleport_check.toggled.connect(_on_teleport_toggled)
	free_camera_check.toggled.connect(_on_free_camera_toggled)
	collect_button.pressed.connect(_on_collect_strawberries_pressed)
	grant_talent_button.pressed.connect(_on_grant_talent_pressed)
	add_strawberry_button.pressed.connect(_on_add_strawberry_pressed)
	window_panel.gui_input.connect(_on_window_gui_input)
	_acquire_player()
	_acquire_camera()
	_acquire_systems()


func _physics_process(_delta: float) -> void:
	# 玩家 / 相机可能比工具更晚实例化，失效时重新寻找。
	if not is_instance_valid(_player):
		_acquire_player()
	if not is_instance_valid(_camera_rig):
		_acquire_camera()
	if not is_instance_valid(_talents) or not is_instance_valid(_ledger) \
			or not is_instance_valid(_belt):
		_acquire_systems()
	_refresh_player_stats()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()
		return

	# 鼠标在面板之外松开时，同样要结束拖动 / 平移。
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = false


func _unhandled_input(event: InputEvent) -> void:
	# 面板上的点击会被 Control 吃掉，因此这里只会收到场景中的点击。
	if _handle_camera_input(event):
		return
	if teleport_check.button_pressed \
			and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_teleport_to_screen_position(event.position)
		get_viewport().set_input_as_handled()


## 开发者相机：自由相机模式下滚轮缩放、平移。
## 返回 true 表示事件已被消费。
func _handle_camera_input(event: InputEvent) -> bool:
	if not is_instance_valid(_camera_rig):
		return false

	if event is InputEventMouseMotion:
		if not _panning:
			return false
		_camera_rig.pan_by_screen(event.relative)
		get_viewport().set_input_as_handled()
		return true

	if not (event is InputEventMouseButton) or not event.pressed:
		return false
	if not free_camera_check.button_pressed:
		return false

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_camera_rig.zoom_by_steps(1.0)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_camera_rig.zoom_by_steps(-1.0)
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = true
	else:
		return false

	get_viewport().set_input_as_handled()
	_refresh_status()
	return true


# ═══════════════════════════════════════════════════════
# 面板交互
# ═══════════════════════════════════════════════════════
func _on_window_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_dragging = true
	elif event is InputEventMouseMotion and _dragging:
		window_panel.position += event.relative


func _on_flag_toggled(_pressed: bool) -> void:
	_apply_to_player()
	_refresh_status()


func _on_teleport_toggled(_pressed: bool) -> void:
	_refresh_status()


func _on_free_camera_toggled(_pressed: bool) -> void:
	_panning = false
	_apply_free_camera()
	_refresh_status()


func _on_collect_strawberries_pressed() -> void:
	var amount := _collect_following_strawberries()
	_collected_count += amount

	if amount > 0:
		print("[DevMode] 收集了 %d 枚跟随中的草莓。" % amount)
	else:
		print("[DevMode] 当前没有跟随中的草莓。")

	_refresh_status("本次收集 %d 枚，累计 %d 枚" % [amount, _collected_count])


# ═══════════════════════════════════════════════════════
# 玩家
# ═══════════════════════════════════════════════════════
func _acquire_player() -> void:
	_player = null
	for node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		if node is CharacterBody2D and node.has_method("teleport_to"):
			_player = node
			break

	_apply_to_player()
	_set_flags_enabled(_player != null)
	_refresh_status()


## 把面板上的开关同步到玩家身上。
func _apply_to_player() -> void:
	if not is_instance_valid(_player):
		return
	_player.invincible = invincible_check.button_pressed
	_player.flying = fly_check.button_pressed
	_player.infinite_stamina = stamina_check.button_pressed


func _set_flags_enabled(enabled: bool) -> void:
	invincible_check.disabled = not enabled
	fly_check.disabled = not enabled
	stamina_check.disabled = not enabled
	teleport_check.disabled = not enabled


# ═══════════════════════════════════════════════════════
# 玩家状态读数
# ═══════════════════════════════════════════════════════
## 把玩家的体力与冲刺次数同步到面板上的体力条 / 计数。
func _refresh_player_stats() -> void:
	if not is_instance_valid(_player):
		return

	var stamina := roundi(_player.stamina)
	var max_stamina := roundi(_player.climb_max_stamina)
	if stamina != _shown_stamina or max_stamina != _shown_max_stamina:
		_shown_stamina = stamina
		_shown_max_stamina = max_stamina
		stamina_bar.max_value = max_stamina
		stamina_bar.value = stamina
		stamina_label.text = "体力 %d / %d" % [stamina, max_stamina]

	var dashes: int = _player.dashes
	var max_dashes: int = _player.max_dashes
	if dashes != _shown_dashes or max_dashes != _shown_max_dashes:
		_shown_dashes = dashes
		_shown_max_dashes = max_dashes
		dash_bar.max_value = max_dashes
		dash_bar.value = dashes
		dash_label.text = "冲刺 %d / %d" % [dashes, max_dashes]


# ═══════════════════════════════════════════════════════
# 天赋 / 草莓
# ═══════════════════════════════════════════════════════
func _acquire_systems() -> void:
	_talents = null
	for node in get_tree().get_nodes_in_group(TALENTS_GROUP):
		if node is Talents:
			_talents = node
			break
	if is_instance_valid(_talents) and not _talents.changed.is_connected(_refresh_talent_readout):
		_talents.changed.connect(_refresh_talent_readout)

	_ledger = null
	for node in get_tree().get_nodes_in_group(LEDGER_GROUP):
		if node is StrawberryLedger:
			_ledger = node
			break

	_belt = null
	for node in get_tree().get_nodes_in_group(BELT_GROUP):
		if node is ItemBelt:
			_belt = node
			break
	if is_instance_valid(_belt) and not _belt.changed.is_connected(_refresh_item_readout):
		_belt.changed.connect(_refresh_item_readout)

	grant_talent_button.disabled = _talents == null
	add_strawberry_button.disabled = _ledger == null
	_refresh_talent_readout()
	_refresh_item_readout()


## 刷新"已获得天赋"读数。
func _refresh_talent_readout() -> void:
	if not is_instance_valid(_talents):
		talent_label.text = "已获得天赋：—（未找到 Talents 组件）"
		return

	var parts: Array[String] = []
	for talent in _talents.talent_pool:
		var level := _talents.get_level(talent)
		if level > 0:
			parts.append("%s Lv%d" % [talent.talent_name, level])

	if parts.is_empty():
		talent_label.text = "已获得天赋：—"
	else:
		talent_label.text = "已获得天赋：" + "、".join(parts)


## 白送一级随机天赋（只在未满级的天赋里挑）。
func _on_grant_talent_pressed() -> void:
	if not is_instance_valid(_talents):
		return

	var pool := _talents.get_available_talents()
	if pool.is_empty():
		_refresh_status("全部天赋都已满级。")
		return

	var talent: Talent = pool[randi() % pool.size()]
	_talents.grant(talent, 1)
	var level := _talents.get_level(talent)
	print("[DevMode] 获得天赋「%s」Lv%d。" % [talent.talent_name, level])
	_refresh_status("获得「%s」Lv%d（%d/%d）" % [
		talent.talent_name, level, level, talent.max_level,
	])
	_refresh_talent_readout()


## 刷新道具栏读数。
func _refresh_item_readout() -> void:
	if not is_instance_valid(_belt):
		item_label.text = "道具栏：—（未找到 ItemBelt）"
		return

	var parts: Array[String] = []
	for item_id in _belt.get_slots():
		if item_id.is_empty():
			parts.append("空")
		else:
			parts.append(str(ItemDrop.NAMES.get(item_id, item_id)))
	item_label.text = "道具栏：" + "、".join(parts)


## 加 10 枚草莓，方便测试商店购买。
func _on_add_strawberry_pressed() -> void:
	if not is_instance_valid(_ledger):
		return
	_ledger.add(10)
	_refresh_status("草莓 +10，当前 %d 枚。" % _ledger.get_total())


func _acquire_camera() -> void:
	_camera_rig = null
	for node in get_tree().get_nodes_in_group(CAMERA_GROUP):
		if node is CameraRig:
			_camera_rig = node
			break

	_apply_free_camera()
	free_camera_check.disabled = _camera_rig == null
	_refresh_status()


## 把"自由移动相机"开关同步到相机支架：关闭时恢复跟随并立即对齐玩家。
func _apply_free_camera() -> void:
	if not is_instance_valid(_camera_rig):
		return
	_camera_rig.set_follow_player(not free_camera_check.button_pressed)
	if not free_camera_check.button_pressed:
		_camera_rig.reset_view()


# ═══════════════════════════════════════════════════════
# 传送
# ═══════════════════════════════════════════════════════
func _teleport_to_screen_position(screen_position: Vector2) -> void:
	if not is_instance_valid(_player):
		_refresh_status("未找到玩家，无法传送。")
		return

	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var target := _find_free_position(world_position)
	_player.teleport_to(target)
	print("[DevMode] 玩家传送至 %s。" % target)
	_refresh_status("已传送至 (%d, %d)" % [target.x, target.y])


## 从目标点向上寻找不与地形重叠的落点；找不到空位时返回原点。
func _find_free_position(world_position: Vector2) -> Vector2:
	var shape_node := _get_player_shape()
	if shape_node == null:
		return world_position

	var space := _player.get_world_2d().direct_space_state
	var offset := 0.0
	while offset <= TELEPORT_SCAN_LIMIT:
		var candidate := world_position + Vector2(0.0, -offset)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape_node.shape
		query.transform = _make_shape_transform(shape_node, candidate)
		query.collision_mask = _player.collision_mask
		query.exclude = [_player.get_rid()]
		if space.intersect_shape(query, 1).is_empty():
			return candidate
		offset += TELEPORT_SCAN_STEP
	return world_position


## 取玩家当前生效的碰撞箱（站立优先，蹲伏时取蹲伏箱）。
func _get_player_shape() -> CollisionShape2D:
	for child in _player.get_children():
		if child is CollisionShape2D and not child.disabled:
			return child
	return null


func _make_shape_transform(shape_node: CollisionShape2D, position: Vector2) -> Transform2D:
	var offset := shape_node.global_position - _player.global_position
	return Transform2D(shape_node.global_rotation, shape_node.global_scale, 0.0, position + offset)


# ═══════════════════════════════════════════════════════
# 草莓
# ═══════════════════════════════════════════════════════
## 立即收集场景中所有正在跟随玩家的草莓，返回本次收集的数量。
func _collect_following_strawberries() -> int:
	var amount := 0
	for node in get_tree().get_nodes_in_group(STRAWBERRY_GROUP):
		if not node.has_method("collect"):
			continue
		if node.has_method("is_following") and not node.is_following():
			continue
		if node.collect():
			amount += 1
	return amount


# ═══════════════════════════════════════════════════════
# 状态栏
# ═══════════════════════════════════════════════════════
func _refresh_status(message := "") -> void:
	if not message.is_empty():
		status_label.text = message
		return

	if not is_instance_valid(_player):
		status_label.text = "未找到玩家（需要加入 \"player\" 分组）"
		return

	var enabled: Array[String] = []
	if _player.invincible:
		enabled.append("无敌")
	if _player.flying:
		enabled.append("飞行")
	if _player.infinite_stamina:
		enabled.append("无限体力")
	if teleport_check.button_pressed:
		enabled.append("点击传送")
	if free_camera_check.button_pressed:
		enabled.append("自由相机")

	var flags_text := "、".join(enabled) if not enabled.is_empty() else "无"
	var zoom_text := "—"
	if is_instance_valid(_camera_rig):
		zoom_text = "×%.2f" % _camera_rig.zoom.x
	status_label.text = "已开启：%s ｜ 草莓 %d 枚 ｜ 视角 %s" % [
		flags_text, _collected_count, zoom_text,
	]
