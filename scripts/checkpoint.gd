## Point de sauvegarde (scène checkpoint.tscn, un Area2D).
## Quand le joueur entre dans la zone, le signal 'activated' est émis : main.gd enregistre alors la
## partie.
class_name Checkpoint
extends Area2D

## Émis la première fois que le joueur touche le point de sauvegarde.
signal activated(checkpoint: Checkpoint)

# Vrai une fois activé (le point devient vert)
var used := false

# 'Pad' : la plateforme colorée ; 'Core' : le petit carré central qui clignote
@onready var pad: Polygon2D = $Pad
@onready var core: Polygon2D = $Core


## Branche la détection du joueur et fait clignoter le centre du point de sauvegarde en boucle.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Animation en boucle : le centre devient transparent puis opaque
	var tw := create_tween().set_loops()
	tw.tween_property(core, "modulate:a", 0.4, 0.8)
	tw.tween_property(core, "modulate:a", 1.0, 0.8)


## Appelé quand un corps entre dans la zone : seul le joueur, et une seule fois, active le point.
func _on_body_entered(body: Node2D) -> void:
	if used or not body.is_in_group("player"):
		return
	_mark_used()
	activated.emit(self)


## Marque le point comme déjà activé quand on reprend une sauvegarde.
func restore_used() -> void:
	_mark_used()


## Passe le point en état « activé » : il devient vert.
func _mark_used() -> void:
	used = true
	pad.color = Color("4fd16a")
