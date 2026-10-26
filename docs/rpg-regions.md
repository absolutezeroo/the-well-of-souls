# RPG : deux lieux chargés et objets persistants

The [classic RPG](rpg-classic.md) now uses a separate authored campaign atlas from F5;
the two-place scene below remains a developer proof. Exploration, death and explicit rest
are implemented by the current campaign; older scope statements here are historical.

Troisième lot de fondations. Voir la [roadmap](rpg-roadmap.md) et le
[checkpoint de campagne](rpg-persistence.md). Cette preuve charge de vraies cartes avec le
rendu, la collision, la navigation et le joueur existants. Elle reste distincte du menu et du
mode roguelike : pas encore un monde ouvert continu ni une campagne narrative.

## Essayer la scène

Ouvrir [tools/rpg/region_proof.tscn](../tools/rpg/region_proof.tscn) dans Godot, puis **F6**.
La cour et la salle réutilisent les biomes Grotte moussue/Crypte et les escaliers existants,
sans nouveau pixel art. Ce sont des lieux de preuve sans statut canonique, pas Kagari ou Solhar.
Marcher sur l’escalier change de lieu ; une entrée distincte évite un retour immédiat.
Le clavier et la manette utilisent les actions habituelles ; le joystick tactile existant
permet de marcher. Le quatrième lot ajoute Santé et boutons tactiles de combat ; inventaire, quêtes et menu de
sauvegarde restent à intégrer. Les potions posées utilisent le ramassage existant.

Par défaut checkpoint_path est vide : **mémoire uniquement**, sans lecture/écriture de campagne
sur disque par la scène. Le code ne convertit, n’efface et ne sauvegarde ni RunSave ni Profile.
Les autoloads restent ceux du projet. Pour les tests en ligne de commande, employer un dossier
utilisateur isolé comme tools/run_tests.py ; ne pas faire de sonde automatisée sur les fichiers
d’un vrai joueur. Le paramètre de chemin est un outil de développement, pas un choix d’interface.

Un chemin de campagne explicite active les checkpoints avant les changements de lieu. La
reprise lit ce seul emplacement. Une sauvegarde absente crée un prototype ; une erreur ou un
format incompatible bloque le démarrage plutôt que de remplacer le héros. La récupération
de verrou après arrêt et la présentation détaillée des erreurs restent task_360.

## Définir un lieu en données

Le registre est [data/regions/proof/atlas.tres](../data/regions/proof/atlas.tres). Ajouter un lieu
ne demande aucune branche dans Game ou World : créer un RegionDef et l’inscrire dans RegionAtlas.

| Ressource | Contrat |
|---|---|
| RegionAtlas | Régions par id unique, région/entrée de départ ; chaque destination et entrée de lien doit exister. |
| RegionDef | id, display_name traduit, layout_version, biome, tile_size, combat_depth, visual_seed, rows, entries, links, items. |
| rows | Carte fixe : `#` mur, `.` sol, lignes égales et bord fermé ; au plus 128 cellules par côté dans ce prototype. |
| entries | Noms d’entrées → cellules praticables ; distinctes des déclencheurs de sortie. |
| RegionLinkDef | id local, cellule d’escalier, destination et entrée cible explicites. |
| RegionItemDef | id local stable, cellule, ItemDef ; apparition initiale unique. |
| RegionMonsterDef | id local stable, cellule, MonsterDef, rang/affixes optionnels ; apparition unique jusqu’à un renouvellement explicite futur. |
| RegionChestDef | id local stable, cellule, ChestDef et piège explicite ; l’état ouvert est durable. |

La validation vérifie aussi que les entrées, sorties et objets sont accessibles depuis une
entrée. RegionFloorKind produit un DungeonMap de ces données. World utilise son pipeline
commun pour le sol, les murs, NavGrid, l’éclairage et la caméra ; aucune population aléatoire,
malédiction ou récompense de nouvelle profondeur n’est ajoutée par cette classe.

Le stamp est un hash de géométrie, entrées, taille de cellule et objets initiaux. Un lieu déjà
initialisé exige la même layout_version et le même stamp. Modifier les données ne réinitialise
pas silencieusement les objets de ce lieu ; une migration explicite est requise. Les retouches
de textures du biome ne changent pas la géographie. Les régions sont aujourd’hui dans un même
repère local d’origine zéro ; le coordinateur refuse un World transformé.

## Cycle de vie du coordinateur

RegionCoordinator ne se branche pas sur un GameSession avec RunState actif. Il est propriétaire
du flux de cette preuve, avec un World et un héros déjà définis dans sa session. Un seul lieu
est chargé à la fois, de façon synchrone. Ce n’est pas le chargement asynchrone des secteurs R3.2.

1. Résoudre et valider le lien, la destination, son entrée et la compatibilité de disposition.
2. Copier le snapshot, capturer le héros et les objets du lieu actuel, initialiser les apparitions
   de la destination seulement si elle n’a jamais été initialisée.
3. Préparer l’emplacement d’arrivée sûr dans la copie ; conserver Santé, équipement, inventaire,
   monnaie, XP et cooldowns. Aucun gain de passif de début d’étage par ce déplacement.
4. Si un stockage est configuré, publier cette copie personnage/lieux **avant** de décharger
   l’origine. Un échec laisse la carte, le héros et les objets actuels en place.
5. Invalider le ticket régional, déconnecter le suivi d’objets, reconstruire World avec
   RegionFloorKind, garder le même nœud Player et appliquer sa nouvelle position.
6. Annuler chute, dash, poussée et attaque tamponnée de l’ancien lieu ; conserver les statuts
   et le producteur de commandes. Reconnecter les objets restaurés et les nouveaux passages.
7. Émettre region_changed ; l’interface de la preuve ne fait qu’afficher le nom.

Les corps entrant dans un escalier demandent un déplacement différé avec un ticket opaque.
Deux demandes d’un lieu quitté ne peuvent pas se transformer en deux déplacements. L’arrivée
reste hors des déclencheurs ; une position de reprise dans un mur ou une sortie revient à une
entrée sûre. Une disposition incompatible bloque la transition. Le quatrième lot replace un objet ou une
pile dont le saut a fini dans un mur sur le sol proche, en conservant identité et valeur.

Un checkpoint sur place actualise les records sans reconstruire le lieu et sans créer un
second exemplaire des pickups. Quitter la scène ne déclenche pas une écriture automatique :
les points d’autosave/arrière-plan du futur RPG restent à définir et tester.

## Objets persistants (introduits au schéma 2)

RegionState contient maintenant facts, initialized, layout_stamp et objects, en plus de id et
layout_version. RegionObjectState conserve id, position et le résultat exact de LootRoller,
avec base, affixes, runes, rareté et niveau. Aucun objet n’est rerollé au retour.

Les apparitions définies par la région utilisent `authored:<region_id>/<spawn_id>` ; leur portée
reste celle du monde de campagne. Les dépôts dynamiques reçoivent un id objet à 128 bits. Les
identités des objets déjà portés dans l’inventaire ne sont pas encore ajoutées par ce lot.

RegionLoot écoute World.item_created **avant** l’insertion différée, ce qui inclut un dépôt
fait juste avant un passage ou checkpoint. Le ramassage réussi supprime son record ; le manque
de place conserve le pickup. initialized distingue un lieu vidé d’un lieu jamais visité : une
map objects vide n’autorise jamais à remettre ses objets initiaux. Une destruction non suivie
bloque la capture plutôt que d’effacer un objet sans règle.

WorldSpawner vérifie floor_id avant d’insérer un pickup différé. Si le lieu a changé, le nœud
ancien est libéré ; son record reste dans la région quittée et sera recréé à sa revisite. Cela
protège aussi les redémarrages de floors historiques. Les connexions du suivi sont débranchées
avant déchargement ou sortie du coordinateur.

Le troisième lot écrivait **version 2** et lisait la version 1. Le
[quatrième lot](rpg-population.md) écrit v3 et conserve la lecture de v1/v2. La migration ajoute des
ledgers d’objets vides et un état non initialisé aux anciennes régions, en conservant tous leurs
faits. Elle ne réécrit pas le fichier à la lecture ; le prochain commit explicite publie v2.
Une forme v1 contenant des champs non reconnus reste refusée. RunSave v3 et FLOOR_FORMAT 3
sont inchangés : aucune modification de la génération historique ou de ses références.

## Limites et validations à poursuivre

Le scénario A → B → A et le redémarrage passent maintenant par deux cartes réellement chargées.
Le quatrième lot peuple et persiste monstres, coffres et or au sol. Restent PNJ, portes
destructibles, météo, exploration FogOfWar et état des activités ; ces types ne sont pas peuplés
par cette preuve.
Les objets passent par World.spawn_item ; le dépôt d’inventaire existant emprunte ce chemin.
Les autres fabriques ou un ajout direct de pickup devront rejoindre ce contrat avant adoption.

Les coutures de secteurs, transitions sans écran, caméra multi-acteur, multijoueur et pause
partagée restent des lots distincts. Les validations allouent et les checkpoints sont synchrones
aux frontières ; aucun nouveau scan ou tableau par monstre/image. Latence, mémoire, rendu et
ressenti tactile sur S23/Windows restent à mesurer avant activation dans le jeu principal.

unit.regions valide le graphe, la géométrie, les entrées et le codec d’objet. game.regions charge
la scène, prend un objet, traverse, garde le même héros blessé, dépose un objet amélioré avec
affixe/rune, revient, redémarre, éprouve un verrou de sauvegarde et un changement de disposition,
une double demande, un dépôt différé, un vrai passage physique et la migration v1 → v2.

Validation historique du troisième lot sous Godot 4.7 headless, seed 347348 : **19 761 vérifications, 0 échec** ;
16 782 rapides passent. Les nouveaux cas régions totalisent 39 vérifications ; la sélection
régions + campagnes en totalise 102. Linter : 657 scripts, 0 diagnostic ; 7 tests Python,
3 010 clés traduites et catalogue de 303 références valides. Aucun export ni essai visuel ou
tactile sur appareils réalisé. Le contrôle de la scène sur S23/Windows reste task_364.
