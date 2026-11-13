## Zone de sortie du niveau (scène exit.tscn, un Area2D).
## Quand le joueur y entre, le signal 'reached' est émis : main.gd affiche l'écran de victoire.
class_name ExitZone
extends Area2D

## Émis quand le joueur atteint la sortie.
signal reached


## Branche la détection d'entrée dans la zone.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Seul le joueur (groupe 'player') déclenche la sortie ; les zombies sont ignorés.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		reached.emit()
