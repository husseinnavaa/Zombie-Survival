class_name Crate
extends StaticBody2D

@export var has_key := false   # coché dans l'inspecteur pour la caisse qui contient la clé

var used := false

@onready var closed_visual: Node2D = $Visual/Closed
@onready var open_visual: Node2D = $Visual/Open


func get_hint(_player: Player) -> String:
	return "E — Fouiller la caisse"


func interact(player: Player) -> void:
	if used:
		return
	_set_open()
	if has_key:
		player.give_key()
		return
	var r := randf()
	if r < 0.5:
		player.add_ammo(randi_range(6, 12))
	elif r < 0.8:
		player.heal(30.0)
	else:
		player.message.emit("La caisse est vide…")


func restore_used() -> void:
	_set_open()


func _set_open() -> void:
	used = true
	closed_visual.hide()
	open_visual.show()
