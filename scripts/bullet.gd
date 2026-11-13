## Balle tirée par le joueur (scène bullet.tscn, un Area2D).
## Elle avance en ligne droite et disparaît au premier contact ou après 'lifetime' secondes.
class_name Bullet
extends Area2D

## Vitesse en pixels par seconde.
@export var speed := 720.0
## Dégâts infligés à la cible.
@export var damage := 25.0
## Durée de vie maximale en secondes (évite que les balles volent à l'infini).
@export var lifetime := 1.2

# Direction du tir : assignée par le joueur au moment de la création
var direction := Vector2.RIGHT


## Branche la détection de contact et programme la disparition de la balle après 'lifetime'
## secondes.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


## Fait avancer la balle à vitesse constante.
func _physics_process(delta: float) -> void:
	position += direction * speed * delta


## Au contact d'un corps : lui inflige des dégâts s'il peut en recevoir (zombie, baril), puis
## détruit la balle.
## Les murs arrêtent aussi la balle (le masque de collision de bullet.tscn les inclut).
func _on_body_entered(body: Node2D) -> void:
	# Les murs n'ont pas de méthode take_damage : ils arrêtent la balle sans être blessés
	if body.has_method("take_damage"):
		body.take_damage(damage, direction)
	queue_free()
