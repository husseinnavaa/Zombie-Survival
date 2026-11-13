## Explosion (scène explosion.tscn) : particules, flash de lumière et dégâts de zone.
## Les dégâts sont appliqués une seule fois, dès que la scène apparaît (_ready), puis la scène se
## supprime.
class_name Explosion
extends Node2D

## Rayon des dégâts, en pixels.
@export var radius := 100.0
## Dégâts maximum (le joueur n'en reçoit que 40 %).
@export var damage := 100.0

# Lumière orange qui s'éteint progressivement
@onready var flash: PointLight2D = $Flash


## Applique tous les effets de l'explosion d'un seul coup, puis attend 1,2 s (le temps des
## particules) avant de se supprimer.
func _ready() -> void:
	# La lumière du flash s'éteint en 0,4 s
	create_tween().tween_property(flash, "energy", 0.0, 0.4)
	# Les zombies dans le rayon reçoivent les dégâts complets et sont repoussés
	for z in get_tree().get_nodes_in_group("zombies"):
		var zn := z as Node2D
		if zn.global_position.distance_to(global_position) < radius:
			z.take_damage(damage, zn.global_position - global_position)
	# Le joueur : secousse de caméra, et 40 % des dégâts s'il est dans le rayon
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null:
		p.add_shake(10.0)
		if p.alive and p.global_position.distance_to(global_position) < radius:
			p.take_damage(damage * 0.4)
	# Les barils proches explosent à leur tour
	for b in get_tree().get_nodes_in_group("barrels"):
		var bn := b as Node2D
		if bn.global_position.distance_to(global_position) < radius:
			b.take_damage(999.0)   # réaction en chaîne
	# Le bruit de l'explosion alerte les zombies dans un rayon de 500 pixels
	get_tree().call_group("zombies", "hear_noise", global_position, 500.0)
	# Laisse le temps aux particules de se terminer avant de supprimer la scène
	await get_tree().create_timer(1.2).timeout
	queue_free()
