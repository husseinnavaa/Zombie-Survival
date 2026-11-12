class_name Door
extends StaticBody2D

signal opened

var used := false

@onready var closed_visual: Node2D = $Visual/Closed
@onready var open_visual: Node2D = $Visual/Open


func get_hint(player: Player) -> String:
	if player.has_key:
		return "E — Ouvrir la porte"
	return "E — Porte verrouillée"


func interact(player: Player) -> void:
	if used:
		return
	if player.has_key:
		open()
		player.message.emit("Porte déverrouillée")
	else:
		player.message.emit("Verrouillée : il faut trouver la clé")


func open() -> void:
	used = true
	collision_layer = 0
	remove_from_group("dynamic_obstacle")   # les zombies peuvent maintenant passer
	closed_visual.hide()
	open_visual.show()
	opened.emit()


func restore_used() -> void:
	open()
