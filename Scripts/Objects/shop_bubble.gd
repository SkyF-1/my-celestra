extends Area2D
class_name ShopBubble

## 商店泡泡（占位实现）。
##
## 目前只负责显示外观与价格标签。草莓扣费、"天赋三选一 / 道具全要" 的
## 结算规则、以及泡泡内容的抽取，等天赋 / 道具系统实装后再接入。

enum Kind { TALENT, ITEM }

const TEXTURE_TALENT := preload("res://Assets/Graphics/Gameplay/shop_talent_bubble.png")
const TEXTURE_ITEM := preload("res://Assets/Graphics/Gameplay/shop_item_bubble.png")

## 泡泡种类：天赋（绿）或道具（红）。
@export var kind := Kind.TALENT
## 戳破本泡泡需要消耗的草莓数。
@export var price := 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var price_label: Label = $Price


func _ready() -> void:
	sprite.texture = TEXTURE_TALENT if kind == Kind.TALENT else TEXTURE_ITEM
	price_label.text = str(price)
