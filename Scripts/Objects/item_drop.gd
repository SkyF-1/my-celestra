extends Area2D
class_name ItemDrop

## 掉落道具（占位实现）。
##
## 目前只负责显示外观与名称。拾取交互、背包栏位的选择 / 替换，以及
## 金羽毛 / 风 / 弹球各自的效果，等道具系统实装后再接入。

const TEXTURES := {
	"golden_feather": preload("res://Assets/Graphics/Items/golden_feather.png"),
	"wind": preload("res://Assets/Graphics/Items/wind.png"),
	"pinball": preload("res://Assets/Graphics/Items/pinball.png"),
}

const NAMES := {
	"golden_feather": "金羽毛",
	"wind": "风",
	"pinball": "弹球",
}

## 道具标识：golden_feather / wind / pinball。
@export var item_id := "golden_feather"

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $Name


func _ready() -> void:
	sprite.texture = TEXTURES.get(item_id, TEXTURES["golden_feather"])
	name_label.text = NAMES.get(item_id, item_id)
