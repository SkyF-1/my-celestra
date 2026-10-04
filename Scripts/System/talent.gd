extends Resource
class_name Talent

## 天赋静态数据。
##
## 每个天赋为一个 .tres 资源。泡泡、商店、天赋组件引用本资源获取全部信息。
## 天赋的「生效逻辑」由 Talents 组件依据 effect_key 分发，本类只承载数据。

## 显示名，同时作为唯一标识。
@export var talent_name := "未命名"

## 图标。
@export var icon: Texture2D

## 购买价格（草莓数）。
@export var cost := 1

## 等级上限。
@export var max_level := 1

## 描述文本，供 UI 展示。
@export var description := ""

## 效果类型标识。Talents 组件据此决定修改玩家哪个属性。
## 取值：stamina / speed / dash / special
@export var effect_key := ""

## 每级数值。含义由 effect_key 决定：
##   stamina → 每级增加的体力上限
##   speed   → 每级增加的最大移动速度
##   dash    → 每级增加的冲刺次数
##   special → 忽略
@export var per_level := 0.0
