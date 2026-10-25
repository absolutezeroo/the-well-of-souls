# Inspirations de Shattered Pixel Dungeon

Étude du 25 octobre 2026 pour **Le Puits des Âmes**. Propositions de conception uniquement ; aucune mécanique ajoutée.

## Périmètre

34 fichiers sources parcourus dans le dépôt public 00-Evan/shattered-pixel-dungeon, révision **57a4e06a4caf162446d1c28caa7983f0493fecf0** : champions, enchantements, consommables, babioles, recettes, génération et salles spéciales. Comparaison avec le Puits à **e6d5270**, définitions et points d’application compris. Mob, Generator, Level, Weapon, Armor et RegularLevel ont aussi été consultés pour suivre les appels réels.

Lecture directe via GitHub ; REA n’est pas nécessaire pour ces sources publiques. Aucun exécutable lancé, aucun scénario joué ni coût mobile mesuré. Les observations de code sont vérifiées ; l’intérêt ludique et l’effort estimé restent à tester. Les exemples ci-dessous sont nos adaptations, pas des descriptions de fonctionnalités présentes dans le Puits.

Les en-têtes de Shattered indiquent GPL-3.0 ou ultérieure. L’étude décrit des mécanismes ; aucun fichier Java ni asset de Shattered n’est intégré au projet.

## Ce qui existe déjà dans le Puits

| Shattered | Puits des Âmes | Conséquence |
|---|---|---|
| Champions ajoutant des comportements au monstre de base | EliteAffixDef, MonsterTraits, affixes composables | Consolider l’existant ; pas de second système de champions. |
| Enchantements élémentaires et vol de vie | Affixes, runes, passifs, familles | Chercher des interactions nouvelles plutôt que renommer un effet existant. |
| Salles spéciales, trésors cachés, autels | Salles signatures, SecretRoom, rencontres, épreuves | Étendre les points d’entrée existants. |
| Construction du personnage | Atouts, reliques, familles, forge, serments | Réutiliser définitions, fenêtres et sauvegardes. |

## Six pistes retenues

### 1. Consommables tactiques — priorité

**Observé :** la purification retire des effets négatifs puis applique une protection temporaire ; la pierre de déplacement exploite la destination du lancer. Peur et brouillard apportent d’autres réponses aux ennemis [S1–S4].

**Adaptation proposée :** une fiole de givre (faibles dégâts et ralentissement autour du héros), une potion de purification (brûlure/poison), une pierre de fuite (déplacement court dans la direction visée). Noms provisoires, valeurs à équilibrer. Cela crée un choix entre soin, contrôle et fuite dans les trois emplacements de ceinture actuels.

**Réemploi :** ConsumableDef.effects, DamageAreaEffect, OnHitStatus, StatusSet, Belt et PlayerPack. La fiole peut principalement utiliser des données ; purification et déplacement demandent chacun un Effect dédié. Leurs comportements complets n’existent pas aujourd’hui.

**Art/effort estimés :** très peu de dessin, icônes existantes différenciées par teinte/glyphe/nom et VFX existants ; effort petit à moyen.

**Points à vérifier :** préserver les règles de terrain en purifiant (le sable ralentit de nouveau tant qu’on y reste), contrôler mur/eau profonde/trou/occupation à la destination, consommer exactement un objet. Garder le ciblage tactile actuel, sans exiger un clic précis au milieu du combat.

Roadmap : task_273.

### 2. Salle à récompense exclusive — priorité

**Observé :** CrystalChoiceRoom construit deux branches, l’une avec des consommables, l’autre avec un coffre d’une autre catégorie, et fait générer une clé de cristal [S5].

**Adaptation proposée :** une offrande à trois niches : soins, rune ou équipement ; choisir engage la salle une fois. Première version sous forme de rencontre à trois options. Une salle physique avec plusieurs coffres liés peut venir ensuite.

**Réemploi :** EncounterDef, EncounterChoice, EncounterOutcome, Encounter et le panneau existant. Employer un résultat garanti par option. Trois coffres ordinaires côte à côte ne constituent pas un choix exclusif : la version physique demanderait un propriétaire commun.

**Art/effort estimés :** faibles pour une rencontre avec statue/niches existantes ; moyens pour une salle physique.

**Points à vérifier :** expliquer la récompense avant le choix, déposer le gain au sol si le sac est plein selon les règles existantes, sauvegarder le choix, empêcher double interaction/récompense et changement après reprise.

Roadmap : task_274, liée à task_107.

### 3. Enchantements qui changent le placement

**Observé :** Elastic projette sa cible selon la trajectoire attaquant–défenseur [S6]. Autre idée, plus délicate : Viscosity reporte une partie du dégât après armure dans une dette de dégâts ultérieurs, sauvegardée avec le buff [S7].

**Adaptation proposée :** commencer par un affixe de recul renforcé, avec un déclencheur lisible. Cela valorise les couloirs, murs et trous existants. L’armure à dette serait une expérience ultérieure.

**Réemploi :** ItemAffixDef.passives, Passive.modify_outgoing_hit, HitInfo.knockback et résistance au recul. Un passif réutilisable et ses paramètres dans les ressources. Très peu d’art ; effort faible à moyen pour le recul.

**Points à vérifier :** boss résistants, chute, dégâts secondaires et cumul de recul. L’armure à dette est un chantier supérieur : Passive.on_damaged intervient après la perte de Santé et ne suffit pas à différer un coup. Il faudrait conserver dette/rythme/attribution sur reprise et changement d’étage, éviter une seconde mitigation et afficher la dette au joueur. Ne pas inclure cette armure dans le premier lot.

Roadmap : task_275.

### 4. Reliques qui modifient la descente

**Observé :** MossyClump conserve une séquence d’ambiances de terrain ; ParchmentScrap modifie les chances d’enchantement/malédiction ; ExoticCrystals modifie la fréquence des variantes de consommables. Level applique MossyClump, Generator applique ExoticCrystals et Weapon/Armor appliquent ParchmentScrap [S8–S10, S18–S21].

**Adaptation proposée :** une relique ou un serment donnant davantage de butin de qualité contre moins de soins ; autre piste, plus de salles cachées contre plus d’élites. Exemples à équilibrer, sans coefficients décidés.

**Réemploi :** OathDef/RunBoons gèrent déjà or, qualité et prix ; FloorRules demeure l’autorité d’un étage. Une version en serment de départ est plus simple qu’une relique acquise en cours de partie. Les chances de salles/élites/catégories de butin nécessitent de nouveaux points de configuration : une ressource seule ne suffit pas.

**Art/effort estimés :** peu d’art ; effort moyen à important suivant les règles.

**Points à vérifier :** appliquer les changements aux prochains étages, sauvegarder les ids et l’état de partie, respecter le défi quotidien, annoncer quand l’effet commencera. Ne pas modifier un DungeonConfig partagé ni reconstruire un étage déjà généré après prise de la relique.

Roadmap : enrichissement de task_36, déjà consacrée aux reliques qui changent une règle.

### 5. Alchimie courte

**Observé :** Recipe expose validation des ingrédients, coût, résultat et aperçu ; les recettes sont aussi sélectionnées selon le nombre d’ingrédients [S11].

**Adaptation proposée :** trois ou quatre recettes au repos : combiner des soins pour une version forte, ou une bombe et un consommable de froid pour une bombe de givre. Ce sont des exemples pour le Puits, pas des recettes attestées de Shattered. Commencer avec les objets existants et un coût d’or.

**Réemploi :** fenêtres sac/forge et ConsumableDef.effects ; ajouter une définition de recette en données et un service de fabrication. La forge ne fait actuellement que sertir/retirer les runes : il faut réellement implémenter la fabrication et son interface.

**Art/effort estimés :** peu de dessin avec des variantes d’icônes ; effort moyen, surtout transactions et interface.

**Points à vérifier :** aperçu exact, ingrédients dans sac/ceinture, piles et capacité du résultat. Tout vérifier avant de retirer les ingrédients. Aucun objet perdu/dupliqué en cas de refus, d’annulation ou de reprise. Éviter une boucle fabrication/revente rentable sans limite.

Roadmap : task_276.

### 6. Salles résolues par les objets

**Observé :** MagicalFireRoom ajoute une potion de froid aux objets à générer ; ToxicGasRoom ajoute une potion de pureté. Freezing agit sur le feu ; Burning peut s’éteindre dans l’eau [S12–S15]. La salle prépare un obstacle et un moyen d’agir dessus.

**Adaptation proposée :** une salle optionnelle de brasier protégeant du butin, avec une fiole de givre accessible dans l’étage. Récompenser la compréhension d’un objet, avec une solution de repli si l’outil a été dépensé ailleurs. Le trajet normal vers les escaliers reste possible.

**Réemploi :** SceneDef, salles signatures, hazards et effets. VfxElementDef décrit surtout l’apparence : feu et givre visuels ne créent pas automatiquement une interaction. Ajouter un contrat explicite de réaction entre effet et obstacle.

**Art/effort estimés :** faible besoin de dessin avec les VFX existants ; effort important de code et de validation.

**Points à vérifier :** outil accessible avant l’obstacle, jamais derrière lui ; pas de porte obligatoire dépendant d’un butin aléatoire ; obstacle résolu sauvegardé ; nav, ligne de vue et nombre de zones actives bornés. L’eau profonde du Puits bloque actuellement la marche : elle ne peut pas devenir telle quelle le bassin où le héros entre pour éteindre sa brûlure.

Roadmap : enrichissement de task_108, liée à task_107.

## Une leçon de génération : limiter les répétitions

SpecialRoom mélange deux listes, favorise le début d’une file et remet les types utilisés en fin de file. SecretRoom emploie une logique voisine et un budget par région. Generator utilise aussi des paquets pondérés dont les poids diminuent au fil des tirages [S16–S18].

Le Puits limite déjà certaines répétitions par étage et augmente la chance de forge après une absence. Il ne possède pas de mémoire de partie généralisée des salles et récompenses récentes : SecretRoom utilise un flux propre à l’étage ; RoomShaper compte les formes du seul étage courant.

**Proposition :** mémoire bornée des salles/récompenses récentes, ids stables et état dans la sauvegarde de partie. Préserver filtres biome/profondeur, déterminisme du quotidien et flux aléatoire isolé. Assainir les ids retirés sans bloquer un tirage. Aucun dessin ; effort moyen lié au contrat de génération/sauvegarde.

Roadmap : task_277.

## Ordre conseillé et limites

1. Consommables tactiques + rencontre de choix : nouvelles décisions, forte réutilisation.
2. Affixe de recul + variété entre étages : enrichir équipement et exploration.
3. Alchimie courte après validation des consommables.
4. Reliques de destinée et salles à interactions, avec essais ciblés de sauvegarde/génération et lisibilité mobile.

Ne pas commencer par faim, identification aléatoire de toutes les potions, destruction du sac par les éléments ou propagation générale de gaz. Le rythme en temps réel demande une décision de conception propre. Les nombres de Shattered ne constituent pas un équilibrage du Puits.

## Sources vérifiées

Liens épinglés à la révision étudiée. Les ancres ci-dessous pointent le début des méthodes ou sections pertinentes.
- [S1 — PotionOfCleansing.java, ligne 47](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/potions/exotic/PotionOfCleansing.java#L47)
- [S2 — StoneOfBlink.java, ligne 39](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/stones/StoneOfBlink.java#L39)
- [S3 — StoneOfFear.java, ligne 42](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/stones/StoneOfFear.java#L42)
- [S4 — PotionOfShroudingFog.java, ligne 40](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/potions/exotic/PotionOfShroudingFog.java#L40)
- [S5 — CrystalChoiceRoom.java, ligne 95](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/rooms/special/CrystalChoiceRoom.java#L95)
- [S6 — Elastic.java, ligne 39](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/weapon/enchantments/Elastic.java#L39)
- [S7 — Viscosity.java, ligne 45](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/armor/glyphs/Viscosity.java#L45)
- [S8 — MossyClump.java, ligne 54](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/trinkets/MossyClump.java#L54)
- [S9 — ParchmentScrap.java, ligne 48](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/trinkets/ParchmentScrap.java#L48)
- [S10 — ExoticCrystals.java, ligne 48](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/trinkets/ExoticCrystals.java#L48)
- [S11 — Recipe.java, ligne 150](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/Recipe.java#L150)
- [S12 — MagicalFireRoom.java, ligne 57](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/rooms/special/MagicalFireRoom.java#L57)
- [S13 — ToxicGasRoom.java, ligne 49](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/rooms/special/ToxicGasRoom.java#L49)
- [S14 — Freezing.java, ligne 40](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/blobs/Freezing.java#L40)
- [S15 — Burning.java, ligne 97](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/buffs/Burning.java#L97)
- [S16 — SpecialRoom.java, ligne 82](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/rooms/special/SpecialRoom.java#L82)
- [S17 — SecretRoom.java, ligne 45](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/rooms/secret/SecretRoom.java#L45)
- [S18 — Generator.java, ligne 256](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/Generator.java#L256)

- [S19 — Level.java, ligne 285](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/Level.java#L285)
- [S20 — Weapon.java, ligne 439](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/weapon/Weapon.java#L439)
- [S21 — Armor.java, ligne 671](https://github.com/00-Evan/shattered-pixel-dungeon/blob/57a4e06a4caf162446d1c28caa7983f0493fecf0/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/armor/Armor.java#L671)

## Validation de l’étude

Chemins et ancres des sources contrôlés sur les fichiers consultés ; références au Puits comparées au code local ; ids de roadmap vérifiés. Documentation et roadmap uniquement : aucune modification de src/, data/, des sauvegardes ou des tests. Les suites du moteur ne sont pas relancées pour cette étude documentaire. La jouabilité des propositions reste à valider après une éventuelle implémentation.
