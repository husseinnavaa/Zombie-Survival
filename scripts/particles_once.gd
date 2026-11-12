extends CPUParticles2D
# Particules jouées une seule fois, puis la scène se supprime.

func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.3).timeout
	queue_free()
