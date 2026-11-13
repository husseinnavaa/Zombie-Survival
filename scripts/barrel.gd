## Baril explosif (scène barrel.tscn).
## Les balles, les coups et les autres explosions lui infligent des dégâts. À 0 PV il explose (scène
## explosion.tscn).
class_name Barrel
extends StaticBody2D

## Émis quand le baril explose (main.gd mémorise les barils détruits pour la sauvegarde).
signal destroyed(barrel: Barrel)

## Points de vie du baril.
@export var hp := 30.0
## Rayon de l'explosion, en pixels.
@export var blast_radius := 100.0
## Dégâts infligés par l'explosion.
@export var blast_damage := 100.0
## Scène de l'explosion à créer (explosion.tscn).
@export var explosion_scene: PackedScene

# Évite d'exploser deux fois
var exploded := false


## Appelé par les balles, les coups et les autres explosions.
func take_damage(amount: float, _dir: Vector2 = Vector2.ZERO) -> void:
	if exploded:
		return
	hp -= amount
	if hp <= 0.0:
		explode()


## Fait exploser le baril : crée l'explosion à sa position, puis se supprime.
func explode() -> void:
	exploded = true
	destroyed.emit(self)
	# L'explosion reçoit son rayon et ses dégâts avant d'être ajoutée à la scène
	var fx := explosion_scene.instantiate() as Explosion
	fx.position = position
	fx.radius = blast_radius
	fx.damage = blast_damage
	# call_deferred : l'ajout se fait à la fin de l'image, car on est peut-être en plein calcul de
	# collision
	get_parent().add_child.call_deferred(fx)
	queue_free()
