## Caisse fouillable (scène crate.tscn).
## Le joueur appuie sur E à côté : la caisse s'ouvre et donne des munitions, des soins ou rien.
## Une caisse spéciale (has_key coché dans l'inspecteur) contient la clé de la porte.
class_name Crate
extends StaticBody2D

@export var has_key := false   # coché dans l'inspecteur pour la caisse qui contient la clé

# Vrai quand la caisse a déjà été fouillée (le groupe 'stateful' sert à la sauvegarde)
var used := false

# Les deux apparences de la caisse : fermée et ouverte (une seule est visible à la fois)
@onready var closed_visual: Node2D = $Visual/Closed
@onready var open_visual: Node2D = $Visual/Open


## Texte d'aide affiché au joueur quand la caisse est proche (appelé par player.gd).
func get_hint(_player: Player) -> String:
	return "E — Fouiller la caisse"


## Appelé par le joueur quand il appuie sur E à côté de la caisse. 'player' est le joueur qui
## fouille.
func interact(player: Player) -> void:
	if used:
		return
	_set_open()
	if has_key:
		player.give_key()
		return
	# Loot aléatoire : 50 % de munitions, 30 % de soins, 20 % de caisse vide
	var r := randf()
	if r < 0.5:
		player.add_ammo(randi_range(6, 12))
	elif r < 0.8:
		player.heal(30.0)
	else:
		player.message.emit("La caisse est vide…")


## Remet la caisse à l'état « déjà fouillée » (utilisé par la sauvegarde de main.gd).
func restore_used() -> void:
	_set_open()


## Marque la caisse comme utilisée et affiche l'apparence ouverte.
func _set_open() -> void:
	used = true
	closed_visual.hide()
	open_visual.show()
