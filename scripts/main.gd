extends Node2D

const TILE := 32
const COLS := 40
const ROWS := 24

func _ready() -> void:
	var player := Player.new()
	player.position = Vector2(COLS, ROWS) * TILE * 0.5   # centre du sol
	add_child(player)


func _draw() -> void:
	for y in ROWS:
		for x in COLS:
			var c := Color(0.165, 0.2, 0.25)
			if (x + y) % 2 == 1:
				c = Color(0.18, 0.22, 0.27)
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), c)
