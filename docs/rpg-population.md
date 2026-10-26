# RPG : coffres, monstres et récompenses persistants

**Current extension:** [the classic RPG](rpg-classic.md) is the default entry point. It adds
explicit rest renewal for dead common spawns, persistent exploration (CampaignSave v4) and
death recovery without losing character progress. The no-public-mode/rest/death statements
below describe the fourth foundation lot, not the current product.

Quatrième lot de fondations. Il complète la [preuve de régions](rpg-regions.md) et le
[checkpoint commun de campagne](rpg-persistence.md), sans ajouter de mode au menu principal.

## Essayer

La même scène [tools/rpg/region_proof.tscn](../tools/rpg/region_proof.tscn) se lance avec F6.
Les ressources de la cour ajoutent un slime, un squelette et un coffre ; celles de la salle
ajoutent un voleur et un coffre. Les graphismes et comportements sont ceux du jeu existant.
Une ligne de Santé et les boutons tactiles Attaque/Esquive réutilisent les actions normales.
Le clavier et la manette gardent leurs bindings. Les coffres natifs s’ouvrent en s’approchant.

Le chemin de checkpoint reste vide par défaut : mémoire uniquement. Un chemin de test explicite
permet la reprise sur disque. La preuve ne convertit ni ne supprime la partie roguelike, ne
sauvegarde pas Profile et n’étend pas le cloud. La mort du héros reste celle du prototype :
indication de relancer la scène, sans nouveau système RPG de réapparition ou pénalité. Une
capture de héros mort reste refusée ; le mode public de reprise/mort appartient à R4.5 et R8.

## Règles de revisite

| Élément | État repris | Événements jamais rejoués au chargement |
|---|---|---|
| Coffre | id, définition, cellule, ouvert/piégé et fuse restante. | open(), récompenses, statistique d’ouverture et choix de piège. |
| Ennemi vivant | id, définition, position, Santé absolue, rang, affixes, summoned/dormant, mémoire durable. | Nouveau tirage de rang, récompense ou kill. La Santé est limitée au maximum courant si le contenu a changé. |
| Ennemi initial vaincu | Tombstone conservée pour son id d’apparition. | die(), XP, butin, or, rejetons et effets de mort. |
| Ennemi dynamique vaincu | Retiré des records : aucune apparition initiale ne peut le recréer. | Aucun historique illimité de minions morts ; les minions vivants restent sauvegardés. |
| Objet au sol | Identité et données LootRoller exactes. | Tirage d’objet/rareté/affixes/runes. |
| Or au sol | Identité, position et montant déjà calculé par FloorRules. | Multiplicateur de profondeur/difficulté et nouveau découpage en piles. |
| Vol d’or | Montant porté par le voleur et temps de fuite restant. | Remboursement ou disparition de l’or au simple retour. |

**Aucun respawn à la revisite**, au chargement ou à l’heure civile. Le renouvellement des
monstres communs via un repos explicite reste à concevoir avec R0.2/R4.5 ; ce lot n’active pas
un timer de respawn caché. Une récompense déjà produite est représentée soit chez le héros,
soit parmi les objets/piles au sol, dans le même checkpoint que la mort ou l’ouverture.

Les cibles, windups d’IA, états temporaires comme brûlure/gel et certains timers de combat
repartent au chargement. Ils ne constituent pas encore une simulation continue des régions
inactives. Les valeurs durables passent par les hooks de module ci-dessous ; les dégâts
retardés et activités devront rejoindre un contrat de cycle de vie avant leur ajout au monde.

## Données et composants

RegionMonsterDef et RegionChestDef sont des ressources référencées par RegionDef.monsters et
RegionDef.chests. Les ids d’apparition sont stables, indépendants de leur ordre :
`monster:<region_id>/<spawn_id>` et `chest:<region_id>/<spawn_id>`. Les apparitions dynamiques
reçoivent des ids à 128 bits. La validation vérifie références, rangs/affixes, sol praticable,
approche des coffres et passages accessibles **avec les cellules de coffres bloquées**.

Le stamp de géométrie existant reste inchangé. Un stamp de population distinct couvre les
apparitions et leur combat_depth. Une région v2 déjà visitée peut ainsi adopter sa première
population sans remettre les potions ramassées ni changer sa carte. Une population initialisée
exige ensuite le même stamp ; modifier des apparitions demande une migration explicite.

RegionPopulation suit les créations de monstres et coffres et leurs signaux de mort/ouverture.
Il capture les valeurs vivantes avant chaque checkpoint, garde les tombstones initiales et
restaure sans appeler les actions qui distribuent les récompenses. L’initialisation hors arbre
emploie Monster.setup/make_ranked et FloorRules : aucun second calcul de difficulté ou de Santé.
Les boss à phases sont refusés par ce premier codec plutôt que restaurés dans un état faux.

RegionLoot suit maintenant aussi les piles d’or. Les fabriques annoncent les pickups avant
insertion différée ; même une récompense créée juste avant un départ fait partie de la capture.
Collecter une pile la retire du ledger. GoldPickup.take et ItemPickup.take refusent les transferts
réentrants/déjà effectués. Une position de saut dans un mur est replacée sur le sol le plus
proche, sans changer l’objet ou le montant ; les changements de géométrie restent refusés.
L’arrivée du héros évite aussi corps d’ennemis et coffres, sans déplacer ceux-ci ni soigner le héros.

Les connexions sont retirées avant déchargement et à la fermeture. Aucun scan des monstres ou
des pickups n’est ajouté à une boucle par image : le suivi vient des fabriques et signaux,
les validations/copies étant réservées aux frontières et checkpoints.

## Mémoire durable des comportements

MonsterTrait fournit persistent_data, accepts_persistent_data et restore_persistent_data.
Par défaut le module n’a pas d’état durable et n’accepte qu’un dictionnaire vide. ThiefTrait
implémente ce contrat pour stolen et flee. Ajouter un comportement portant des valeurs durables
exige son implémentation dans le module, sans branche par type dans Monster ou le coordinateur.

MonsterTraits conserve les records dans l’ordre de la composition native + affixes, avec le
nom global de classe de chaque module. Changement de type, d’ordre ou de forme non accepté :
refus de lecture, jamais application des compteurs d’un module à un autre. Ces noms/contrats
font désormais partie du schéma ; un renommage ou réordonnancement demande une migration.

PerkSet.persistent_memory conserve la mémoire durable des perks par leur id local, dans la
portée de cette composition. Les clés commençant par `_` restent transitoires comme dans le
format existant. MonsterTrait.granted_perks permet de valider les ids sans créer un acteur
vivant ; PerkTrait le fournit. Les perks d’affixes peuvent être des sous-ressources : elles ne
sont pas faussement enregistrées comme des objets indépendants dans le catalogue. Un compteur
limité, par exemple `used`, ne se recharge donc pas simplement en changeant de région.

## Frontière de récompense et apparitions différées

Les notifications natives peuvent arriver au milieu d’un transfert. Par exemple, opened est
émis avant la distribution du coffre ; gold_changed précède le retrait de la pile. Capturer
à cet instant pouvait garder la récompense chez le héros et aussi sa source au sol.

WorldSpawner porte un compteur de traitements synchrones et de batches d’apparitions en attente.
Actor.die, Chest.open/explosion et les transferts item/or entourent leurs opérations. Le
coordinateur refuse un checkpoint tant que is_settled est faux, et pendant son activation.
Une requête de passage attend un process_frame puis revérifie son ticket avant de réessayer.
Une reprise de paiement n’est donc pas déduite d’un simple signal émis avant la fin de l’action.

Les rejetons de DeathSpawnTrait et les monstres des coffres piégés utilisent un SpawnBatch typé :
génération de floor, définitions, position, rayon et cible faible. Le batch termine avant un
départ régional normal. Un remplacement forcé de floor historique invalide le batch, qui ne
peut plus déposer ses monstres ailleurs ni lire une cible libérée. Le stockage ne sérialise
pas un batch partiellement appliqué : il attend sa résolution. Les invocations synchrones
passent déjà par la fabrique suivie, avec leur flag summoned recapturé après application.

Une fuse de coffre suspendue reprend son temps restant. Une fuse terminée est normalisée à
-1 avant l’explosion ; le checkpoint suivant reste valide et la reprise ne réarme pas le piège.
Les effets visuels et les cadavres animés ne sont pas des identités persistantes.

## Schéma 3 et compatibilité

CampaignSave écrit la version 3 et lit toujours 1 et 2. La migration ajoute aux régions :

- population_initialized et population_stamp ;
- maps monsters, chests et gold, initialement vides.

Une v1 reçoit d’abord les champs d’objets v2. Une v2 conserve géométrie, objets, héros et faits,
puis reçoit une population non initialisée. C’est le coordinateur qui l’initialise avec les
données actuelles ; la simple lecture ne modifie ni fichier ni état du monde actif. Les formes
non reconnues et les références manquantes restent refusées entières. Le fichier précédent
reste récupérable selon les garanties et limites du [backend](rpg-persistence.md).

ContentCatalog ajoute 18 références stables : coffres, rangs et affixes de monstres, pour un total
de 321. Les 303 références antérieures et tous leurs alias restent conservés. RunSave.VERSION 3,
FLOOR_FORMAT 3, la génération du roguelike et sa politique de mort ne changent pas.

## Validation et limites

unit.region_population valide les records, références, mémoire inconnue, tombstones, formes de
piège et impossibilité de bloquer l’unique passage avec un coffre. game.region_population
emploie les vrais chemins de dégâts, mort, coffre et ramassage ; seule l’IA est désactivée dans
les assertions pour isoler la persistance du timing de combat.

La scène vérifie blessures et ennemis vaincus après A/B/A et redémarrage, coffre sans seconde
récompense, richesse totale, compteur de perk d’affixe, or volé, rejetons natifs, snapshots
réentrants refusés, piège en cours/terminé et migration v2 non destructive. Les suites régionales
v1 → schéma courant et les suites du jeu historique restent requises.

Les mesures visuelles/tactiles, coûts de capture et intégration sur S23/Windows restent à faire.
Les checkpoints restent synchrones et bornés à 16 MiB ; ce n’est pas une validation de streaming
à 60 fps. Restent PNJ, portes/obstacles, FogOfWar, activités, boss à phases, repos/respawn explicite,
identités d’inventaire, mort RPG et reprise publique avec gestion des erreurs/verrous.

Validation Godot 4.7 headless, seed 347348 : **19 845 vérifications, 0 échec**. Les nouveaux
cas totalisent 49 vérifications ; les rapides 16 812, sans échec. Linter : 664 scripts,
0 diagnostic ; les 7 tests Python, 3 012 clés traduites et catalogue de 321 références
passent. Aucun export ni essai visuel/tactile sur appareils effectué ; task_368 suit cet essai.
