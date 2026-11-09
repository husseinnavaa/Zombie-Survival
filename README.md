# Outbreak: Sector 2D — Partie 1

Jeu d'action/survie **top-down 2D** fait avec **Godot 4.3+** (renderer Compatibilité).
Le jeu est construit avec des **scènes et des nodes** : tout est visible et modifiable dans l'éditeur.

## Ouvrir
Godot → *Importer* → `project.godot` → F5. (Au premier lancement, Godot importe les images : patiente un instant.)

## Contrôles
W A S D / flèches : bouger · Souris : viser · Clic gauche : tirer · Clic droit : corps à corps ·
Maj : courir · Ctrl ou C : s'accroupir · E : interagir · R : recharger · F : lampe · Échap : pause.
(Les touches sont dans *Projet → Paramètres du projet → Map des entrées*.)

## Arborescence
```
assets/            images (sol, mur, lumières)
scripts/           un script par scène (player, zombie, crate, door, barrel, level, hud...)
scenes/
  main.tscn        Main (Node) = Level1 + HUD
  levels/level1.tscn   le niveau : Floor, Walls, Props, Zombies, Player
  player/          player.tscn, bullet.tscn
  enemies/         zombie.tscn, zombie_runner.tscn (scène héritée)
  props/           wall, crate, barrel, door, checkpoint, exit
  effects/         explosion, blood_hit, muzzle_flash, blood_stain
  ui/hud.tscn      barres, textes, menus pause / mort / victoire
```

## Idées de Godot utilisées
- **Scènes instanciées** (un mur = une scène placée 300 fois), **scène héritée** (le coureur hérite du marcheur).
- **Signaux** : le joueur émet `health_changed`, `ammo_changed`, `died`... ; `game.gd` les relie au HUD.
- **Groupes** : `zombies`, `wall`, `barrels`, `interactable`, `stateful`... (`call_group`, `get_nodes_in_group`).
- **Nodes** pour la physique et les effets : CollisionShape2D, Area2D, RayCast2D (vue des zombies),
  Timer, PointLight2D + LightOccluder2D, CPUParticles2D, Camera2D, Control/Container/ProgressBar/Button.
- **Input Map** (actions) au lieu de touches écrites dans le code.

## Pour modifier le niveau
Ouvre `scenes/levels/level1.tscn` : déplace un zombie, ajoute une caisse (glisse `props/crate.tscn`),
coche `Has Key` sur une caisse pour y mettre la clé. Pour un nouveau niveau : duplique `level1.tscn`.
Astuce : pendant l'édition, cache `CanvasModulate` (l'œil) pour voir le niveau en clair.
