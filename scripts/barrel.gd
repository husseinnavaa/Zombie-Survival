class_name Barrel
extends StaticBody2D

signal destroyed(barrel: Barrel)

@export var hp := 30.0
@export var blast_radius := 100.0
@export var blast_damage := 100.0
@export var explosion_scene: PackedScene

var exploded := false


func take_damage(amount: float, _dir: Vector2 = Vector2.ZERO) -> void:
	if exploded:
		return
	hp -= amount
	if hp <= 0.0:
		explode()


func explode() -> void:
	exploded = true
	destroyed.emit(self)
	var fx := explosion_scene.instantiate() as Explosion
	fx.position = position
	fx.radius = blast_radius
	fx.damage = blast_damage
	get_parent().add_child.call_deferred(fx)
	queue_free()
