extends Node2D

const PlayerScript = preload("res://scripts/player.gd")
const CHUNK_W := 320.0
const CHUNK_H := 200.0
const TOP_ROW := 8
const TALENTS := ["坚韧", "加速", "更多冲刺", "草莓罐头"]
const MAX_LEVELS := {"坚韧": 5, "加速": 5, "更多冲刺": 3, "草莓罐头": 1}
const COSTS := {"坚韧": 1, "加速": 1, "更多冲刺": 3, "草莓罐头": 5}
const ICONS := {"坚韧": "toughness", "加速": "haste", "更多冲刺": "more_dash", "草莓罐头": "strawberry_can"}

var world: Node2D
var player: Climber
var camera: Camera2D
var canvas: CanvasLayer
var root_ui: Control
var hud: Control
var overlay: Control
var prompt: Label
var status: Label
var music: AudioStreamPlayer
var audio: AudioStreamPlayer
var menu_mode := "main"
var running := false
var finished := false
var elapsed := 0.0
var deaths := 0
var collected_total := 0
var strawberries := 0
var talents := {"坚韧": 0, "加速": 0, "更多冲刺": 0, "草莓罐头": 0}
var inventory := ["", "", ""]
var pending_item: Dictionary = {}
var checkpoint := Vector2(0, 50)
var camera_floor := 100000.0
var chunks := {}
var interactables: Array[Dictionary] = []
var berries: Array[Dictionary] = []
var finish_col := 999999
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_ui()
	_show_main_menu()

func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	player = PlayerScript.new()
	player.position = checkpoint
	world.add_child(player)
	player.jumped.connect(func(): _sfx("SFX/jump"))
	player.dashed.connect(func(): _sfx("SFX/dash"))
	player.landed.connect(_on_landed)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.7, 1.7)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	world.add_child(camera)
	camera.make_current()
	_platform(world, Vector2(0, 80), 940, 44, Color("697687"), false)
	for c in range(-2, 3):
		_generate_chunk(c, 1)
	world.visible = false

func _platform(parent: Node2D, pos: Vector2, width: float, height: float, color: Color, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	parent.add_child(body)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	shape.one_way_collision = one_way
	body.add_child(shape)
	var base := ColorRect.new()
	base.color = color
	base.position = Vector2(-width / 2, -height / 2)
	base.size = Vector2(width, height)
	body.add_child(base)
	var cap := TextureRect.new()
	cap.texture = load("res://Assets/Graphics/World/Platforms/wood.png")
	cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cap.stretch_mode = TextureRect.STRETCH_TILE
	cap.position = Vector2(-width / 2, -height / 2)
	cap.size = Vector2(width, minf(10.0, height))
	body.add_child(cap)

func _generate_nearby() -> void:
	var col := floori(player.position.x / CHUNK_W + 0.5)
	var row := maxi(1, floori((80.0 - player.position.y) / CHUNK_H))
	if row + 2 >= TOP_ROW and finish_col == 999999:
		finish_col = col
	for r in range(maxi(1, row - 1), mini(TOP_ROW, row + 2) + 1):
		for c in range(col - 2, col + 3):
			_generate_chunk(c, r)

func _generate_chunk(col: int, row: int) -> void:
	var key := Vector2i(col, row)
	if chunks.has(key):
		return
	if row == TOP_ROW and finish_col == 999999:
		finish_col = col
	var kind := "ordinary"
	if row == TOP_ROW and col == finish_col:
		kind = "finish"
	elif row == 1 and col == 0:
		kind = "danger"
	elif row == 2 and col == 0:
		kind = "checkpoint"
	elif row == 3 and col == 0:
		kind = "talent"
	elif row == 4 and col == 0:
		kind = "item_shop"
	elif row == 5 and col == 0:
		kind = "reward"
	else:
		var roll := rng.randi_range(0, 9)
		if roll == 0:
			kind = "danger"
		elif roll == 1:
			kind = "checkpoint"
		elif roll == 2 and _available_talents().size() > 0:
			kind = "talent"
		elif roll == 3:
			kind = "item_shop"
		elif roll == 4:
			kind = "reward"
	var chunk := Node2D.new()
	chunk.name = "Chunk_%s_%s_%s" % [col, row, kind]
	chunk.position = Vector2(col * CHUNK_W, 80.0 - row * CHUNK_H)
	world.add_child(chunk)
	chunks[key] = chunk
	var variant := absi(col * 11 + row * 7) % 3
	var tint: Color = [Color("526d87"), Color("5f7380"), Color("596980")][variant]
	var offset: float = [-30.0, 0.0, 30.0][variant]
	_platform(chunk, Vector2(offset, 0), 230.0, 24.0, tint, true)
	_platform(chunk, Vector2(-92.0 if variant != 1 else 92.0, 95), 115.0, 16.0, tint.lightened(0.12), true)
	if variant == 2:
		_platform(chunk, Vector2(112, -50), 86.0, 12.0, tint.darkened(0.1), true)
	elif variant == 1:
		_platform(chunk, Vector2(-113, -55), 95.0, 14.0, tint.darkened(0.1), true)
	var heading := _label(kind.to_upper(), Vector2(-92, -56), 17, Color("f7e5b0"))
	chunk.add_child(heading)
	match kind:
		"danger":
			for i in range(2):
				var berry_pos := Vector2(-45 + i * 90, -38)
				var berry_node := _marker(chunk, berry_pos, "Gameplay/strawberry", Vector2(0.9, 0.9))
				berries.append({"node": berry_node, "origin": berry_node.global_position, "key": key, "state": "free"})
			var spikes := _marker(chunk, Vector2(138, -14), "World/Hazards/spikes_up", Vector2(1, 1))
			interactables.append({"kind": "spikes", "node": spikes, "active": true})
		"checkpoint":
			var camp := _marker(chunk, Vector2(0, -44), "Gameplay/checkpoint_inactive")
			interactables.append({"kind": "checkpoint", "node": camp, "active": true})
		"talent":
			var available := _available_talents()
			for i in range(3):
				var name: String = available[rng.randi_range(0, available.size() - 1)]
				var bubble := _marker(chunk, Vector2(-74 + i * 74, -39), "Gameplay/shop_talent_bubble")
				interactables.append({"kind": "talent", "node": bubble, "active": true, "talent": name, "shop": key})
				chunk.add_child(_label(name, Vector2(-96 + i * 74, -92), 12, Color.WHITE))
		"item_shop":
			for i in range(3):
				var bubble := _marker(chunk, Vector2(-74 + i * 74, -39), "Gameplay/shop_item_bubble")
				interactables.append({"kind": "item_shop", "node": bubble, "active": true, "item": "风"})
		"reward":
			var item := _marker(chunk, Vector2(0, -38), "Items/wind")
			interactables.append({"kind": "item", "node": item, "active": true, "item": "风"})
		"finish":
			var flag := _marker(chunk, Vector2(0, -45), "Gameplay/finish_flag")
			interactables.append({"kind": "finish", "node": flag, "active": true})
			chunk.add_child(_label("山顶终点 · E 触碰旗帜", Vector2(-115, -105), 16, Color("ffe7a7")))

func _marker(parent: Node2D, pos: Vector2, file: String, scale_value: Vector2 = Vector2.ONE) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = load("res://Assets/Graphics/%s.png" % file)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.position = pos
	node.scale = scale_value * (0.125 if file == "Items/wind" else 2.0 if file == "World/Hazards/spikes_up" else 1.0)
	parent.add_child(node)
	return node

func _label(value: String, pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _available_talents() -> Array[String]:
	var available: Array[String] = []
	for name in TALENTS:
		if talents[name] < MAX_LEVELS[name]:
			available.append(name)
	return available

func _process(delta: float) -> void:
	if not running or menu_mode != "game":
		return
	elapsed += delta
	_generate_nearby()
	_update_camera()
	_update_berries()
	var nearest := _nearest_interactable()
	if nearest.is_empty():
		prompt.text = "WASD 移动  Space 跳跃  J 抓墙  K 冲刺  E 交互  B 背包"
	else:
		prompt.text = _interaction_text(nearest)
	if Input.is_action_just_pressed("interact") and not nearest.is_empty():
		_interact(nearest)
	if Input.is_action_just_pressed("item_1"):
		_use_item(0)
	elif Input.is_action_just_pressed("item_2"):
		_use_item(1)
	elif Input.is_action_just_pressed("item_3"):
		_use_item(2)
	if Input.is_action_just_pressed("backpack"):
		_show_bag()
	if player.position.y > camera.position.y + 235 or player.position.y > 145:
		_die()
	_update_hud()

func _update_camera() -> void:
	camera.position = Vector2(player.position.x, minf(player.position.y - 52, camera_floor))

func _nearest_interactable() -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 65.0
	for entry in interactables:
		if not entry.active or not is_instance_valid(entry.node):
			continue
		var d: float = player.position.distance_to(entry.node.global_position)
		if entry.kind == "spikes":
			if d < 20.0 and player.invulnerable <= 0.0:
				_die()
			continue
		if d < distance:
			distance = d
			nearest = entry
	return nearest

func _interaction_text(entry: Dictionary) -> String:
	match entry.kind:
		"checkpoint": return "E · 在篝火旁存档"
		"talent": return "E · %s Lv.%d/%d，花费 %d 草莓" % [entry.talent, talents[entry.talent] + 1, MAX_LEVELS[entry.talent], COSTS[entry.talent]]
		"item_shop": return "E · 购买风道具，花费 1 草莓"
		"item": return "E · 拾取风道具"
		"finish": return "E · 结束本局，登顶胜利"
	return ""

func _interact(entry: Dictionary) -> void:
	match entry.kind:
		"checkpoint":
			checkpoint = entry.node.global_position + Vector2(0, -4)
			camera_floor = minf(camera_floor, checkpoint.y + 55)
			entry.node.texture = load("res://Assets/Graphics/Gameplay/checkpoint_active.png")
			_sfx("SFX/checkpoint")
		"talent":
			var name: String = entry.talent
			if strawberries < COSTS[name] or talents[name] >= MAX_LEVELS[name]:
				return
			strawberries -= COSTS[name]
			talents[name] += 1
			_apply_talents()
			_sfx("SFX/talent_upgrade")
			for other in interactables:
				if other.kind == "talent" and other.shop == entry.shop:
					other.active = false
					other.node.visible = false
		"item_shop":
			if strawberries < 1:
				return
			strawberries -= 1
			entry.active = false
			entry.node.visible = false
			_sfx("SFX/shop_purchase")
			var drop := _marker(world, entry.node.global_position + Vector2(0, -25), "Items/wind")
			interactables.append({"kind": "item", "node": drop, "active": true, "item": "风"})
		"item":
			pending_item = entry
			_show_bag()
		"finish":
			_victory()

func _apply_talents() -> void:
	player.max_stamina = 100.0 + talents["坚韧"] * 30.0
	player.stamina = minf(player.max_stamina, player.stamina + 30.0)
	player.move_speed = 195.0 + talents["加速"] * 22.0
	player.max_dashes = 1 + talents["更多冲刺"]
	player.dash_count = mini(player.max_dashes, player.dash_count + 1)

func _update_berries() -> void:
	var follower_index := 0
	for berry in berries:
		if berry.state == "collected":
			continue
		if berry.state == "free" and player.position.distance_to(berry.node.global_position) < 23.0:
			if talents["草莓罐头"] > 0:
				_collect_berry(berry)
			else:
				berry.state = "following"
				_sfx("SFX/strawberry_touch")
		if berry.state == "following":
			berry.node.global_position = player.position + Vector2(-player.facing * (24 + follower_index * 14), -20)
			follower_index += 1
	if player.is_on_floor():
		_collect_followers()

func _collect_followers() -> void:
	var col := floori(player.position.x / CHUNK_W + 0.5)
	var row := roundi((80.0 - (player.position.y + 16.0)) / CHUNK_H)
	for berry in berries:
		if berry.state == "following" and berry.key != Vector2i(col, row):
			_collect_berry(berry)

func _collect_berry(berry: Dictionary) -> void:
	berry.state = "collected"
	berry.node.visible = false
	strawberries += 1
	collected_total += 1
	_sfx("SFX/strawberry_collect")

func _on_landed() -> void:
	_collect_followers()

func _die() -> void:
	if not running or player.invulnerable > 0.0:
		return
	deaths += 1
	_sfx("SFX/death")
	for berry in berries:
		if berry.state == "following":
			berry.state = "free"
			berry.node.global_position = berry.origin
	player.position = checkpoint
	player.velocity = Vector2.ZERO
	player.stamina = player.max_stamina
	player.dash_count = player.max_dashes
	player.invulnerable = 1.0
	camera.position = Vector2(checkpoint.x, minf(checkpoint.y - 52, camera_floor))

func _use_item(slot: int) -> void:
	if inventory[slot] == "风":
		inventory[slot] = ""
		player.wind_timer = 10.0
		_sfx("Items/wind_loop")

func _sfx(path: String) -> void:
	var file := "res://Assets/Audio/%s.ogg" % path
	if ResourceLoader.exists(file):
		audio.stream = load(file)
		audio.play()

func _play_music(path: String) -> void:
	music.stream = load("res://Assets/Audio/Music/%s.ogg" % path)
	music.play()

func _build_ui() -> void:
	var background_layer := CanvasLayer.new()
	background_layer.layer = -1
	add_child(background_layer)
	var background := TextureRect.new()
	background.texture = load("res://Assets/Graphics/Background/layer_02_mountains.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.6, 0.75, 0.92, 1)
	background_layer.add_child(background)
	canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root_ui)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(hud)
	var hud_panel := PanelContainer.new()
	hud_panel.position = Vector2(20, 18)
	hud_panel.custom_minimum_size = Vector2(545, 102)
	hud.add_child(hud_panel)
	status = _label("", Vector2(16, 10), 19, Color.WHITE)
	hud_panel.add_child(status)
	prompt = _label("", Vector2(22, 661), 19, Color.WHITE)
	hud.add_child(prompt)
	var title := _label("CELESTRA", Vector2(1020, 20), 23, Color("fff0d2"))
	hud.add_child(title)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(overlay)
	music = AudioStreamPlayer.new()
	music.volume_db = -12
	add_child(music)
	music.finished.connect(func(): music.play())
	audio = AudioStreamPlayer.new()
	audio.volume_db = -3
	add_child(audio)

func _update_hud() -> void:
	status.text = "🍓 %d    冲刺 %d/%d    体力 %d/%d    高度 %dm\n天赋 坚韧%d 加速%d 冲刺%d 罐头%d\n道具 [1] %s  [2] %s  [3] %s" % [strawberries, player.dash_count, player.max_dashes, int(player.stamina), int(player.max_stamina), maxi(0, int((80 - player.position.y) / 10)), talents["坚韧"], talents["加速"], talents["更多冲刺"], talents["草莓罐头"], _item_name(0), _item_name(1), _item_name(2)]

func _item_name(slot: int) -> String:
	return inventory[slot] if inventory[slot] != "" else "空"

func _clear_overlay() -> void:
	for child in overlay.get_children():
		child.queue_free()

func _panel(title: String, subtitle: String = "") -> VBoxContainer:
	_clear_overlay()
	overlay.visible = true
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.08, 0.16, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var panel := Control.new()
	panel.position = Vector2(365, 95)
	panel.size = Vector2(550, 530)
	overlay.add_child(panel)
	var texture := TextureRect.new()
	texture.texture = load("res://Assets/Graphics/UI/Panels/menu_inventory_panel.png")
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(texture)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 15)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 65
	box.offset_top = 55
	box.offset_right = -65
	box.offset_bottom = -50
	panel.add_child(box)
	var heading := _label(title, Vector2.ZERO, 35, Color("334056"))
	box.add_child(heading)
	if subtitle != "":
		var sub := _label(subtitle, Vector2.ZERO, 18, Color("334056"))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(420, 45)
		box.add_child(sub)
	return box

func _button(box: VBoxContainer, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.clip_text = true
	button.custom_minimum_size = Vector2(400, 42 if menu_mode == "bag" else 51)
	button.add_theme_font_size_override("font_size", 19 if menu_mode == "bag" else 23)
	box.add_child(button)
	button.pressed.connect(func():
		_sfx("UI/click")
		action.call()
	)
	return button

func _show_main_menu() -> void:
	menu_mode = "main"
	running = false
	world.visible = false
	hud.visible = false
	var box := _panel("CELESTRA", "向山顶攀登 · 每局随机生成的雪山")
	_button(box, "开始游戏", _new_run)
	_button(box, "设置", _show_settings)
	_button(box, "退出游戏", func(): get_tree().quit())
	_play_music("menu_loop")

func _new_run() -> void:
	if is_instance_valid(world):
		world.queue_free()
	chunks.clear()
	interactables.clear()
	berries.clear()
	finish_col = 999999
	checkpoint = Vector2(0, 50)
	camera_floor = 100000.0
	strawberries = 0
	collected_total = 0
	deaths = 0
	elapsed = 0.0
	finished = false
	talents = {"坚韧": 0, "加速": 0, "更多冲刺": 0, "草莓罐头": 0}
	inventory = ["", "", ""]
	pending_item = {}
	_build_world()
	menu_mode = "game"
	running = true
	world.visible = true
	hud.visible = true
	overlay.visible = false
	player.controls_enabled = true
	_play_music("gameplay_loop")

func _show_pause() -> void:
	if not running:
		return
	menu_mode = "pause"
	player.controls_enabled = false
	var box := _panel("暂停", "山会在这里等你")
	_button(box, "继续游戏", _resume)
	_button(box, "设置", _show_settings)
	_button(box, "主菜单", _show_main_menu)
	_sfx("UI/pause")

func _resume() -> void:
	menu_mode = "game"
	player.controls_enabled = true
	overlay.visible = false
	_sfx("UI/resume")

func _show_settings() -> void:
	var previous := menu_mode
	menu_mode = "settings"
	var box := _panel("设置", "控制：AD 移动 / W S 爬墙 / Space 跳跃 / J 抓墙 / K 冲刺")
	_button(box, "返回", func():
		if previous == "pause": _show_pause()
		else: _show_main_menu()
	)

func _show_bag() -> void:
	if not running:
		return
	menu_mode = "bag"
	player.controls_enabled = false
	var box := _panel("背包", "上栏：装备槽；下栏：附近掉落物。风：减小重力与抓墙消耗 10 秒")
	box.get_parent().position = Vector2(365, 40)
	box.get_parent().size = Vector2(550, 640)
	box.add_theme_constant_override("separation", 8)
	for i in range(3):
		var index := i
		_button(box, "[%d] %s　（点击卸下）" % [i + 1, _item_name(i)], func(): _drop_slot(index))
	var available: Array[Dictionary] = []
	if not pending_item.is_empty() and pending_item.active:
		available.append(pending_item)
	for entry in interactables:
		if entry.kind == "item" and entry.active and entry.node.global_position.distance_to(player.position) < 95.0 and not available.has(entry):
			available.append(entry)
	var section := _label("附近掉落物：%d" % available.size(), Vector2.ZERO, 20, Color("334056"))
	box.add_child(section)
	if available.size() > 0:
		var picked := available[0]
		for i in range(3):
			var index := i
			_button(box, "风 → 栏位 %d（替换已有道具）" % (i + 1), func(): _equip(picked, index))
	_button(box, "返回游戏", _resume)

func _drop_slot(slot: int) -> void:
	if inventory[slot] != "":
		inventory[slot] = ""
		var drop := _marker(world, player.position + Vector2(24 + slot * 14, -20), "Items/wind")
		interactables.append({"kind": "item", "node": drop, "active": true, "item": "风"})
	_show_bag()

func _equip(entry: Dictionary, slot: int) -> void:
	if inventory[slot] != "":
		var drop := _marker(world, player.position + Vector2(-28, -20), "Items/wind")
		interactables.append({"kind": "item", "node": drop, "active": true, "item": "风"})
	inventory[slot] = entry.item
	entry.active = false
	entry.node.visible = false
	pending_item = {}
	_show_bag()

func _victory() -> void:
	finished = true
	menu_mode = "victory"
	player.controls_enabled = false
	var box := _panel("登顶成功！", "耗时 %d 秒 · 收集 %d 草莓 · 死亡 %d 次" % [int(elapsed), collected_total, deaths])
	_button(box, "再来一局", _new_run)
	_button(box, "主菜单", _show_main_menu)
	_play_music("victory")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if menu_mode == "game":
			_show_pause()
		elif menu_mode == "pause" or menu_mode == "bag":
			_resume()
		elif menu_mode == "settings":
			_show_main_menu()
