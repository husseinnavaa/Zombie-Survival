# Game Design Document — Zombie Survival 2D

## 1. Introduction

Ce document présente le Game Design Document (GDD) de **Outbreak: Sector 2D** (titre temporaire), un jeu d'action et de survie **top-down 2D** (vue du dessus). Le joueur doit survivre à des zombies tout en gérant ses munitions et en atteignant la sortie de chaque niveau. L'ambiance est rétro, sombre et exigeante.

## 2. Spécifications

### 2.1. Concept

Un jeu de tir et de survie en 2D vu du dessus. Le joueur incarne un survivant qui traverse des environnements urbains ravagés par une épidémie de zombies. Le gameplay repose sur l'exploration, la gestion des munitions, le combat tactique et l'évitement des zombies.

### 2.2. Histoire

En 2028, un virus biochimique expérimental se propage dans la métropole de New Haven et transforme la population en morts-vivants agressifs. Alex, un ancien mécanicien, tente de traverser la ville pour atteindre le dernier point d'évacuation de l'armée avant la mise en quarantaine définitive du secteur.

### 2.3. Structure du jeu

Pour rester réaliste, le jeu est limité à **3 niveaux**, qui représentent la progression à travers la ville :

| Niveau | Lieu | Contenu principal | Partie du projet |
|---|---|---|---|
| 1 | La Banlieue | Zombies marcheurs et coureurs, clé et porte verrouillée | Partie 1 |
| 2 | Le Centre-Ville | Plus de zombies, nouvelle disposition | Partie 2 |
| 3 | Le Métro | Zombie cracheur et boss **Le Boucher** | Partie 2 |

Chaque niveau est un espace fermé avec un point d'arrivée précis. Si le temps le permet, des niveaux supplémentaires pourront s'ajouter (voir la section 10).

### 2.4. Joueurs

Mode solo : campagne principale.

### 2.5. Actions

- **Déplacement :** marcher, courir (consomme de l'endurance), s'accroupir.
- **Combat :** viser, tirer, recharger, attaque au corps à corps.
- **Interaction :** fouiller des caisses, ouvrir des portes, activer des points de sauvegarde.

### 2.6. Objectifs

- **Principal :** survivre et atteindre la sortie de chaque niveau.
- **Secondaires (si le temps le permet) :** sauver des survivants isolés, trouver des documents secrets sur l'origine du virus.

### 2.7. Visuel

- **Style artistique :** pixel art sombre et crasseux. Palette de couleurs froides (bleus, gris) qui contraste avec le rouge vif du sang et le jaune clair des sources de lumière (lampe torche, incendies).
- **Boucle de jeu :**

```text
[Zone de départ] -> [Exploration / Loot] -> [Affrontement de zombies] -> [Clé / Porte verrouillée] -> [Sortie ou Boss]
```

## 3. Gameplay

### 3.1. Monde

- **Visibilité :** éclairage dynamique. Le niveau est sombre et le joueur éclaire devant lui avec sa lampe torche. Les murs projettent des ombres.
- **Éléments du décor :**
  - Barils explosifs.
  - Caisses à fouiller (munitions, soins, clé).
  - Porte verrouillée qui demande une clé.
  - Points de sauvegarde.

### 3.2. Ennemis de base

| Ennemi | Description | Partie |
|---|---|---|
| Zombie marcheur | Lent mais résistant, inflige des dégâts au corps à corps | 1 |
| Zombie coureur | Très rapide, repère le joueur de loin, faible santé | 1 |
| Zombie cracheur | Reste à distance et crache de l'acide qui ralentit le joueur | 2 |

### 3.3. Boss

- **Le Boucher** *(partie 2)* : boss de fin du niveau 3. Massif, armé d'un hachoir géant, il provoque des ondes de choc au sol.
- **L'Abomination Alpha** *(bonus)* : créature mutante agile capable de se déplacer rapidement d'un mur à l'autre. Réalisée seulement si le temps le permet.

## 4. Menus

| Menu | Options |
|---|---|
| Menu principal | Nouvelle partie, Charger partie, Options, Crédits, Quitter |
| Menu pause | Reprendre, Inventaire, Options, Quitter vers le menu principal |
| Game over | Recommencer au dernier point de sauvegarde, Quitter |

*Partie 1 :* menu pause et game over simples. *Partie 2 :* tous les menus complets.

## 5. Gestion des données et sauvegarde

### Structures de données

- **Joueur :** position, santé (PV), endurance, munitions, présence de la clé.
- **Ennemis :** machine à états finis (IDLE, CHASE, ATTACK, DEAD).
- **Sauvegarde :** dictionnaire avec la position, les stats du joueur, les zombies tués et les objets utilisés.

### Sauvegarde

- **Partie 1 :** sauvegarde automatique aux points de sauvegarde (en mémoire pendant la partie).
- **Partie 2 :** sauvegarde dans un fichier JSON local pour pouvoir charger la partie.

## 6. Système ciblé

Plateforme principale : ordinateur (macOS et Windows).

## 7. Contrôles

| Action | Touche |
|---|---|
| Déplacement | W A S D ou flèches |
| Viser | Curseur de la souris |
| Tirer | Clic gauche |
| Corps à corps | Clic droit |
| Courir | Maj (Shift) |
| S'accroupir | Ctrl ou C |
| Interagir | E |
| Recharger | R |
| Lampe torche | F |
| Pause | Échap |

## 8. Outils de développement

- **Moteur de jeu :** Godot Engine 4 (GDScript).
- **Gestion de projet :** GitHub (tableau Kanban, branches et Pull Requests).

## 9. Références

- **Project Zomboid :** ambiance de survie, gestion de la tension, exploration urbaine.
- **Hotline Miami :** rythme nerveux, vue du dessus, contrôles réactifs.
- **Dead Cells :** qualité et fluidité des animations en pixel art 2D.

## 10. Planification

### Partie 1 : un seul niveau

- Niveau 1 jouable de bout en bout : joueur, zombies marcheurs et coureurs, caisses, clé, porte, barils explosifs, points de sauvegarde, sortie.
- HUD, menu pause, écrans de mort et de victoire.

### Partie 2 : suite du jeu

- Au moins 2 autres niveaux (niveaux 2 et 3).
- Menus complets, effets visuels, au moins 1 boss (Le Boucher).

### Si le temps le permet

- Zombie cracheur, sprites animés, musique et sons, grenades et cocktail Molotov, objectifs secondaires, boss L'Abomination Alpha, chapitres supplémentaires.
