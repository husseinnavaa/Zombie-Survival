# 1. Introduction
Ce document présente le Game Design Document (GDD) pour Outbreak: Sector 2D (titre temporaire), un jeu d'action et de survie en vue globale (Top-Down) ou vue de côté (Side-Scroller). L'objectif est d'offrir une expérience rétro, immersive et exigeante où le joueur doit survivre à des vagues de zombies tout en gérant ses ressources et en atteignant des zones sécurisées.

# 2. Spécifications

## 2.1. Concept
Un jeu de tir et de survie en 2D où le joueur incarne un survivant naviguant dans des environnements urbains ravagés par une épidémie zombie. Le gameplay repose sur l'exploration, la gestion des munitions, le combat tactique et l'évitement des hordes

## 2.2. Histoire
En 2028, un virus biochimique expérimental se propage dans la métropole de New Haven, transformant la population en morts-vivants agressifs. Alex, un ancien mécanicien, tente de traverser la ville pour atteindre le dernier point d'évacuation de l'armée avant la mise en quarantaine définitive du secteur

## 2.3. Structure du jeu
Le jeu est découpé en 5 chapitres linéaire représentant la progression à travers la ville (ex. La Banlieue, Le Centre-Ville, Le Métro, Le Complexe Scientifique, La Zone d'Évacuation). Chaque chapitre contient 3 à 4 niveaux fermés avec un point d'arrivée précis.

## 2.4. Joueurs
Mode Solo : Campagne principale.

## 2.5. Actions
Déplacement : Marcher, courir (consomme de l'endurance), s'accroupir/se cacher.
Combat : Attaque au corps à corps, viser, tirer, recharger, lancer un projectile (grenade, cocktail Molotov).
Interaction : Ouvrir des portes, fouiller des conteneurs, activer des interrupteurs, ramasser du loot.

## 2.6. Objectif
Principal : Survivre et atteindre la sortie de chaque niveau.
Secondaires : Sauver des survivants isolés, trouver des documents secrets retraçant l'origine du virus, éliminer tous les zombies d'une zone pour débloquer du matériel bonus.


## 2.7. Visuel
•	Style artistique : Pixel Art 16-bit / 32-bit sombre et crasseux, avec une palette de couleurs froides (bleus, grises) contrastant avec le rouge vif du sang et le jaune clair des sources de lumière (lampes torche, incendies).
•	Wireframe / Schéma de la boucle de jeu :
•	[Zone de départ] ➔ [Exploration / Loot] ➔ [Affrontement Horde] ➔ [Résolution d'énigme / Portes] ➔ [Boss / Fin de niveau]


# 3. Gameplay
Description en détail de chaque élément du jeu, comme le monde, les ennemis, les bonus, les obstacles, etc. 

## 3.1. Monde
Visibilité : Utilisation d'un système de champ de vision et d'éclairage dynamique (Fog of War / Lampes torches) limitant la visibilité dans les zones sombres.

Environnement destructible/utilisable : Présence de barils explosifs, de barricades à réparer ou à enfoncer, et de portes verrouillées nécessitant des clés spécifiques.
## 3.2. Ennemi de base
Zombie Marcheur : Lent mais résistant en groupe, inflige des dégâts au corps à corps.

Zombie Coureur : Très rapide, repère le joueur de loin, faible santé mais dangereux si ignoré.

Zombie Cracheur : Reste à distance et crache de l'acide pour ralentir le joueur.
## 3.3. Ennemi boss
Le Boucher : Boss de fin de chapitre 3, massif, armé d'un hachoir géant, provoque des ondes de choc au sol.

L'Abomination Alpha : Boss final du jeu, créature mutante agile capable de se déplacer rapidement d'un mur à l'autre.
## 3.4. Etc.

# 4. Menus
Menu Principal :

Nouvelle Partie | Charger Partie | Options | Crédits | Quitter

Menu Pause :

Reprendre | Inventaire | Options | Quitter vers le menu principal

Menu Game Over :

Recommencer au dernier checkpoint | Quitter
# 5. Gestion des données et sauvegarde
Structures de données
Classe Player : Stocke la position (Vector2), la santé (HP), l'endurance, et l'inventaire actif.

Dictionnaire d'Inventaire : Associe un identifiant d'objet (itemID) à une quantité (count).

Gestion des ennemis : Utilisation d'une machine à états finis (Finite State Machine : Idle, Chase, Attack, Dead) pour chaque ennemi.

Sauvegarde
Format : Fichiers .json locaux cryptés pour stocker la progression du joueur et l'état des niveaux.

Mécanisme : Sauvegarde automatique aux points de passage (checkpoints) entre les zones de transition.

# 6. Système ciblé
Plateforme principale : Ordinateur

# 7. Contrôles
Deplacement : W-A-S-D, les fleche
viser: curseur de la souris
Attaquer: Clic gauche
interagir: Touche E 
Courir: Touche Maj (shift)
Pause: touch echap

# 8. Outils de développement
Moteur de jeu unique : Godot Engine

# 9. Références
Project Zomboid : Référence majeure pour l'ambiance de survie en vue du dessus, la gestion de la tension et l'exploration urbaine.

Hotline Miami : Référence pour le rythme nerveux, la vue top-down et la réactivité des contrôles.

Dead Cells : Référence pour la qualité et la fluidité des animations en Pixel Art 2D.

# 10. Équipe
Adam Belasfar(2733326), El Hussein Navaa(2733158), Wael Feki(2733126)
