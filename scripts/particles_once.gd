## Particules jouées une seule fois (sang, flash de tir) : le node se supprime tout seul une fois
## l'effet terminé.
extends CPUParticles2D

## Lance l'émission, attend la fin de la durée de vie des particules (+ 0,3 s de marge), puis se
## supprime.
func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.3).timeout
	queue_free()
