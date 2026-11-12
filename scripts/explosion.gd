class_name Explosion
extends Node2D
# Scène explosion.tscn : particules (nodes CPUParticles2D) + lumière + dégâts de zone.

@export var radius := 100.0
@export var damage := 100.0

@onready var flash: PointLight2D = $Flash


func _ready() -> void:
	create_tween().tween_property(flash, "energy", 0.0, 0.4)
	for z in get_tree().get_nodes_in_group("zombies"):
		var zn := z as Node2D
		if zn.global_position.distance_to(global_position) < radius:
			z.take_damage(damage, zn.global_position - global_position)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null:
		p.add_shake(10.0)
		if p.alive and p.global_position.distance_to(global_position) < radius:
			p.take_damage(damage * 0.4)
	for b in get_tree().get_nodes_in_group("barrels"):
		var bn := b as Node2D
		if bn.global_position.distance_to(global_position) < radius:
			b.take_damage(999.0)   # réaction en chaîne
	get_tree().call_group("zombies", "hear_noise", global_position, 500.0)
	await get_tree().create_timer(1.2).timeout
	queue_free()
