# Roadmap : RPG en monde ouvert, puis multijoueur

**Date : 26 octobre 2026. Base examinée : `308e410`.**

Le jeu livré par le code actuel reste un roguelike d’action. Ce document planifie sa
transformation ; il ne décrit pas des fonctionnalités déjà réalisées. La cible demandée est
un **RPG en monde ouvert**, avec un **RPG multijoueur ultérieur**. Godot 4.7, GDScript typé,
Compatibility, Android Samsung S23 et Windows restent les contraintes de départ.

La [roadmap Godoban](../godoban_boards/puits_roadmap.json) reste la liste de travail. Ce document
explique les choix, l’ordre et les critères ; les cartes portent leur état. Une case en backlog
n’est ni une fonctionnalité existante ni une promesse de date. Les valeurs de progression,
la taille du monde et le nombre de joueurs seront fixés par décisions et mesures.

## Mise en route — premier lot technique

Le [contrat du premier prototype](rpg-foundation-contract.md) précise les hypothèses proposées
pour R0 et ce qui est effectivement implémenté : producteurs de commandes indépendants,
contexte runtime GameSession et protection des continuations/fondus après redémarrage.
La carte task_356 suit ce lot. R0.1/R0.2 sont en revue ; R0.3/R0.4 et R1.1/R1.2/R1.3 restent
partielles, avec les schémas durables, identités persistantes et autres commandes encore à
réaliser. La preuve à deux acteurs ne vaut pas validation de R1.6 ni ajout de multijoueur.

## Deuxième lot — état durable et sauvegarde cohérente

Le [contrat de persistance](rpg-persistence.md) décrit les records personnage/monde/régions,
les identités durables et le checkpoint commun avec révision, backup validé et refus des
conflits. La carte task_359 suit ce lot. R1.1/R1.2/R2.1/R2.2 restent partiels ; les faits de
région ne sont pas encore des cartes persistantes et aucun mode RPG n’est ajouté au menu.

## Ce qui est décidé et ce qui doit l’être

**Demandé :** monde ouvert, évolution durable du jeu vers le RPG, préparation d’un multijoueur
plus tard. **Livrable de planification initiale :** roadmap, inventaire des transformations et cartes de
réalisation. Aucune conversion du gameplay, migration de sauvegarde ou infrastructure déployée.

**Hypothèses proposées pour travailler, à valider en R0 :**

- D’abord une région ouverte, un lieu sûr et deux donjons pour prouver toute la boucle.
- Campagne solo hors ligne d’abord ; préserver ce mode après l’arrivée éventuelle du réseau.
- Coopération à petite échelle avant un monde partagé permanent. Un essai à deux joueurs est
  une preuve technique, pas un choix définitif de capacité.
- Le Puits demeure un lieu central ; la place de Kagari, des âmes et des fins respecte un canon
  adapté explicitement. Une forêt et un village vivants ne sont pas ajoutés sans examiner le lore.
- Géographie du monde reconnaissable ; réemploi de la génération pour les donjons où elle sert.
  Un monde ouvert n’exige ni une seule scène immense ni une simulation de toute la carte.

**À trancher avant de figer les données :** politique de mort, checkpoints et réapparition ;
respawn et renouvellement des donjons ; talents ou classes ; nombre de personnages ; portée
personnelle/partagée des quêtes et du monde ; devenir de l’ancienne descente ; économie solo et
admission future en ligne ; type d’hébergement, nombre de joueurs et budget. Les classes,
PvP, guildes, marché, logement, métiers approfondis et MMO ne sont pas implicitement décidés.

## Les trois jalons jouables

| Jalon | Ce que le joueur doit pouvoir faire | Condition de passage |
|---|---|---|
| **J1 — Tranche RPG** | Créer/reprendre un personnage, explorer une région continue, accomplir une chaîne de quêtes, parcourir deux donjons, commercer, mourir et revenir. | Revisite et reprise après arrêt conservent les faits ; performance mesurée sur les exports ; aucun reset ou paiement involontaire. |
| **J2 — RPG solo livrable** | Jouer une campagne étendue par lots, avec progression durable, journal, carte, équilibrage et synchronisation solo explicitement définie. | Tests, migrations, traductions, essais S23/Windows et politique de données cohérents avec le produit. |
| **J3 — Première coopération** | Deux clients de preuve, puis la taille de groupe décidée, jouent avec une autorité de simulation, progression et récompenses correctement possédées. | Latence, concurrence, déconnexion et restauration testées ; capacité et coûts mesurés avant extension. |

Les phases peuvent avancer en partie en parallèle après leurs dépendances. Le multijoueur
n’est pas « un bouton à ajouter à la fin » : R1 prépare commandes, propriétaires, temps et
plusieurs acteurs. Le travail de connexion réseau commence en M0 après la preuve de la boucle
solo ; il peut se faire avant d’étendre la campagne à de nombreuses régions (R9.4).

## Conserver, transformer, créer

| Domaine | État constaté et points de départ | Travail pour le RPG et le réseau futur |
|---|---|---|
| Combat, armes, compétences, statuts | [Actor](../src/entities/actor.gd), [Combat](../src/combat/combat.gd), Effect, Passive et ressources de contenu. | Réutiliser comportements et définitions ; séparer commandes, autorité et présentation ; requalifier chiffres et attribution. |
| Monstres et affixes | [Monster](../src/entities/monster/monster.gd), MonsterTraits, EliteAffixDef, IA et écartement. | Réutiliser ; ajouter population régionale, retour à l’origine, respawn choisi et cibles multiples. Les non-collisions entre monstres et la cadence IA volontaire restent des décisions valides. |
| Déroulement | [Game](../src/game/game.gd), [RunState](../src/game/run_state.gd), transitions par profondeur. | Séparer session, personnage, monde et contexte d’expédition ; la fin d’un donjon ne termine pas un personnage. |
| Monde | [World](../src/world/world.gd) possède carte et état de l’étage courant. | Ajouter carte de régions, secteurs, liens, cycle de chargement et états de lieux revisités ; conserver World comme façade lorsque c’est utile. |
| Génération | DungeonGenerator, FloorKind, biomes, salles et scènes en données. | Réemployer pour des donjons et l’assemblage adapté ; ne pas remplacer une géographie permanente à chaque retour. |
| Sauvegarde | [RunSave](../src/game/run_save.gd) v3/FLOOR_FORMAT 3 et [FloorSave](../src/world/floor_save.gd) ; ids de contenu, SafeFile, validation. | Réutiliser robustesse et références ; créer schémas personnage/monde, régions multiples et commit cohérent. Le modèle de régénération d’étage ne suffit plus. |
| Profil et progression | [Profile](../src/autoload/profile.gd), arbre d’âmes, serments, records et historique de runs. | Décider portée compte/personnage/monde, conversion et avenir des âmes ; garder traces anciennes et préférences. |
| Équipement et inventaire | Instances roulées, rareté, niveau lié à la profondeur, runes et ceinture. | Ajouter identité des instances et transactions ; établir niveau/qualité par contexte RPG plutôt que profondeur seule. |
| Difficulté et butin | [FloorRules](../src/world/floor_rules.gd), [LootRoller](../src/definitions/loot/loot_roller.gd). | Une autorité de règles de région/donjon remplace les calculs dépendants de la descente ; ni multiplication sauvage ni level scaling décidé implicitement. |
| Mort, Seuil et Tréfonds | La boucle et les récompenses sont liées à la descente et à ses fins. | Règles RPG explicites, réapparition, coût, états morts/transitions et reprise ; lore conservé ou adapté consciemment. |
| Quêtes | [QuestDef](../src/definitions/quest_def.gd) est quotidien/hebdomadaire, [QuestBoard](../src/game/quest_board.gd) compte des statistiques de profil. | Créer quêtes narratives, branches, objectifs, objets, faits et récompenses idempotentes ; les compteurs périodiques ne suffisent pas. |
| Narration et PNJ | Dialogues et conditions en données ; [Narrative](../src/game/story/narrative.gd) écrit actuellement dans Profile. | Réutiliser conditions/contenu ; attribuer faits de campagne, rendre PNJ et services persistants, préparer narration personnelle ou partagée. |
| Commerce et forge | Marchand, stock, vente, démantèlement et sertissage. | Contrats d’inventaire, renouvellement et prix durables ; alchimie/banque/échanges seulement si retenus. |
| Interface et exploration | HUD, minimap locale, sac, panneaux, traductions et commandes communes. | Carte région/monde, journal, sélection de personnage, exploration persistante, voyage rapide si choisi et menus locaux futurs. |
| Temps | [Game._set_paused](../src/game/game.gd) utilise la pause globale ; [HitStop](../src/autoload/hit_stop.gd) change Engine.time_scale. | Séparer pause solo et présentation locale de la simulation partagée. Ouvrir son sac ne doit pas stopper les autres. |
| Activité et caméra | [ActivityManager](../src/world/activity_manager.gd) s’appuie sur World.player et la vue ; [WorldSpace](../src/world/world_space.gd) garde une vue locale. | Préparer ensemble des acteurs/joueurs et zones utiles ; le serveur sans caméra doit simuler correctement. |
| Compte et cloud | Compte Talo distinct de l’appareil, session unique ; [CloudSave](../src/autoload/cloud_save.gd) synchronise le profil, jamais la partie courante. | Préserver ces choix ; concevoir synchronisation de personnages/régions et identité de jeu serveur. Le verrou in_run doit évoluer pour une campagne longue. |
| Services en ligne | REST maison : scores, consentement, télémétrie, présence, configuration et feedback. | Talo/presence actuels ne fournissent pas la simulation autoritaire RPG. Réévaluer événements, finalités et champs publics/privés. |
| Tests et outils | Suites, lint, traduction, catalogues, bots de combat et sonde perf. | Garder les contrôles utiles et données historiques ; ajouter visites multiples, transactions, migrations, streaming et tests multi-processus. |
| Art et son | Pack existant, biomes, équipements modulaires, VFX et ambiances. | Inventorier avant de produire ; identifier les vrais manques du monde extérieur et les budgets mémoire. Le RPG ne résout pas à lui seul le travail d’art. |

## Contrats à établir tôt

### Identité et propriété

| Identité proposée | Exemple conceptuel | Propriétaire de l’état |
|---|---|---|
| Définition de contenu | item:katana, monster:rat | Catalogue immuable partagé ; conserver les ids publiés. |
| Instance d’objet ou pile | Une arme avec ses runes et son état | Personnage, coffre ou sol ; un seul propriétaire validé à la fois. |
| Personnage | Héros d’un emplacement de sauvegarde | Joueur local en solo ; autorité de session/serveur pour l’état partagé. |
| Monde et lieu | Monde, région/secteur, instance de donjon | Sauvegarde locale ou autorité du monde, selon le mode décidé. |
| Apparition et fait persistant | Coffre ouvert, obstacle résolu, PNJ sauvé | Fait de monde ou droit personnel explicitement choisi. |
| Entité réseau et contexte | Entité de simulation, époque/génération de zone | Session de simulation ; distinct de l’identité durable. |
| Connexion et compte | Peer temporaire et identité authentifiée | Service d’authentification/session ; jamais équivalents par simple numéro de peer. |

Les noms et schémas nouveaux sont des propositions. Un id de Resource n’identifie pas chaque
copie d’une arme. Un id de nœud Godot, RID ou NodePath n’est pas une clé durable ou un protocole
portable. Les ressources restent immuables ; états mutables par propriétaire.

### Persistance et chargement

- Définir état permanent, état renouvelable et état de combat temporaire. Écrire les deltas utiles,
  pas toutes les positions à chaque image. Une région déchargée n’est pas un monde oublié.
- Coordonnées, graine, version du générateur et modifications doivent permettre une reprise
  contrôlée. Pour une région durable, un changement de version ne peut pas simplement jeter
  les faits comme le stamp d’un ancien étage.
- Équiper, acheter, fabriquer, ramasser et rendre une quête doivent produire un commit cohérent.
  SafeFile par fichier est une base ; un ensemble de fichiers exige manifeste, génération ou
  journal, et tests de coupure. Le procédé précis sera choisi en R2.
- Sauvegarder avant déchargement, annuler les travaux tardifs et reprendre correctement sur un
  point sûr après échec. Le contexte d’annulation est par zone/instance : ne pas invalider les
  effets d’une autre région en incrémentant un compteur global à chaque secteur déchargé.
- Préchargement en arrière-plan et ajout à l’arbre de scène sont des opérations différentes.
  Contrôler l’état du chargement avant récupération, intégrer au bon thread et borner le travail
  par image ; les APIs Godot documentées ne garantissent pas un streaming fluide automatiquement.

### Préparation réseau et confiance

- Chemin cible : commande du joueur → validation par l’autorité → modification de l’état →
  événements de simulation → présentation locale. En solo, l’autorité peut être locale.
- Répliquer les ids et données autorisées, pas des Resources/objets entiers ; filtrer par intérêt
  spatial et droits d’accès. Les outils Godot de réplication sont des candidats, pas un protocole
  d’inventaire ou une protection contre les commandes invalides.
- Une autorité sur l’ordinateur d’un hôte suffit pour un certain modèle de coopération privée,
  mais cet hôte n’est pas une preuve de richesse fiable pour une économie officielle.
- Un personnage hors ligne reste modifiable. La décision d’import dans une partie privée est
  différente de son admission à des échanges/classements officiels ; prévoir des espaces de
  progression séparés ou une politique d’import explicitement limitée.
- Le client ne décide pas de son loot, d’un prix ou d’une récompense de quête. Tickets de session,
  secrets et inventaires privés ne passent ni dans les props publics Talo ni dans les logs bruts.
- Pas de déterminisme physique entre Android/Windows supposé : la graine de génération ne suffit
  pas à synchroniser les combats. Tester prédiction/interpolation et réconciliation avec une
  autorité plutôt que promettre du lockstep sans preuve.
- Prévoir jeu en arrière-plan sur Android, reconnexion, timeout et arrêt contrôlé de l’hôte.
  La migration d’hôte, le monde permanent et l’architecture distribuée sont des lots distincts.

## Lecture des phases

13 phases, **64 cartes de réalisation**. Les références R0.1, M0.2, etc. sont des repères de ce
document ; chaque ligne ci-dessous les relie à un id Godoban stable. Les dépendances nomment les
prérequis techniques. Les validations de choix produit restent requises là où elles figurent.

| Phase | Résultat de sortie | Portée |
|---|---|---|
| R0 — Cadrage du RPG | Un contrat produit tranche les choix qui changent les sauvegardes, le monde et les règles réseau. | RPG solo et préparation. |
| R1 — Socle de session et préparation multijoueur | Deux acteurs pilotables dans une simulation de test, avec état et présentation correctement séparés, sans réseau requis. | RPG solo et préparation. |
| R2 — Persistance durable et migration | Personnage et plusieurs zones survivent à un arrêt brutal, avec transactions cohérentes et migration contrôlée. | RPG solo et préparation. |
| R3 — Monde ouvert et chargement par secteurs | Traverser plusieurs secteurs aller-retour est continu, sauvegardé et mesuré sur les appareils cibles. | RPG solo et préparation. |
| R4 — Personnage, combat et progression RPG | Le personnage évolue durablement, les zones revisitées restent cohérentes et la mort suit le contrat décidé. | RPG solo et préparation. |
| R5 — Quêtes, PNJ et narration persistante | Une chaîne de quête modifie réellement le monde et se reprend à chaque étape sans payer deux fois. | RPG solo et préparation. |
| R6 — Inventaire, économie et services | Des heures de jeu et des cycles d’achat/fabrication ne produisent ni duplication ni inflation hors des règles. | RPG solo et préparation. |
| R7 — Régions, contenu et identité du Puits | La première région raconte et fait jouer une boucle RPG complète avec un budget d’assets connu. | RPG solo et préparation. |
| R8 — Interface, outils et performances | La boucle tient sur les exports S23/Windows, avec interface et chargement adaptés à une longue session. | RPG solo et préparation. |
| R9 — Validation et livraison du RPG solo | Une région et deux donjons forment une tranche complète jouable ; la campagne s’étend ensuite avec les mêmes contrats. | RPG solo et préparation. |
| M0 — Preuve multijoueur autoritaire | Deux clients jouent un scénario commun avec une autorité indépendante et des commandes validées. | Multijoueur ultérieur. |
| M1 — Coopération jouable et persistance en ligne | La campagne retenue se joue à plusieurs avec progression, propriété des récompenses et restauration cohérentes. | Multijoueur ultérieur. |
| M2 — Exploitation et extension multijoueur | Une version hébergée possède sauvegarde/restauration, supervision et limites mesurées ; un monde partagé plus vaste reste une décision distincte. | Multijoueur ultérieur. |

## Cartes détaillées

### R0 — Cadrage du RPG

**Epic Godoban : epic_279. Critère de sortie :** Un contrat produit tranche les choix qui changent les sauvegardes, le monde et les règles réseau.

#### R0.1 · task_292 — Définir le périmètre du RPG et la première région

**Dépendances :** Cadrage demandé ; pas de prérequis technique.

**À réaliser :** Fixer la boucle explorer → combattre → accomplir une quête → améliorer le personnage ; préciser étendue, donjons, intérieur/extérieur, solo hors ligne et priorités. La cible initiale proposée est une région, un lieu sûr et deux donjons ; classes, artisanat et taille du futur groupe restent des choix.

**Fini quand :** Un document de périmètre accepté distingue minimum jouable, extension et hors périmètre ; aucun MMO ni multijoueur massif promis.

**Points de départ :** [README.md](../README.md), [docs/lore.md](../docs/lore.md).

#### R0.2 · task_293 — Décider mort, réapparition et renouvellement du monde

**Dépendances :** R0.1 (task_292)

**À réaliser :** Choisir coût de mort, lieu sûr, récupération éventuelle, permanence des boss, respawn des monstres/ressources et réinitialisation des donjons. Distinguer temps de jeu, temps hors ligne et temps serveur futur.

**Fini quand :** Chaque type d’entité a une politique de persistance et de renouvellement ; mourir, quitter ou changer l’horloge ne crée pas une ferme de récompenses.

**Points de départ :** [src/game/game.gd](../src/game/game.gd), [src/world/floor_save.gd](../src/world/floor_save.gd).

#### R0.3 · task_294 — Définir propriété du personnage, du monde et du futur groupe

**Dépendances :** R0.1 (task_292)

**À réaliser :** Décider nombre de personnages/mondes, progression personnelle ou partagée, hôte ou serveur, départ d’un joueur, reprise à plusieurs et cible de joueurs simultanés. Hypothèse à valider : petite coopération avant monde partagé permanent.

**Fini quand :** Table de propriété et règles d’import/export : héros solo modifiable non importable comme richesse fiable dans une économie en ligne officielle ; autorité et limites d’un hôte particulier explicites.

**Points de départ :** [src/autoload/account.gd](../src/autoload/account.gd), [src/autoload/cloud_save.gd](../src/autoload/cloud_save.gd), [docs/online.md](../docs/online.md).

#### R0.4 · task_295 — Établir le canon de surface et le devenir du roguelike

**Dépendances :** R0.1 (task_292)

**À réaliser :** Adapter Kagari, sanctuaire, âmes endormies, régions de surface et révélations à un monde ouvert. Décider si l’ancienne descente reste un mode séparé, devient un donjon ou est conservée seulement comme version précédente ; traiter fins, Seuil, Tréfonds et Gardien Sans Nom. Trier tout l’ancien backlog entre prérequis transversal, adaptation RPG, ancien mode à conserver et idée reportée ; conserver les correctifs et l’historique.

**Fini quand :** Carte narrative sans spoiler prématuré ; décision explicite sur mode historique, succès et classements ; aucune suppression d’anciens ids ou fichiers de joueur.

**Points de départ :** [docs/lore.md](../docs/lore.md), [docs/design/progression.md](../docs/design/progression.md), [src/game/daily_run.gd](../src/game/daily_run.gd).

### R1 — Socle de session et préparation multijoueur

**Epic Godoban : epic_280. Critère de sortie :** Deux acteurs pilotables dans une simulation de test, avec état et présentation correctement séparés, sans réseau requis.

#### R1.1 · task_296 — Séparer session, personnage, monde et expédition

**Dépendances :** R0.2 (task_293), R0.3 (task_294)

**À réaliser :** Faire évoluer Game/RunState vers des propriétaires explicites : session active, état du personnage, état du monde, contexte d’un donjon. Garder les façades existantes tant qu’elles servent ; ne pas faire grossir Game/World ni déplacer tous les fichiers.

**Fini quand :** Quitter un donjon ou mourir ne recrée pas le personnage ; le mode historique reste testable si retenu. Les nouveaux noms/classes sont proposés, pas déjà implémentés.

**Points de départ :** [src/game/game.gd](../src/game/game.gd), [src/game/run_state.gd](../src/game/run_state.gd), [src/world/world.gd](../src/world/world.gd).

#### R1.2 · task_297 — Définir les identifiants stables et les contextes d’exécution

**Dépendances :** R1.1 (task_296)

**À réaliser :** Distinguer id de définition, instance d’objet, personnage, monde, région/secteur, apparition persistante et entité de simulation ; ajouter révision et génération de contexte aux effets différés.

**Fini quand :** Un objet conserve son identité entre chargements ; un effet de région déchargée ne touche pas la nouvelle génération. Aucun NodePath, RID ou get_instance_id persisté comme identité durable.

**Points de départ :** [src/game/content_catalog.gd](../src/game/content_catalog.gd), [src/definitions/loot/loot_roller.gd](../src/definitions/loot/loot_roller.gd), [src/combat/ground_strike.gd](../src/combat/ground_strike.gd).

#### R1.3 · task_298 — Faire passer les actions par des commandes validées

**Dépendances :** R1.1 (task_296), R1.2 (task_297)

**À réaliser :** Séparer lecture Input, intention de déplacement/attaque/compétence/objet et application des règles. Le solo applique localement le même contrat que pourra appliquer une autorité distante ; validation portée, coût et état.

**Fini quand :** Deux contrôleurs de test dirigent deux héros sans partager les touches ; l’UI ne fabrique ni dégâts ni récompenses ; les triches de debug restent identifiées.

**Points de départ :** [src/entities/player/player_controls.gd](../src/entities/player/player_controls.gd), [src/entities/player/player.gd](../src/entities/player/player.gd), [src/combat/combat.gd](../src/combat/combat.gd).

#### R1.4 · task_299 — Remplacer les dépendances au joueur et à la caméra uniques

**Dépendances :** R1.1 (task_296), R1.2 (task_297)

**À réaliser :** Rendre explicites acteur concerné, contrôleur local, équipe et zone. Examiner World.player, AI, interactor, boss, bestiaire, drops et Events ; conserver les tests de type légitimes au lieu de les remplacer par des appels dynamiques.

**Fini quand :** Scénario à deux acteurs : cibles, XP, interactions, HUD, quêtes et récompenses vont au bon propriétaire ; aucune caméra ne décide de l’activité de simulation serveur.

**Points de départ :** [src/world/world.gd](../src/world/world.gd), [src/world/activity_manager.gd](../src/world/activity_manager.gd), [src/entities/monster/monster.gd](../src/entities/monster/monster.gd), [src/game/bestiary.gd](../src/game/bestiary.gd).

#### R1.5 · task_300 — Isoler temps de simulation, pause et présentation

**Dépendances :** R1.3 (task_298), R1.4 (task_299)

**À réaliser :** Séparer menus/cinématiques/HitStop du temps partagé ; définir horloge gameplay, horloge de persistance et temps réel. Émettre les effets visuels/sonores par un chemin désactivable en simulation headless.

**Fini quand :** En test à deux héros, ouvrir un sac ou jouer un retour visuel local ne fige pas l’autre. En solo la pause prévue reste possible. Aucun feedback ne modifie dégâts, cooldowns ou RNG.

**Points de départ :** [src/game/game.gd](../src/game/game.gd), [src/autoload/hit_stop.gd](../src/autoload/hit_stop.gd), [src/game/story/cinematic_director.gd](../src/game/story/cinematic_director.gd).

#### R1.6 · task_301 — Prouver le socle avec deux acteurs sans réseau

**Dépendances :** R1.3 (task_298), R1.4 (task_299), R1.5 (task_300)

**À réaliser :** Ajouter une scène de preuve locale avec deux sources de commandes et une simulation sans interface ; faire combattre, interagir, mourir et changer de zone.

**Fini quand :** Isolation des contrôleurs/états démontrée, résultat de simulation indépendant de l’affichage ; défauts bloquants corrigés avant le développement massif du monde.

**Points de départ :** [tests/suites/](../tests/suites/), [tools/](../tools/).

### R2 — Persistance durable et migration

**Epic Godoban : epic_281. Critère de sortie :** Personnage et plusieurs zones survivent à un arrêt brutal, avec transactions cohérentes et migration contrôlée.

#### R2.1 · task_302 — Définir les schémas compte, personnage et monde

**Dépendances :** R1.1 (task_296), R1.2 (task_297), R0.3 (task_294)

**À réaliser :** Séparer préférences/profil de compte, progression d’un personnage, faits du monde et instances de donjon. Définir versions de schéma, version du contenu, ids, révisions et propriété de chaque champ.

**Fini quand :** Inventaire de champs validé ; les réglages privés ne deviennent pas des données publiques ; un même coffre peut distinguer état du monde et droit individuel.

**Points de départ :** [src/autoload/profile.gd](../src/autoload/profile.gd), [src/game/run_save.gd](../src/game/run_save.gd), [src/world/floor_save.gd](../src/world/floor_save.gd).

#### R2.2 · task_303 — Garantir les écritures et transactions multi-états

**Dépendances :** R2.1 (task_302)

**À réaliser :** Réutiliser SafeFile et validation typée ; concevoir commit de génération/manifeste ou journal pour que personnage, inventaire, récompense et région soient cohérents. Une écriture atomique par fichier seule ne constitue pas un commit global.

**Fini quand :** Coupure simulée à chaque étape : reprise sur une génération complète, aucune monnaie/quête payée deux fois, ancien état récupérable et erreurs visibles.

**Points de départ :** [src/core/safe_file.gd](../src/core/safe_file.gd), [src/game/run_save.gd](../src/game/run_save.gd), [tests/suites/](../tests/suites/).

#### R2.3 · task_304 — Persister les régions et les objets qui y restent

**Dépendances :** R2.1 (task_302), R2.2 (task_303)

**À réaliser :** Étendre le modèle de FloorSave à plusieurs régions : ouvertures, obstacles, PNJ, ressources, monstres selon politique, butin dynamique, objets posés, vagues et instances. Écrire les changements avant déchargement.

**Fini quand :** Revisiter A après B puis redémarrer conserve les faits décidés ; aucun reset involontaire de coffres ou butin ; taille des fichiers et nettoyage des états sont bornés.

**Points de départ :** [src/world/floor_save.gd](../src/world/floor_save.gd), [src/world/floor_ledger.gd](../src/world/floor_ledger.gd), [src/world/secret_room.gd](../src/world/secret_room.gd).

#### R2.4 · task_305 — Migrer les profils et sauvegardes du roguelike

**Dépendances :** R2.1 (task_302), R2.2 (task_303), R0.4 (task_295)

**À réaliser :** Créer un import versionné conservant sauvegardes originales ; décider conversion ou archivage de la partie en cours, âmes, arbre, serments, chroniques et équipement. Proposer une table de compensation seulement après décision produit.

**Fini quand :** Fixtures anciennes, partielles, corrompues et plus récentes traitées ; import idempotent sans perte silencieuse. Une mise à jour ne régénère plus un monde durable par simple changement du stamp d’étage.

**Points de départ :** [src/game/run_save.gd](../src/game/run_save.gd), [src/autoload/profile.gd](../src/autoload/profile.gd), [data/save/content_catalog.tres](../data/save/content_catalog.tres).

#### R2.5 · task_306 — Définir la synchronisation solo et les conflits multi-appareils

**Dépendances :** R2.1 (task_302), R2.2 (task_303), R2.4 (task_305)

**À réaliser :** CloudSave actuel synchronise le profil, pas le personnage en cours ni ses régions. Prévoir lots cohérents, révisions, taille, reprises interrompues, suppression et deux appareils concurrents ; garder identité compte/appareil séparée. Remplacer le blocage in_run par des points de synchronisation cohérents : une campagne durable ne peut pas attendre indéfiniment une fin de descente.

**Fini quand :** Téléphone et PC produisent un conflit explicite plutôt qu’une fusion d’inventaires ou un écrasement aveugle ; aucune extension du périmètre de collecte sans choix adapté.

**Points de départ :** [src/autoload/cloud_save.gd](../src/autoload/cloud_save.gd), [src/autoload/account.gd](../src/autoload/account.gd), [docs/privacy-ops.md](../docs/privacy-ops.md).

### R3 — Monde ouvert et chargement par secteurs

**Epic Godoban : epic_282. Critère de sortie :** Traverser plusieurs secteurs aller-retour est continu, sauvegardé et mesuré sur les appareils cibles.

#### R3.1 · task_307 — Créer le modèle de carte et l’outil d’assemblage des régions

**Dépendances :** R0.4 (task_295), R1.2 (task_297), R2.1 (task_302)

**À réaliser :** Définir régions, secteurs, routes, points remarquables, entrées de bâtiments et liens vers donjons ; géographie reconnaissable et réemploi des biomes. Choisir taille et outils après prototype.

**Fini quand :** Un créateur place une région sans écrire une branche dans World ; tous les liens et ids se valident ; les limites d’exploration sont compréhensibles.

**Points de départ :** [src/definitions/biomes/](../src/definitions/biomes/), [src/dungeon/](../src/dungeon/), [data/biomes/](../data/biomes/).

#### R3.2 · task_308 — Implémenter le cycle de vie du chargement de secteurs

**Dépendances :** R3.1 (task_307), R2.3 (task_304)

**À réaliser :** Précharger, charger, appliquer état, activer, suspendre, sauver et décharger selon une machine de cycle de vie ; jobs annulables/générations, files et mémoire bornées. Préparer des données en arrière-plan et intégrer la scène active de façon contrôlée.

**Fini quand :** Traversées rapides, demi-tour et téléportation ne créent ni doublons ni callbacks tardifs ; aucun état sale perdu ; pas de lecture bloquante forcée avant fin d’un chargement asynchrone.

**Points de départ :** [src/world/world.gd](../src/world/world.gd), [src/game/game.gd](../src/game/game.gd).

#### R3.3 · task_309 — Gérer les coutures de collision, navigation et visibilité

**Dépendances :** R3.1 (task_307), R3.2 (task_308)

**À réaliser :** Traiter coordonnées monde/secteur, bords communs, chemins entre secteurs, trous/eau, rayons et migrations d’acteurs. Évaluer flottants/recentrage seulement à la taille mesurée du monde.

**Fini quand :** Joueur, monstres et projectiles passent une frontière sans mur invisible, chute ni téléportation ; aucun acteur n’est possédé simultanément par deux secteurs.

**Points de départ :** [src/world/world_space.gd](../src/world/world_space.gd), [src/world/nav_grid.gd](../src/world/nav_grid.gd), [src/entities/monster/monster_steering.gd](../src/entities/monster/monster_steering.gd).

#### R3.4 · task_310 — Adapter rendu, éclairage, décoration et audio au chargement

**Dépendances :** R3.2 (task_308), R3.3 (task_309)

**À réaliser :** Découper lumière, plafonds, sols, minimap locale, occlusion, sons et VFX par secteur ; réchauffer les caches utilement, les libérer avec une politique bornée. Conserver Compatibility et grille pixel.

**Fini quand :** Lumière et sons restent continus à la frontière ; pas de fuite de texture ni GPU readback en jeu ; budget d’intégration mesuré sur S23 et Windows.

**Points de départ :** [src/world/](../src/world/), [src/vfx/](../src/vfx/), [assets/shaders/](../assets/shaders/), [docs/performance.md](../docs/performance.md).

#### R3.5 · task_311 — Créer les donjons et bâtiments comme lieux persistants ou instances

**Dépendances :** R3.1 (task_307), R2.3 (task_304), R0.2 (task_293)

**À réaliser :** Réutiliser DungeonGenerator/FloorKind derrière un contexte de destination. Gérer entrée/sortie, point de retour, plusieurs donjons actifs ou archivés, renouvellement explicite, boss et récompenses uniques.

**Fini quand :** Entrer, sortir, mourir et reprendre retrouvent le bon lieu/état ; un renouvellement ne duplique pas une récompense de quête ; le Puits conserve son rôle narratif.

**Points de départ :** [src/world/floor_kinds/](../src/world/floor_kinds/), [src/dungeon/dungeon_generator.gd](../src/dungeon/dungeon_generator.gd), [src/game/game.gd](../src/game/game.gd).

#### R3.6 · task_312 — Adapter population, activité et renouvellement à la région

**Dépendances :** R3.2 (task_308), R3.3 (task_309), R0.2 (task_293), R1.4 (task_299)

**À réaliser :** Spawns par points persistants et budgets, zones sûres, retour à l’origine des monstres, activité par proximité utile, ressources, timers et anti-exploitation chargement/déchargement ; conserver écartement et cadence IA décidés.

**Fini quand :** Monstre sorti de zone ne bloque pas la quête ; aucun spawn sur un héros ni exploitation du déchargement ; simulation bornée même avec plusieurs acteurs éloignés.

**Points de départ :** [src/world/floor_populator.gd](../src/world/floor_populator.gd), [src/world/activity_manager.gd](../src/world/activity_manager.gd), [src/entities/monster/](../src/entities/monster/).

### R4 — Personnage, combat et progression RPG

**Epic Godoban : epic_283. Critère de sortie :** Le personnage évolue durablement, les zones revisitées restent cohérentes et la mort suit le contrat décidé.

#### R4.1 · task_313 — Créer le cycle de vie du personnage persistant

**Dépendances :** R2.1 (task_302), R1.6 (task_301)

**À réaliser :** Création, sélection, reprise, nom, apparence, emplacement et éventuellement plusieurs emplacements ; portée par personnage des stats, inventaire, ceinture, compétences et exploration. Nombre de personnages à confirmer.

**Fini quand :** Reprendre un personnage restitue son état sans lancer une nouvelle descente ; supprimer/exporter demande une action explicite et ne touche pas un autre personnage.

**Points de départ :** [src/game/game.gd](../src/game/game.gd), [src/ui/title/](../src/ui/title/), [src/entities/player/](../src/entities/player/).

#### R4.2 · task_314 — Reconcevoir XP, niveaux et choix de compétences

**Dépendances :** R4.1 (task_313), R0.1 (task_292)

**À réaliser :** Définir courbe durable, cap, maîtrise ou spécialisation, débloquages, respecialisation et portée des familles/reliques. Décider choix à trois conservés ou système de talents ; les classes restent une option.

**Fini quand :** Le gain répété d’XP ne produit pas une croissance sans fin accidentelle ; points et choix se sauvegardent ; personnages de référence jouables à plusieurs étapes.

**Points de départ :** [src/components/](../src/components/), [src/game/game_offers.gd](../src/game/game_offers.gd), [src/definitions/perk_def.gd](../src/definitions/perk_def.gd), [data/player/](../data/player/).

#### R4.3 · task_315 — Remplacer les dépendances à la profondeur par des règles de zone

**Dépendances :** R3.1 (task_307), R4.2 (task_314)

**À réaliser :** Faire évoluer FloorRules et LootRoller pour un contexte de région/donjon, rang, niveau et difficulté. Décider zones fixes, mise à l’échelle bornée ou mélange ; protéger les ids existants.

**Fini quand :** Revenir dans une région ne relance pas une progression d’étage ; statistiques et rareté annoncées concordent ; les outils d’équilibrage utilisent la même source de règles.

**Points de départ :** [src/world/floor_rules.gd](../src/world/floor_rules.gd), [src/definitions/loot/loot_roller.gd](../src/definitions/loot/loot_roller.gd), [data/items/item_levels.tres](../data/items/item_levels.tres), [tools/balance/](../tools/balance/).

#### R4.4 · task_316 — Adapter combat, rôles et récompenses à une progression longue

**Dépendances :** R4.2 (task_314), R4.3 (task_315), R1.4 (task_299)

**À réaliser :** Revoir sustain, soins hors combat, affixes, contrôle, portée, dégâts de chute et rôle de l’équipement ; préparer attribution des kills/assistances et coopération sans rééquilibrer aveuglément pour un MMO.

**Fini quand :** Builds sans boucle de soin/dégâts illimitée ; compteurs et droits de butin correctement attribués ; boss et foules restent lisibles sur téléphone.

**Points de départ :** [src/combat/](../src/combat/), [src/definitions/passives/](../src/definitions/passives/), [src/definitions/monster_traits/](../src/definitions/monster_traits/), [data/combat/](../data/combat/).

#### R4.5 · task_317 — Transformer mort, checkpoints, Seuil et progression des âmes

**Dépendances :** R0.2 (task_293), R0.4 (task_295), R2.2 (task_303), R4.1 (task_313)

**À réaliser :** Implémenter la règle de mort décidée, points de retour et récupération ; adapter l’arbre d’âmes et les serments à la campagne. Définir sort des offres en attente, mort pendant transition et reprise en état mort.

**Fini quand :** Mort et arrêt d’application ne retirent ni ne rendent deux fois une pénalité ; aucune suppression implicite de personnage ; Seuil/Tréfonds et âmes suivent le canon et les règles choisies.

**Points de départ :** [src/game/game.gd](../src/game/game.gd), [src/game/threshold.gd](../src/game/threshold.gd), [src/game/abyss.gd](../src/game/abyss.gd), [src/game/run_boons.gd](../src/game/run_boons.gd), [src/definitions/soul_tree/](../src/definitions/soul_tree/).

### R5 — Quêtes, PNJ et narration persistante

**Epic Godoban : epic_284. Critère de sortie :** Une chaîne de quête modifie réellement le monde et se reprend à chaque étape sans payer deux fois.

#### R5.1 · task_318 — Créer les quêtes narratives en données

**Dépendances :** R2.1 (task_302), R1.4 (task_299), R0.4 (task_295)

**À réaliser :** Le QuestDef actuel est quotidien/hebdomadaire. Ajouter objectifs composables, prérequis, branches, états, annulation et récompenses ; distinguer faits personnels, faits du monde et éventuels faits du groupe.

**Fini quand :** Une quête parler/explorer/combattre/rapporter se configure sans code par id ; graphes invalides, références manquantes et cycles bloquants détectés.

**Points de départ :** [src/definitions/quest_def.gd](../src/definitions/quest_def.gd), [src/game/quest_board.gd](../src/game/quest_board.gd), [src/definitions/story/](../src/definitions/story/).

#### R5.2 · task_319 — Implémenter le service de progression et les récompenses de quête

**Dépendances :** R5.1 (task_318), R2.2 (task_303), R1.3 (task_298)

**À réaliser :** Traiter événements typés avec contexte et ids, dédoublonnage, objets de quête, inventaire plein et acceptation/rendu. Définir rétroactivité et paiements idempotents.

**Fini quand :** Reprise à chaque objectif et répétition d’un événement ne donnent qu’un paiement ; aucune quête n’est validée parce qu’un autre acteur a ouvert son interface.

**Points de départ :** [src/game/quest_board.gd](../src/game/quest_board.gd), [src/autoload/events.gd](../src/autoload/events.gd), [src/components/inventory.gd](../src/components/inventory.gd).

#### R5.3 · task_320 — Créer les PNJ de monde et leurs services

**Dépendances :** R3.1 (task_307), R5.1 (task_318)

**À réaliser :** Placer PNJ persistants, dialogues conditionnels, services, lieux sûrs et activation après sauvetage ; préparer routines simples sans promettre un calendrier complet.

**Fini quand :** Un PNJ absent/retrouvé change les dialogues/services conformément aux faits sauvés ; services et déplacements restent dans des données réutilisables.

**Points de départ :** [src/definitions/dialogue/](../src/definitions/dialogue/), [src/entities/merchant/](../src/entities/merchant/), [src/entities/forge/](../src/entities/forge/), [src/entities/interactable.gd](../src/entities/interactable.gd).

#### R5.4 · task_321 — Adapter chroniques, révélations et cinématiques à la campagne

**Dépendances :** R0.4 (task_295), R5.1 (task_318), R5.3 (task_320), R1.5 (task_300)

**À réaliser :** Répartir Profile/Narrative entre compte, personnage et monde ; transformer conditions dépendantes des runs/profondeurs. Préparer scène personnelle ou partagée sans arrêter les autres joueurs futurs.

**Fini quand :** Aucun nom/révélation hors calendrier du canon ; dialogues vus et quêtes restent cohérents après retour ; cinématique interrompue possède une sortie définie.

**Points de départ :** [src/game/story/narrative.gd](../src/game/story/narrative.gd), [src/game/story/](../src/game/story/), [data/story/](../data/story/), [docs/lore.md](../docs/lore.md).

#### R5.5 · task_322 — Créer journal, suivi et outils d’écriture de quêtes

**Dépendances :** R5.1 (task_318), R5.2 (task_319)

**À réaliser :** Journal actif/terminé, suivi, objectifs et marqueurs, choix visibles, traduction FR/EN et outils de validation/debug. Le système de nœuds visuel reste une extension à décider après un schéma stable.

**Fini quand :** Une quête complète se crée et se débogue sans retoucher Game ; textes traduits, interface clavier/manette/tactile et marqueurs désactivables.

**Points de départ :** [src/ui/codex/](../src/ui/codex/), [src/ui/hud/](../src/ui/hud/), [tools/](../tools/), [locale/strings.csv](../locale/strings.csv).

### R6 — Inventaire, économie et services

**Epic Godoban : epic_285. Critère de sortie :** Des heures de jeu et des cycles d’achat/fabrication ne produisent ni duplication ni inflation hors des règles.

#### R6.1 · task_323 — Rendre les opérations d’inventaire transactionnelles

**Dépendances :** R2.2 (task_303), R1.2 (task_297), R1.3 (task_298)

**À réaliser :** Modéliser quantités, instances uniques, propriétés liées, équiper/jeter/ramasser/acheter/vendre/sertir comme transactions validées. Préparer concurrence future sur un même objet sans exposer l’état privé.

**Fini quand :** Deux demandes sur le même objet ne créent pas deux propriétaires ; un échec n’enlève rien ; réessais, arrêt et inventaire plein sont couverts.

**Points de départ :** [src/components/inventory.gd](../src/components/inventory.gd), [src/entities/player/player_pack.gd](../src/entities/player/player_pack.gd), [src/definitions/loot/loot_roller.gd](../src/definitions/loot/loot_roller.gd).

#### R6.2 · task_324 — Repenser monnaies, stocks et valeur des ressources

**Dépendances :** R4.3 (task_315), R6.1 (task_323), R0.2 (task_293)

**À réaliser :** Définir sources/dépenses durables, prix par zone, stocks marchands persistants, renouvellement, démantèlement et coût de respecialisation/réparation si retenu. Décider coffre de stockage et portée compte/personnage.

**Fini quand :** Matrice d’achat/revente/fabrication ne crée pas d’arbitrage infini ; stocks et argent restent corrects après reprise ; outils simulent plusieurs heures et retours de zones.

**Points de départ :** [src/definitions/items/forge_def.gd](../src/definitions/items/forge_def.gd), [src/entities/merchant/](../src/entities/merchant/), [data/shop/](../data/shop/), [tools/balance/](../tools/balance/).

#### R6.3 · task_325 — Étendre forge et consommables selon le lot retenu

**Dépendances :** R6.1 (task_323), R6.2 (task_324), R4.4 (task_316)

**À réaliser :** Réévaluer les idées SPD dans le RPG : objets tactiques, affixes de placement, recettes courtes, améliorations d’armes et récompenses exclusives. Réutiliser les cartes existantes plutôt que les dupliquer.

**Fini quand :** Le lot retenu a recettes/effets/conditions en données, aperçu et tests de paiement ; les idées non retenues restent en backlog avec décision de périmètre.

**Points de départ :** [docs/shattered-pixel-dungeon-study.md](../docs/shattered-pixel-dungeon-study.md), [src/definitions/effects/](../src/definitions/effects/), [data/runes/](../data/runes/), [data/affixes/](../data/affixes/).

#### R6.4 · task_326 — Définir le contrat de butin pour coopération future

**Dépendances :** R0.3 (task_294), R6.1 (task_323), R5.2 (task_319)

**À réaliser :** Trancher butin personnel/partagé, crédit des assistances, droits de coffre et objets de quête ; fixer portée XP et comportement d’un joueur absent. Échanges seulement si retenus et après transactions sûres.

**Fini quand :** Les scénarios deux joueurs/mort/déconnexion sont spécifiés ; un coffre unique ou une quête unique n’est jamais payé deux fois par ambiguïté.

**Points de départ :** [src/entities/monster/monster_drops.gd](../src/entities/monster/monster_drops.gd), [src/world/floor_save.gd](../src/world/floor_save.gd), [src/definitions/loot/](../src/definitions/loot/).

### R7 — Régions, contenu et identité du Puits

**Epic Godoban : epic_286. Critère de sortie :** La première région raconte et fait jouer une boucle RPG complète avec un budget d’assets connu.

#### R7.1 · task_327 — Assembler la première région et ses points remarquables

**Dépendances :** R3.1 (task_307), R0.4 (task_295)

**À réaliser :** Concevoir sanctuaire/Kagari selon le canon, chemins alternatifs, repères, zones de danger, raccourcis et accès aux deux donjons de preuve. Réutiliser les biomes et assets avant d’agrandir la bibliothèque.

**Fini quand :** La région se parcourt avec orientation lisible et continuité du terrain ; chaque embranchement utile a une raison d’exister et un état de sauvegarde clair.

**Points de départ :** [data/biomes/](../data/biomes/), [assets/](../assets/), [docs/lore.md](../docs/lore.md).

#### R7.2 · task_328 — Adapter monstres, boss, secrets et épreuves aux régions

**Dépendances :** R3.5 (task_311), R3.6 (task_312), R4.4 (task_316), R5.2 (task_319)

**À réaliser :** Affecter populations, niveaux, compatibilités d’affixes, boss et récompenses ; transformer pactes/épreuves et secrets selon retour et renouvellement. Éviter de transférer les nombres d’étage sans mesure.

**Fini quand :** Les deux donjons sont complets, le boss et les récompenses scénarisées suivent leur politique de répétition ; aucun verrou de progression dépend d’un drop aléatoire manquant.

**Points de départ :** [data/monsters/](../data/monsters/), [data/elites/](../data/elites/), [data/trials/](../data/trials/), [src/world/secret_room.gd](../src/world/secret_room.gd).

#### R7.3 · task_329 — Préparer la chaîne d’assets, d’animation et de son

**Dépendances :** R7.1 (task_327)

**À réaliser :** Inventorier décors, bâtiments, PNJ, monstres, armes et icônes réutilisables ; lister précisément les manques. Conserver équipements/animations modulaires, silhouettes et ambiances par lieu.

**Fini quand :** Table d’assets avec source/licence, variantes, directions et coût ; pas de promesse de centaines d’apparences sans budget ; aucune nouvelle pièce chargée à chaque image.

**Points de départ :** [assets/](../assets/), [data/visuals/](../data/visuals/), [data/audio/](../data/audio/), [docs/vfx.md](../docs/vfx.md).

#### R7.4 · task_330 — Réinterpréter défis, fins, succès et contenu après campagne

**Dépendances :** R0.4 (task_295), R4.5 (task_317), R5.4 (task_321)

**À réaliser :** Décider avenir des difficultés, ascensions, quotidien, records et gardien issu d’un héros ; distinguer campagne, défis isolés et activités répétables. Préserver les anciennes traces de profil.

**Fini quand :** Chaque ancien système a un devenir explicite ; scores de campagne et ancien quotidien ne sont pas mélangés ; fin d’histoire ne supprime pas le monde par accident.

**Points de départ :** [src/game/daily_run.gd](../src/game/daily_run.gd), [src/game/run_records.gd](../src/game/run_records.gd), [src/online/run_summary.gd](../src/online/run_summary.gd), [docs/design/progression.md](../docs/design/progression.md).

### R8 — Interface, outils et performances

**Epic Godoban : epic_287. Critère de sortie :** La boucle tient sur les exports S23/Windows, avec interface et chargement adaptés à une longue session.

#### R8.1 · task_331 — Créer carte du monde, exploration et déplacements

**Dépendances :** R3.1 (task_307), R2.3 (task_304)

**À réaliser :** Faire évoluer minimap vers carte région/monde, découverte persistante, repères, destinations et retours. Décider voyage rapide et ses conditions sans supprimer l’intérêt de l’exploration.

**Fini quand :** Carte exacte après aller-retour et reprise ; destination sûre disponible ; transition échouée ne perd ni monnaie ni position de retour.

**Points de départ :** [src/ui/hud/](../src/ui/hud/), [src/world/world_space.gd](../src/world/world_space.gd), [src/game/game.gd](../src/game/game.gd).

#### R8.2 · task_332 — Adapter HUD, menus et progression aux appareils

**Dépendances :** R4.1 (task_313), R5.5 (task_322), R1.5 (task_300)

**À réaliser :** Ajouter personnage, quêtes et équipement durable ; taille téléphone, navigation manette/clavier, paramètres d’accessibilité. Prévoir mode menu local en multijoueur sans ralentir le monde.

**Fini quand :** Texte FR/EN lisible et parcours complet sans souris ; aucun toucher déclenché deux fois ; monde solo et session partagée suivent leurs règles de pause distinctes.

**Points de départ :** [src/ui/](../src/ui/), [locale/strings.csv](../locale/strings.csv), [docs/design/interface.md](../docs/design/interface.md).

#### R8.3 · task_333 — Adapter tutoriel, aides et retours de combat

**Dépendances :** R4.5 (task_317), R5.5 (task_322), R8.2 (task_332)

**À réaliser :** Remplacer onboarding centré sur la descente par exploration, quêtes, sauvegarde, mort et retours ; retours visuels/audio lisibles sans déduire l’état partagé d’un effet local.

**Fini quand :** Nouvelle partie et reprise ne bloquent pas ; apprentissage par étapes et aide à la demande ; cinématiques et annonces n’écrasent pas les télégraphes.

**Points de départ :** [src/game/tutorial.gd](../src/game/tutorial.gd), [src/ui/hud/](../src/ui/hud/), [data/ui/](../data/ui/).

#### R8.4 · task_334 — Mesurer streaming, foules et mémoire sur appareils

**Dépendances :** R3.4 (task_310), R3.6 (task_312), R7.1 (task_327)

**À réaliser :** Définir et mesurer budgets de secteurs, acteurs actifs, nav, lumière, textures, temps d’intégration, percentiles de frame et mémoire. Cible 60 fps à valider, pas garantie headless ; session prolongée et chauffe sur S23.

**Fini quand :** Rapports exportés S23/Windows : traversées, combat aux frontières, butin au sol et retour après arrière-plan ; pas de croissance mémoire non bornée ni pauses de chargement non traitées.

**Points de départ :** [tools/perf/](../tools/perf/), [docs/performance.md](../docs/performance.md), [docs/android.md](../docs/android.md).

#### R8.5 · task_335 — Créer les outils de validation de contenu et de sauvegarde

**Dépendances :** R2.1 (task_302), R3.1 (task_307), R5.1 (task_318)

**À réaliser :** Valider liens de régions, ids, quêtes, apparitions, tables de butin et catalogues ; inspecter/importer des fixtures de sauvegarde, téléporter en debug et visualiser secteurs/autorité.

**Fini quand :** Une erreur de contenu est détectée avant export et nomme la ressource ; le debug ne rend pas un personnage admissible à une économie officielle future.

**Points de départ :** [tools/](../tools/), [tests/suites/](../tests/suites/), [tools/saves/build_catalog.py](../tools/saves/build_catalog.py).

### R9 — Validation et livraison du RPG solo

**Epic Godoban : epic_288. Critère de sortie :** Une région et deux donjons forment une tranche complète jouable ; la campagne s’étend ensuite avec les mêmes contrats.

#### R9.1 · task_336 — Valider une tranche RPG complète

**Dépendances :** R2.4 (task_305), R3.5 (task_311), R3.6 (task_312), R4.5 (task_317), R5.4 (task_321), R6.2 (task_324), R7.2 (task_328), R8.1 (task_331), R8.3 (task_333), R8.4 (task_334)

**À réaliser :** Scénario bout en bout : créer, explorer, accepter une chaîne, combattre, obtenir un objet, commercer, mourir, revenir, finir un donjon, revisiter, quitter et reprendre. Tester sauvegardes de chaque étape.

**Fini quand :** Scénario reproductible sans commandes de debug, progression expliquée, migration et récompenses exactes ; retours jouabilité consignés avant ajout de plusieurs régions.

**Points de départ :** [tests/suites/](../tests/suites/), [docs/testing.md](../docs/testing.md).

#### R9.2 · task_337 — Adapter les tests et la mesure à la campagne

**Dépendances :** R9.1 (task_336), R8.5 (task_335)

**À réaliser :** Conserver tests utiles et fixtures historiques, ajouter parcours/revisites/migrations/transactions ; remplacer les hypothèses invalidées d’étage par des règles explicites sans affaiblir des contrôles. Refaire bots et mesures longues.

**Fini quand :** Suites complètes, zéro erreur moteur inattendue/avertissement GDScript ; fixtures compatibles ; les instables connus ont un suivi sans être masqués par le changement de genre.

**Points de départ :** [tools/run_tests.py](../tools/run_tests.py), [tests/suites/](../tests/suites/), [tools/balance/](../tools/balance/).

#### R9.3 · task_338 — Préparer la livraison solo et sa politique de données

**Dépendances :** R9.2 (task_337), R8.4 (task_334), R2.5 (task_306)

**À réaliser :** Exports Android/Windows, taille, signature, mise à jour/reprise, options, crédits et documentation. Requalifier télémétrie, présence, compte/cloud et classements pour la campagne ; services inutiles restent arrêtés.

**Fini quand :** Tests manuels sur S23 et Windows ; aucune collecte nouvelle avant règles/choix correspondants ; fiches de distribution cohérentes avec ce qui est réellement publié.

**Points de départ :** [docs/android.md](../docs/android.md), [docs/privacy-ops.md](../docs/privacy-ops.md), [src/autoload/privacy.gd](../src/autoload/privacy.gd), [src/online/](../src/online/).

#### R9.4 · task_339 — Étendre la campagne et mesurer la durée de progression

**Dépendances :** R9.1 (task_336), R9.2 (task_337)

**À réaliser :** Ajouter régions/quêtes/donjons par lots avec la chaîne de données validée ; mesurer rythme XP, ressources, répétitions et temps perdu en trajet. Ne pas fixer une taille totale avant validation.

**Fini quand :** Chaque lot livre contenu complet, traductions et reprise ; métriques et retours guident l’extension plutôt qu’une carte immense vide.

**Points de départ :** [data/](../data/), [docs/design/](../docs/design/), [tools/balance/](../tools/balance/).

### M0 — Preuve multijoueur autoritaire

**Epic Godoban : epic_289. Critère de sortie :** Deux clients jouent un scénario commun avec une autorité indépendante et des commandes validées.

#### M0.1 · task_340 — Choisir la topologie et la frontière de confiance

**Dépendances :** R0.3 (task_294), R1.6 (task_301), R9.1 (task_336)

**À réaliser :** Prototyper une petite coopération puis trancher hôte joueur, serveur dédié, LAN/internet, nombre de joueurs et budget. ENet/MultiplayerAPI sont des candidats à mesurer ; un protocole high-level Godot n’est pas supposé compatible avec un serveur écrit ailleurs.

**Fini quand :** Décision documentée avec essais de connectivité Windows/Android et confiance d’un hôte ; Talo REST/presence n’est pas assimilé à un serveur de simulation temps réel.

**Points de départ :** [docs/online.md](../docs/online.md), [project.godot](../project.godot), [src/online/](../src/online/).

#### M0.2 · task_341 — Créer la simulation autoritaire et le démarrage serveur

**Dépendances :** M0.1 (task_340), R1.5 (task_300), R8.5 (task_335)

**À réaliser :** Démarrer session headless sans caméra/UI/audio obligatoire ; serveur décide positions valides, combats, IA, morts, loot et quêtes. Le client transmet des intentions, pas des résultats de récompense. Vérifier l’export aux visuels retirés : la simulation ne doit pas analyser des pixels de textures pour exister.

**Fini quand :** Deux clients et un serveur distincts ; requête impossible refusée ; même logique métier que solo ; build dédié charge les ressources nécessaires sans rendu.

**Points de départ :** [src/game/](../src/game/), [src/combat/](../src/combat/), [src/world/](../src/world/), [export_presets.cfg](../export_presets.cfg).

#### M0.3 · task_342 — Définir protocole, version et sécurité des commandes

**Dépendances :** M0.2 (task_341), R1.2 (task_297), R1.3 (task_298)

**À réaliser :** Messages typés et bornés, identités de connexion, numéros de séquence, délais, permissions et budgets ; compatibilité versions/contenu. RPC ne prouve pas la validité d’une action. Choisir la protection des données en transit et valider les contenus par liste blanche, jamais par chargement d’un chemin reçu.

**Fini quand :** Paquets malformés, rejoués, hors portée, trop fréquents ou pour un autre acteur refusés ; aucune Resource, Node, clé privée ou donnée inutile transmise.

**Points de départ :** [src/online/](../src/online/), [tests/suites/](../tests/suites/).

#### M0.4 · task_343 — Répliquer entités et zones d’intérêt

**Dépendances :** M0.2 (task_341), M0.3 (task_342), R3.3 (task_309)

**À réaliser :** Apparition/disparition, état initial, deltas, propriété et ids ; étudier Spawner/Synchronizer et leur visibilité plutôt que tout synchroniser. Serveur active l’union utile des zones des joueurs, indépendante des caméras.

**Fini quand :** Joueurs éloignés ne figent pas leurs ennemis respectifs ; arrivée tardive reçoit état cohérent ; aucun inventaire privé envoyé aux autres ni tableau d’objets Godot sérialisé.

**Points de départ :** [src/world/activity_manager.gd](../src/world/activity_manager.gd), [src/world/world_spawner.gd](../src/world/world_spawner.gd), [src/world/world_space.gd](../src/world/world_space.gd).

#### M0.5 · task_344 — Préserver la sensation du combat malgré la latence

**Dépendances :** M0.3 (task_342), M0.4 (task_343)

**À réaliser :** Tick de simulation, interpolation distante, prédiction locale/réconciliation et politique de validation des impacts à mesurer ; annonces, projectiles et effets idempotents. Aucun lockstep déterministe interplateforme supposé.

**Fini quand :** Scénarios latence/perte/réordonnancement : mouvement jouable, dégâts appliqués une fois, télégraphes utiles et divergences bornées ; valeurs de fréquence déterminées par mesure.

**Points de départ :** [src/combat/](../src/combat/), [src/entities/player/](../src/entities/player/), [src/entities/monster/](../src/entities/monster/), [tools/](../tools/).

#### M0.6 · task_345 — Tester pause, déconnexion et changement de région à plusieurs

**Dépendances :** M0.4 (task_343), M0.5 (task_344), R1.5 (task_300)

**À réaliser :** Menus locaux, cinéma, mort, région, arrière-plan Android, perte réseau, retour et départ de l’hôte. Choisir reprise/arrêt contrôlé au lieu de promettre migration d’hôte immédiate.

**Fini quand :** Débrancher n’annule ni dégâts ni transaction ; aucun joueur ne pause les autres ; transitions et reconnexions retrouvent l’état autoritaire et ne dupliquent pas un personnage.

**Points de départ :** [src/game/](../src/game/), [src/autoload/hit_stop.gd](../src/autoload/hit_stop.gd), [tests/suites/](../tests/suites/).

### M1 — Coopération jouable et persistance en ligne

**Epic Godoban : epic_290. Critère de sortie :** La campagne retenue se joue à plusieurs avec progression, propriété des récompenses et restauration cohérentes.

#### M1.1 · task_346 — Authentifier les joueurs et gérer les sessions de jeu

**Dépendances :** M0.3 (task_342), R0.3 (task_294)

**À réaliser :** Relier identité de compte et personnage aux connexions de jeu par un service adapté ; tickets courts, expiration/révocation et reprise. Réexaminer intégration Talo sans changer silencieusement le compte séparé de l’appareil ni sa règle de session unique.

**Fini quand :** Un joueur ne choisit pas l’id d’un autre ; deux joueurs de test utilisent deux identités ; un token de compte n’est pas diffusé aux pairs ; solo hors ligne reste défini.

**Points de départ :** [src/autoload/account.gd](../src/autoload/account.gd), [src/online/talo_backend.gd](../src/online/talo_backend.gd), [src/autoload/online_session.gd](../src/autoload/online_session.gd).

#### M1.2 · task_347 — Définir l’admission des personnages et les sauvegardes autoritaires

**Dépendances :** M1.1 (task_346), R2.2 (task_303), M0.2 (task_341)

**À réaliser :** Séparer personnages solo libres et personnages en ligne officiels ; décider import privé coopératif et limites. Sessions/écritures exclusives par personnage, révisions et reprise après crash ; adapter cloud sans écraser l’état serveur.

**Fini quand :** Un fichier local modifié ou une ancienne sauvegarde cloud ne fabrique pas de richesse officielle ; deux serveurs ne possèdent pas le même personnage ; restauration testée.

**Points de départ :** [src/autoload/cloud_save.gd](../src/autoload/cloud_save.gd), [src/autoload/profile.gd](../src/autoload/profile.gd), [src/game/run_save.gd](../src/game/run_save.gd).

#### M1.3 · task_348 — Implémenter groupes, quêtes et progression coopérative

**Dépendances :** M1.2 (task_347), R6.4 (task_326), R5.2 (task_319), M0.6 (task_345)

**À réaliser :** Groupe, invitations, départ, chef si utile, partage d’objectifs et progression de monde ; choix narratifs, boss, cinématiques et joueurs de niveaux différents selon contrat produit.

**Fini quand :** Chaîne de quête jouable ensemble avec arrivée tardive et départ ; récompenses uniques et choix personnels cohérents ; aucun blocage par un joueur absent.

**Points de départ :** [src/game/](../src/game/), [src/ui/](../src/ui/), [src/definitions/story/](../src/definitions/story/).

#### M1.4 · task_349 — Sécuriser butin, services et échanges retenus

**Dépendances :** M1.2 (task_347), R6.1 (task_323), R6.4 (task_326)

**À réaliser :** Transactions côté autorité pour ramassage concurrent, boutique, forge et fabrication ; échanges seulement si décidés, avec confirmation des deux états, verrouillage et commit atomique.

**Fini quand :** Deux ramassages simultanés, achat rejoué et déconnexion au paiement ne dupliquent ni monnaie ni objet ; audit d’événements borné et restauration vérifiée.

**Points de départ :** [src/components/inventory.gd](../src/components/inventory.gd), [src/entities/player/player_pack.gd](../src/entities/player/player_pack.gd), [src/entities/merchant/](../src/entities/merchant/).

#### M1.5 · task_350 — Créer l’interface et les règles sociales du groupe

**Dépendances :** M1.1 (task_346), M1.3 (task_348)

**À réaliser :** Liste d’amis/groupe ou code d’invitation selon cible, état réseau, marqueurs/pings et réanimation si retenue. Chat texte, blocage et signalement sont une décision de périmètre avec modération avant activation.

**Fini quand :** Entrer/rejoindre/quitter fonctionne clavier/manette/tactile ; échecs expliqués ; aucune publication forcée d’identité ou de présence.

**Points de départ :** [src/ui/](../src/ui/), [src/autoload/presence.gd](../src/autoload/presence.gd), [docs/privacy-ops.md](../docs/privacy-ops.md).

#### M1.6 · task_351 — Livrer et tester une première version coopérative

**Dépendances :** M1.3 (task_348), M1.4 (task_349), M1.5 (task_350), M0.6 (task_345)

**À réaliser :** Matrice Windows↔Windows, Windows↔S23 et S23↔S23, LAN/internet, latence, pertes, plusieurs régions et reprise après crash ; tests multi-processus et jeu réel. Version d’essai privée ; données de test ou traitement déjà couvert. La publication publique attend les validations M2.1 à M2.3.

**Fini quand :** Cible de groupe fixée et mesurée, progression stable sur sessions longues, protocole/version maîtrisés ; pas d’extension de population avant ces résultats.

**Points de départ :** [tests/](../tests/), [tools/](../tools/), [docs/android.md](../docs/android.md).

### M2 — Exploitation et extension multijoueur

**Epic Godoban : epic_291. Critère de sortie :** Une version hébergée possède sauvegarde/restauration, supervision et limites mesurées ; un monde partagé plus vaste reste une décision distincte.

#### M2.1 · task_352 — Préparer hébergement, accès internet et exploitation

**Dépendances :** M0.1 (task_340), M1.2 (task_347)

**À réaliser :** Choisir hébergement/transport, ports/NAT/relay si nécessaire, régions d’hébergement et coûts mesurés. Déploiement reproductible, secrets hors client, limites, supervision, sauvegardes et maintenance.

**Fini quand :** Serveur démarre/repart, une sauvegarde est réellement restaurée, panne/maintenance et compatibilité versions ont une procédure ; aucun abonnement engagé par la roadmap seule.

**Points de départ :** [docs/online.md](../docs/online.md), [docs/android.md](../docs/android.md), [export_presets.cfg](../export_presets.cfg).

#### M2.2 · task_353 — Revoir confidentialité, abus et observabilité

**Dépendances :** M1.1 (task_346), M1.5 (task_350), M2.1 (task_352)

**À réaliser :** Définir données nécessaires au jeu partagé, consentements optionnels distincts, champs publics/privés, rétention, suppression/export et logs expurgés ; rate limits, signalements/sanctions si social activé.

**Fini quand :** Inventaires/tokens/adresses ne se retrouvent pas dans props publics ou logs ; refus des statistiques optionnelles ne bloque pas le jeu partagé ; documentation et fiches de distribution révisées avant publication.

**Points de départ :** [docs/privacy-ops.md](../docs/privacy-ops.md), [src/autoload/privacy.gd](../src/autoload/privacy.gd), [src/autoload/telemetry.gd](../src/autoload/telemetry.gd).

#### M2.3 · task_354 — Qualifier la version en ligne et sa publication

**Dépendances :** M1.6 (task_351), M2.1 (task_352), M2.2 (task_353)

**À réaliser :** Tests de charge à la population décidée : zones éloignées, combats denses, bande passante par joueur, tick serveur, latence, mémoire, déconnexions et reprise ; sauvegardes, mises à jour et rollback de protocole. Vérifier aussi exports clients, fiches de distribution et procédure de publication de la version en ligne.

**Fini quand :** Rapports et seuils de service acceptés ; procédure de récupération testée ; aucune revendication MMO ou support d’une population non mesurée. Publication publique uniquement après ce jalon et les contrôles M2.2.

**Points de départ :** [tools/](../tools/), [tests/](../tests/), [docs/performance.md](../docs/performance.md).

#### M2.4 · task_355 — Décider l’étape monde partagé permanent et ses limites

**Dépendances :** M2.3 (task_354), R0.3 (task_294)

**À réaliser :** Si souhaité après coopération : monde qui vit sans hôte joueur, comptes/personnages serveur, ownership des instances, conflits de quêtes, économie et passages entre serveurs. Guildes, PvP, marché, logement et population massive restent des projets optionnels.

**Fini quand :** Nouvelle décision de produit avec population/budget/risques et preuve de charge ; architecture distribuée seulement si besoin mesuré, sans supposer que le RPG multijoueur impose un MMO.

**Points de départ :** [docs/rpg-roadmap.md](../docs/rpg-roadmap.md).

## Devenir des cartes et des idées existantes

Les cartes historiques sont conservées avec leur statut. 26 liens de contexte sont ajoutés ; ils ne valent pas annulation ou validation des travaux précédents. R0 doit trier aussi les autres cartes en : prérequis transversal, ancien mode à conserver, adaptation RPG ou idée reportée. Les corrections de bugs, consentement, sauvegarde et sécurité ne deviennent pas inutiles parce que le genre change.

| Ensemble existant | Lien avec la transformation |
|---|---|
| Armes évolutives, reliques, classes | R4.2/R6.3 ; les classes restent un choix, les reliques changent éventuellement de portée. |
| Salles signatures, formes, styles et épreuves | R3/R7 ; préserver états persistants et géographie reconnaissable. |
| Idées Shattered (task_273 à task_277) | Lots optionnels de consommables, récompenses, affixes, alchimie et variété. Aucune n’est nécessaire pour commencer R1/R2. |
| Cloud, profil et services Talo | R2.5/M1.1/M1.2 ; ne pas confondre copie du profil et sauvegarde RPG autoritaire. |
| Tests instables, perf, accessibilité, commandes et exports | Garder et requalifier dans R8/R9 ; défauts connus toujours tracés. |
| Quotidien, records, ascensions, fins et mode La Veille | Décision R0.4 puis R7.4 ; modes ou archives séparés si retenus. |
| Projet de horde, cosmétiques, réseau social, PvP, métiers et MMO | Idées/extension explicite ; aucun ajout imposé pour déclarer la tranche RPG finie. |

## Parcours recommandé pour les premiers travaux

1. **R0** : figer le contrat minimal (mort, propriété, renouvellement, lore et reprise de l’existant).
2. **R1 + R2** : découpler les propriétaires et sécuriser identité/persistance ; preuve à deux acteurs locaux.
3. **R3**, puis **R4/R5/R6** en parallèle selon les dépendances : petite région, personnage, quêtes et services.
4. **R7/R8 → R9.1** : terminer la tranche jouable et la mesurer sur appareils avant d’agrandir la carte.
5. **R9.2/R9.3** pour le solo livrable ; **M0** peut commencer après la tranche validée, sans attendre toute l’expansion R9.4.
6. **M1**, puis **M2** : coopération stable, exploitation et décision éventuelle de monde partagé permanent.

Les cartes ne sont pas des estimations égales de durée. Aucun calendrier artificiel n’est fixé sans capacité de travail, taille du contenu et décisions de R0. Priorité haute signifie dépendance ou intégrité du socle, pas autorisation de commencer toutes les cartes simultanément.

## Conditions communes de fin et scénarios de validation

- Respecter AGENTS.md : typage, données, tr(), ids stables, ressources immuables, tests d’une règle et docs avec le changement ; catalogues à jour, zéro avertissement et aucune erreur moteur inattendue.
- Scénarios solo : traversée A→B→A, demi-tour pendant chargement, quête à chaque étape, sac plein, boss tué, butin posé, mort pendant transition, arrière-plan Android, fermeture brutale à chaque commit et mise à jour de contenu.
- Scénarios réseau : deux acteurs au même coffre, requête rejouée, objet d’un autre joueur, arrivée tardive, plusieurs régions, cinématique, perte de connexion pendant paiement, serveur tué puis restauré, client/protocole incompatible.
- Mesurer CPU, GPU, mémoire, chauffe et rythme des images en exports S23/Windows ; percentiles et pics aux frontières comptent autant que la moyenne. Pour le réseau, mesurer aussi tick serveur, RTT, perte et bande passante par joueur.
- Versionner schémas et protocole ; conserver des fixtures des anciennes versions et tester refus contrôlé des versions futures. Aucun test existant affaibli pour faire passer un nouveau modèle.
- Un rapport headless ne valide ni lisibilité graphique, ni contrôles tactiles, ni comportement réseau réel sur mobile. Ces essais restent des critères explicites, pas des éléments marqués finis par la rédaction du plan.

## Sources de cadrage technique

Les liens officiels suivants ont été consultés le 26 octobre 2026. Ce sont des guides de capacités ; chaque choix sera vérifié avec la version exacte Godot 4.7 du projet et ses exports.

- [Chargement en arrière-plan](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) : requête asynchrone, état et récupération pouvant encore bloquer si elle arrive trop tôt.
- [APIs et threads](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) : contraintes d’accès à la scène active et aux ressources partagées.
- [Multijoueur high-level](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) : configuration client/serveur, autorité, RPC, identités de peers et contrainte Android INTERNET.
- [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html) : visibilité et propriétés synchronisées ; Resources, ids locaux et RID ne se synchronisent pas comme un état portable.
- [Export serveur dédié](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html) : mode headless et traitement des ressources visuelles pour le serveur.

## Validation du livrable de planification

Lors du lot de planification initial, les liens locaux, le graphe de dépendances, les ids/epics/tags de Godoban et la correspondance des 64 cartes ont été contrôlés. Ce lot ne modifiait que la documentation, ses index et la roadmap, sans changement moteur ni relance de sa suite de tests. La carte task_278 clôt cette planification ; les statuts actuels et les sous-lots de réalisation sont suivis dans Godoban. Le premier lot de code et ses validations sont décrits dans le [contrat du prototype](rpg-foundation-contract.md).
