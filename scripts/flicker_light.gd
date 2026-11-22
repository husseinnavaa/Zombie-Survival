## Lumière qui vacille (feux, lampes du métro). À mettre sur un node PointLight2D.
## L'énergie de la lumière varie en continu autour de sa valeur de départ.
class_name FlickerLight
extends PointLight2D

## Amplitude du vacillement : 0.0 = lumière fixe, 0.5 = grandes variations.
@export var flicker := 0.25
## Vitesse du vacillement.
@export var flicker_speed := 9.0

# Énergie de départ (celle réglée dans l'inspecteur) et phase de l'oscillation
var base_energy := 1.0
var phase := 0.0


## Mémorise l'énergie de départ. La phase est aléatoire pour que deux lumières ne vacillent pas pareil.
func _ready() -> void:
	base_energy = energy
	phase = randf() * 10.0


## Fait varier l'énergie : une oscillation douce (sin) plus un petit bruit aléatoire.
func _process(delta: float) -> void:
	phase += delta * flicker_speed
	var noise := randf_range(-flicker, flicker) * 0.5
	energy = maxf(0.0, base_energy * (1.0 + sin(phase) * flicker * 0.5 + noise))
