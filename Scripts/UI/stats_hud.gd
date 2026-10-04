extends CanvasLayer
class_name StatsHud

## 玩家统计数据 HUD（屏幕右上角）。
##
## 显示三样东西：
##   层数 —— 玩家当前所处区块的 depth（不在任何区块内时显示 "—"）
##   草莓 —— 局内草莓账本余额
##   天赋 —— 下拉菜单，列出已获得的天赋与等级，悬停显示效果说明
##
## 三个数据源都按组自动查找（"player" / "strawberry_ledger" / "talents"），
## 所以挂在关卡下任意位置都能工作；找不到时显示占位文本而不是报错。
##
## 节点位置：挂载于关卡根节点下。

const PLAYER_GROUP := "player"
const LEDGER_GROUP := "strawberry_ledger"
const TALENTS_GROUP := "talents"

@onready var depth_label: Label = $Panel/VBox/DepthLabel
@onready var berry_label: Label = $Panel/VBox/BerryLabel
@onready var talent_menu: MenuButton = $Panel/VBox/TalentMenu

var _player: Node2D = null
var _ledger: StrawberryLedger = null
var _talents: Talents = null

# 读数缓存，数值没变就不写控件。
var _shown_depth := -1
var _shown_berries := -1


func _ready() -> void:
	_acquire_nodes()
	_rebuild_talent_menu()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player) \
			or not is_instance_valid(_ledger) \
			or not is_instance_valid(_talents):
		_acquire_nodes()
	_refresh_counters()


# ═══════════════════════════════════════════════════════
# 数据源
# ═══════════════════════════════════════════════════════
func _acquire_nodes() -> void:
	_player = null
	for node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		if node is Node2D:
			_player = node
			break

	_ledger = null
	for node in get_tree().get_nodes_in_group(LEDGER_GROUP):
		if node is StrawberryLedger:
			_ledger = node
			break

	var previous := _talents
	_talents = null
	for node in get_tree().get_nodes_in_group(TALENTS_GROUP):
		if node is Talents:
			_talents = node
			break
	if is_instance_valid(_talents) and _talents != previous:
		if not _talents.changed.is_connected(_rebuild_talent_menu):
			_talents.changed.connect(_rebuild_talent_menu)
		_rebuild_talent_menu()


## 每帧刷新层数与草莓数（只在数值真的变化时写控件）。
func _refresh_counters() -> void:
	var depth := -1
	if is_instance_valid(_player):
		var chunk := Chunk.find_at(get_tree(), _player.global_position)
		if chunk != null:
			depth = chunk.depth
	if depth != _shown_depth:
		_shown_depth = depth
		depth_label.text = "层数 —" if depth < 0 else "层数 %d" % depth

	var berries := -1
	if is_instance_valid(_ledger):
		berries = _ledger.get_total()
	if berries != _shown_berries:
		_shown_berries = berries
		berry_label.text = "草莓 —" if berries < 0 else "草莓 %d" % berries


# ═══════════════════════════════════════════════════════
# 天赋下拉菜单
# ═══════════════════════════════════════════════════════
## 重建下拉菜单。只在拿到组件或天赋变化时调用——每帧重建会把展开中的菜单关掉。
func _rebuild_talent_menu() -> void:
	var popup := talent_menu.get_popup()
	popup.clear()

	var acquired := 0
	if is_instance_valid(_talents):
		for talent in _talents.talent_pool:
			var level := _talents.get_level(talent)
			if level <= 0:
				continue
			popup.add_item("%s Lv%d/%d" % [talent.talent_name, level, talent.max_level])
			popup.set_item_tooltip(popup.item_count - 1, talent.description)
			acquired += 1

	talent_menu.text = "天赋 (%d)" % acquired
	if acquired == 0:
		popup.add_item("（暂无天赋）")
		popup.set_item_disabled(0, true)
