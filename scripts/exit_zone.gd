## Zone de sortie du niveau (scène exit.tscn, un Area2D).
## Quand le joueur y entre, le signal 'reached' est émis : main.gd affiche l'écran de victoire.
class_name ExitZone
extends Area2D

## Émis quand le joueur atteint la sortie.
signal reached

## Émis quand le joueur touche la sortie alors qu'elle est verrouillée (boss encore vivant).
signal blocked

## Vrai tant que la sortie est verrouillée. main.gd la verrouille pendant le combat contre le boss.
var locked := false


## Branche la détection d'entrée dans la zone.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Seul le joueur (groupe 'player') déclenche la sortie ; les zombies sont ignorés.
## Si la sortie est verrouillée, on émet 'blocked' au lieu de 'reached'.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if locked:
			blocked.emit()
		else:
			reached.emit()


## Déverrouille la sortie. Si le joueur est déjà dans la zone (il attendait là), on le fait sortir tout de suite.
func unlock() -> void:
	locked = false
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			reached.emit()
