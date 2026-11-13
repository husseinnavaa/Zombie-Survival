## Porte verrouillée (scène door.tscn).
## Bloque le passage tant que le joueur n'a pas la clé. Le signal 'opened' permet à main.gd de
## mettre à jour l'objectif.
class_name Door
extends StaticBody2D

## Émis quand la porte s'ouvre.
signal opened

# Vrai quand la porte est ouverte
var used := false

# Les deux apparences de la porte : fermée et ouverte
@onready var closed_visual: Node2D = $Visual/Closed
@onready var open_visual: Node2D = $Visual/Open


## Texte d'aide selon que le joueur a la clé ou non (appelé par player.gd).
func get_hint(player: Player) -> String:
	if player.has_key:
		return "E — Ouvrir la porte"
	return "E — Porte verrouillée"


## Appelé quand le joueur appuie sur E : ouvre la porte s'il a la clé, sinon affiche un message.
func interact(player: Player) -> void:
	if used:
		return
	if player.has_key:
		open()
		player.message.emit("Porte déverrouillée")
	else:
		player.message.emit("Verrouillée : il faut trouver la clé")


## Ouvre la porte : supprime sa collision, la retire des obstacles du chemin des zombies et change
## son apparence.
func open() -> void:
	used = true
	# Plus de collision : le joueur et les zombies peuvent passer
	collision_layer = 0
	remove_from_group("dynamic_obstacle")   # les zombies peuvent maintenant passer
	closed_visual.hide()
	open_visual.show()
	opened.emit()


## Rouvre la porte quand on reprend une sauvegarde où elle était déjà ouverte.
func restore_used() -> void:
	open()
