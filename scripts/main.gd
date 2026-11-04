extends Node2D

const TILE := 32
const COLS := 40
const ROWS := 24

func _ready() -> void:
	var player := Player.new()
	player.position = Vector2(COLS, ROWS) * TILE * 0.5   # centre du sol
	player.died.connect(_on_player_died)
	add_child(player)

	# Zombies marcheurs
	for cell in [Vector2(5, 4), Vector2(34, 4), Vector2(6, 19), Vector2(33, 18), Vector2(20, 3)]:
		_spawn_zombie("walker", cell)
	# Zombies coureurs
	for cell in [Vector2(36, 12), Vector2(4, 12)]:
		_spawn_zombie("runner", cell)

func _spawn_zombie(kind: String, cell: Vector2) -> void:
	var z := Zombie.new()
	z.kind = kind
	z.position = cell * TILE
	add_child(z)

func _on_player_died() -> void:
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()

func _draw() -> void:
	for y in ROWS:
		for x in COLS:
			var c := Color(0.165, 0.2, 0.25)
			if (x + y) % 2 == 1:
				c = Color(0.18, 0.22, 0.27)
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), c)
