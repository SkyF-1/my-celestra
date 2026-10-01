# Celestra StarterAssets

## 目录说明

| 目录 | 内容 |
| --- | --- |
| `Graphics/Player` | 待机、跑动、跳跃、下落、加速下落、蹲伏、攀墙、冲刺、死亡 |
| `Graphics/World` | 三种地形图块、平台、尖刺 |
| `Graphics/Gameplay` | 草莓、篝火、商店泡泡、终点旗帜 |
| `Graphics/Talents` | 四种天赋的近似语义图标 |
| `Graphics/Items` | 金羽毛、风、弹球；图标也可直接作为场景掉落物 |
| `Graphics/UI` | 开始/设置/退出、通用面板、HUD 和策划案实际使用的键位图 |
| `Graphics/Background` | 五层雪山场景，可用于主菜单或视差背景 |
| `Graphics/Effects` | 雪、风、尘土三种通用粒子纹理 |
| `Audio/Music` | 菜单、游戏过程、胜利音乐 |
| `Audio/SFX` | 角色、草莓、篝火、商店与天赋反馈 |
| `Audio/UI` | 点击、返回、暂停、继续 |
| `Audio/Items` | 三种道具的核心音效 |

## 角色

- `Idle`：地面静止；
- `Run`：地面移动；
- `Jump`：上升阶段；
- `Fall`：正常下落；
- `FastFall`：空中按下时的加速下落；
- `Crouch`：蹲伏，只有一帧；
- `Climb`：抓墙、上下攀爬或滑墙，可复用；
- `Dash`：冲刺；
- `Death`：死亡。

## UI 

- `UI/Panels/menu_inventory_panel.png` 可统一作为主菜单、暂停菜单、背包和商店底图；
- `UI/Panels/item_slot.png` 用于三个道具栏位；
- 文本直接使用引擎字体，不需要在图片上修改文字；
- `UI/Keys` 只保留 WASD、Space、J、K、E、B、1/2/3、Esc。

## 音频

| 游戏事件 | 文件 |
| --- | --- |
| 正常游戏背景音乐 | `Audio/Music/gameplay_loop.ogg` |
| 主菜单背景音乐 | `Audio/Music/menu_loop.ogg` |
| 跳跃 | `Audio/SFX/jump.ogg` |
| 蹬墙跳 | `Audio/SFX/wall_jump.ogg` |
| 冲刺 | `Audio/SFX/dash.ogg` |
| 死亡 | `Audio/SFX/death.ogg` |
| 草莓触碰/正式收集 | `Audio/SFX/strawberry_touch.ogg`、`strawberry_collect.ogg` |
| 激活篝火 | `Audio/SFX/checkpoint.ogg` |
| 主要菜单按钮 | `Audio/UI/click.ogg` |
| 到达终点 | `Audio/Music/victory.ogg` |
| 天赋购买 | `Audio/SFX/talent_upgrade.ogg` |
| 商店泡泡破裂 | `Audio/SFX/shop_purchase.ogg` |

