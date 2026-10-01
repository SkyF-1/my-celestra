extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._new_run()
	await process_frame
	assert(game.running)
	assert(game.chunks.size() >= 5)
	game.player.position = Vector2(0, -1260)
	game._generate_nearby()
	assert(game.chunks.has(Vector2i(0, 7)))
	assert(game.chunks.has(Vector2i(0, 8)))
	var saw_finish := false
	for entry in game.interactables:
		if entry.kind == "finish":
			saw_finish = true
	assert(saw_finish)
	game.strawberries = 10
	for entry in game.interactables:
		if entry.kind == "talent" and entry.active:
			game._interact(entry)
			assert(game.talents[entry.talent] == 1)
			break
	game._die()
	assert(game.deaths == 1)
	game._show_bag()
	assert(game.menu_mode == "bag")
	game._resume()
	game._show_pause()
	game._resume()
	game._victory()
	assert(game.finished)
	print("SMOKE_OK chunks=%d items=%d" % [game.chunks.size(), game.interactables.size()])
	quit()
