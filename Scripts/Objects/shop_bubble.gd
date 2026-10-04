@tool
extends Area2D
class_name ShopBubble

## 商店泡泡。
##
## 天赋泡泡：把 Assets/Talents 下的 Talent 资源赋给 talent，
## 名称 / 价格 / 图标全部自动取自该资源，不必在场景里重复填一遍。
##
## 图标会统一缩放到 icon_size 的方框内：天赋图标原始尺寸从 20×20 到
## 96×96 不等，不归一化的话显示出来会大小不一。
##
## 道具泡泡：等道具系统实装后再对齐；当前留空 talent，用
## kind / display_name / price / icon 作为占位。
##
## 交互：玩家靠近时显示提示，按交互键发出 interact_requested，
## 买不买得起、要不要让其它泡泡破裂，由 ShopBubbleContainer 统一决定。

signal interact_requested(bubble: ShopBubble)

enum Kind { TALENT, ITEM }

const TEXTURE_TALENT := preload("res://Assets/Graphics/Gameplay/shop_talent_bubble.png")
const TEXTURE_ITEM := preload("res://Assets/Graphics/Gameplay/shop_item_bubble.png")

const DEFAULT_TALENT: Talent = preload("res://Assets/Talents/toughness.tres")

## 泡泡承载的天赋。赋值后名称 / 价格 / 图标都以该资源为准。
@export var talent: Talent = DEFAULT_TALENT:
	set(value):
		talent = value
		refresh()

## 泡泡底色：天赋（绿）或道具（红）。已指定 talent 时按天赋处理。
@export var kind := Kind.TALENT

## 图标显示尺寸（世界像素）。泡泡为 32×32，默认 20 留出一圈泡泡边缘。
@export_range(4.0, 64.0, 1.0) var icon_size := 20.0

## 以下三项只在没有 talent（道具泡泡占位）时使用。
@export var display_name := ""
@export var icon: Texture2D
## 道具泡泡的道具标识（golden_feather / wind / pinball）。非空时按道具显示。
@export var item_id := ""
## 戳破本泡泡需要消耗的草莓数。
@export var price := 1

@onready var bubble_sprite: Sprite2D = $Bubble
@onready var icon_sprite: Sprite2D = $Icon
@onready var title_label: Label = %Title
@onready var price_label: Label = %Price
@onready var prompt: Label = $Prompt

var _player_inside := false

func _ready() -> void:
	refresh()
	prompt.visible = false
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	interact_requested.emit(self)


## 破裂：直接消失。
func break_apart() -> void:
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_inside = false
	prompt.visible = false


func _is_player(body: Node2D) -> bool:
	return body is CharacterBody2D and body.has_method("die")


## 依据当前数据刷新外观。运行时换过 talent / price 后调用一次即可。
func refresh() -> void:
	if not is_node_ready():
		return

	var is_talent := talent != null
	var is_item := not item_id.is_empty()
	bubble_sprite.texture = TEXTURE_TALENT if (is_talent or kind == Kind.TALENT) else TEXTURE_ITEM

	if is_talent:
		title_label.text = talent.talent_name
		price_label.text = str(talent.cost)
		_set_icon(talent.icon)
	elif is_item:
		title_label.text = str(ItemDrop.NAMES.get(item_id, item_id))
		price_label.text = str(price)
		_set_icon(ItemDrop.TEXTURES.get(item_id) as Texture2D)
	else:
		title_label.text = display_name
		price_label.text = str(price)
		_set_icon(icon)


## 把图标缩放进指定尺寸的方框，保证不同原始尺寸的图标显示大小一致。
func _set_icon(texture: Texture2D) -> void:
	icon_sprite.texture = texture
	icon_sprite.visible = texture != null
	if texture == null:
		return

	var longest := maxf(texture.get_width(), texture.get_height())
	if longest <= 0.0:
		return
	icon_sprite.scale = Vector2.ONE * (icon_size / longest)
