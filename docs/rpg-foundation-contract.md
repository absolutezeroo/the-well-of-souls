# RPG : contrat du premier prototype et premier lot technique

Date : 26 octobre 2026. Lié à [la roadmap](rpg-roadmap.md), R0 et R1.

## Statut

L’objectif confirmé est un monde ouvert, avec multijoueur ultérieur. Les règles de prototype
ci-dessous sont **une proposition de travail modifiable** : elles permettent de préparer des
scénarios et des schémas, sans changer les règles de la version jouable actuelle. R0.1/R0.2
sont en revue ; R0.3/R0.4 restent partiels. La migration et l’activation du mode RPG ne sont pas
réalisées par ce lot.

Le premier lot de code est branché dans le jeu existant : commandes par personnage, contexte
de session et protection des continuations/fondus après redémarrage. Il ne constitue ni un
monde ouvert jouable, ni une sauvegarde de personnage RPG, ni une session réseau.

## R0.1 — Périmètre proposé

- Solo hors ligne pour la première tranche ; version Windows et Android S23, renderer Compatibility.
- Une région explorable continue autour du sanctuaire et de Kagari, des chemins alternatifs,
  des repères et des intérieurs. Préparer deux donjons avec les ressources existantes.
- Un personnage par campagne dans le premier prototype ; garder un id de personnage et un id de
  monde distincts pour permettre plusieurs emplacements ultérieurement.
- Progression durable, inventaire, équipement, XP, compétences, quêtes et exploration conservés.
- Combat actuel réutilisé. Le style vient d’abord des armes et compétences ; pas de classes
  imposées au premier lot. Le choix définitif talents/classes appartient à R4.2.
- Première chaîne de quête : rencontrer, explorer, accomplir un objectif, rendre et ouvrir un
  service ou un passage. Le contenu et ses textes seront écrits sous les règles du canon.
- Commerce et forge existants pour commencer. Alchimie, métiers, banque, guildes et PvP ne sont
  pas des prérequis de la tranche.

**Scénario de référence :** créer/reprendre, explorer, accepter une quête, combattre, récupérer
un objet, utiliser un service, mourir et revenir, terminer un donjon, revisiter et redémarrer.
Le scénario complet doit fonctionner avant d’agrandir la carte.

## R0.2 — Mort et renouvellement proposés

| Élément | Règle du premier prototype proposée | Limite importante |
|---|---|---|
| Mort | Retour au dernier lieu sûr activé, personnage et équipement conservés. | Pas de destruction de sauvegarde ni de dette d’XP. Une éventuelle pénalité économique se décidera après essai. |
| Réapparition | Position sûre, Santé remise à niveau selon les règles du point de repos. | Éviter trou, eau profonde, corps occupé et boucle de morts. |
| Monstres communs | Réinitialisation via un repos explicite, dans les zones éligibles et non occupées. | Aucun renouvellement déclenché simplement par chargement, arrière-plan ou changement d’horloge. |
| Boss narratif | Première victoire et récompense de quête permanentes. | Les variantes répétables demandent une instance/politique distincte. |
| Coffre unique, secret, passage et PNJ sauvé | Faits de campagne conservés. | Revenir ou recharger ne donne pas une seconde récompense. |
| Butin au sol | État durable du lieu jusqu’à ramassage ou nettoyage explicite décidé par les règles. | Aucune disparition automatique au déchargement ; politique de nettoyage bornée à définir en R2/R6. |
| Consommables et or | Conservés avec le personnage, dépenses transactionnelles. | Le repos ne rend pas les objets dépensés et ne rembourse pas les achats. |
| Donjon | État conservé par défaut ; renouvellement explicite d’une instance répétable. | Aucun effacement d’un fait de campagne lors d’un reset d’instance. |
| Temps hors ligne | Pas de progression économique ou de respawn sur l’horloge civile dans la première tranche. | Distinguer plus tard temps de jeu, temps de session et temps serveur. |

Ces règles ne modifient pas la mort ni le format RunSave actuellement livrés. Les valeurs de
repos, les timers, les prix et la difficulté future seront dans des ressources, pas dans Game.

## R0.3 — Propriété et multijoueur proposés

| Domaine | Propriétaire dans la tranche solo | Contrat à préserver pour la suite |
|---|---|---|
| Préférences et choix de confidentialité | Installation/profil local. | Ne pas les transformer en props publics ou en état partagé de groupe. |
| Progression du personnage | Personnage de campagne. | Ne pas confondre id de contenu, id d’instance d’arme et id du personnage. |
| Exploration, coffre unique, obstacle et PNJ | Monde de cette campagne, sauf droit personnel explicite. | Chaque récompense doit dire si elle est personnelle ou partagée avant la coopération. |
| Donjon et combat temporaire | Contexte d’expédition dans un monde. | Quitter une expédition ne définit pas la durée de vie du personnage. |
| Compte/cloud | Fonction optionnelle existante. | Le cloud actuel ne couvre que Profile ; ne pas y envoyer silencieusement campagne et régions. |
| Première preuve réseau | Deux clients de test et une autorité. | Taille du groupe, topologie et hébergement définitifs à mesurer et décider en M0. |
| Personnage hors ligne | Libre dans son espace solo. | Import privé éventuel distinct d’une richesse admise en économie officielle en ligne. |

Le solo ne nécessite pas de compte. Le REST Talo et sa présence ne deviennent pas un serveur
RPG temps réel. Le choix compte/appareil séparés et la session unique restent valides. La
coopération privée, l’économie officielle et un éventuel monde permanent sont trois étapes
à distinguer ; aucune infrastructure ni nouvelle collecte n’est activée.

## R0.4 — Canon et ancien jeu

Kagari ne devient pas immédiatement une ville pleine de personnages éveillés : le canon dit
que ses habitants dorment depuis la nuit sans lune. Le sanctuaire et la Veilleuse constituent
un point de départ cohérent ; les réveils et services supplémentaires doivent provenir de
faits de campagne et de quêtes. Brann et le marchand ont leur histoire dans Solhar : leur
installation en surface demanderait un passage narratif explicite.

La Grotte, l’Ossuaire, les Archives, le Temple et Solhar restent des lieux de la profondeur,
pas des biomes de surface déplacés sans justification. Les ressources peuvent servir à des
intérieurs de prototype sans révéler trop tôt les noms et l’identité de Tôma. Le calendrier de
révélation sera traduit de « plusieurs descentes » vers les étapes de campagne avant les textes.

La version roguelike actuelle est conservée pendant la construction. Proposition de transition :
mode RPG distinct pendant le prototype, sauvegarde dans un espace versionné distinct à définir
en R2, conversion explicite ou archivage des anciennes parties. La destination finale de
l’ancien mode reste une décision produit ; ne pas maintenir deux campagnes complètes par défaut.
Ne renommer aucun id publié et ne supprimer aucune sauvegarde pour amorcer le RPG.

Le tri exhaustif de l’ancien backlog reste à finir en R0.4. Les cartes liées dans la roadmap
sont des correspondances ; les correctifs, appareils, consentements et outils transversaux
restent utiles. Le quotidien, les records, les ascensions et les deux fins gardent leurs règles
actuelles jusqu’à leur adaptation explicite.

## Premier lot implémenté

### Commandes par personnage

- PlayerCommand contient mouvement, maintien/pression d’attaque et pressions de compétences et
  d’objets. Ce sont des intentions : SkillSet, Actor et PlayerPack continuent d’appliquer les
  règles de coûts, délais et inventaire.
- LocalPlayerInput lit les actions communes au clavier, à la manette et au tactile.
- BufferedPlayerInput copie les intentions d’un producteur indépendant ; il accumule les
  pressions avant un pas, les consomme une fois et conserve le mouvement/le maintien jusqu’à
  nouvel ordre ou reset. Ce n’est pas une file de transport réseau.
- PlayerControls prélève une copie dans un tampon propre avant mouvement et actions. Tous les
  tampons sont réutilisés ; aucun tableau ni nom d’action créé par image.
- Changer de source annule charge et attaque tamponnée. Une source nulle est inactive ; elle
  ne récupère pas par surprise le clavier global. La protection du toucher de fermeture de
  menu est conservée.
- Les bornes de mouvement et de slots assainissent ce contrat local ; elles ne remplacent pas
  authentification, séquences, refus des replays, timeout et validation serveur de M0.

### Session et expédition

GameSession détient les références runtime de l’expédition, du personnage vivant et du World.
Game.run et Game.player restent des vues compatibles. Les références de nœuds ne sont pas
sérialisées. Il ne s’agit pas encore de CharacterState ou d’un WorldState durable.

Chaque entrée d’expédition crée un ticket opaque ; un ticket ne correspond pas à une autre
session même si son compteur a la même valeur. Quitter une expédition peut conserver la
référence du personnage. Le flux historique décide encore explicitement de remplacer le héros
à « Nouvelle partie ». L’écran de mort et le format v3 restent ceux du roguelike.

Les reprises de Game après attente (mort, récompenses, descente et cartes) vérifient leur ticket.
Une descente différée transporte son ticket dès sa programmation. Les fondus liés à une
ancienne expédition terminent sans peindre sur la nouvelle. La fermeture de Game invalide
les tickets avant la sortie des enfants, tout en laissant l’état consultable aux écouteurs de
sortie existants.

Cela ne remplace pas les contextes par région, l’annulation complète de toutes les cinématiques,
les propriétaires des quêtes ni les timers des monstres : R1.1, R1.2, R1.4 et R1.5 restent à terminer.
Le Game historique suppose encore une expédition active ; quitter vers un hub persistant doit
être implémenté avant d’appeler leave_expedition() dans un futur flux d’interface.

## Validation et suite

Les nouveaux tests couvrent tampon copié, pressions consommées, entrée locale, bornes, deux
producteurs, isolation de deux personnages vivants, maintien des cooldowns, protection après
menu et annulation de source. Ils vérifient aussi les tickets propres à chaque session et les
redémarrages pendant écran de mort, descente programmée et fondu en cours.

La preuve à deux personnages porte sur les commandes dans le même World de test. Elle ne
valide pas encore deux HUD/caméras, le partage de récompenses, les régions éloignées, le réseau
ni l’ensemble de R1.6. Les tests existants restent requis pour combat, sauvegardes et commandes
locales. Aucun schéma de sauvegarde, nombre de gameplay ou contenu généré n’est modifié par ce lot.

Validation du lot sous Godot 4.7 headless (seed 347348) : **19 659 vérifications, 0 échec**
dans la suite complète ; 25 nouvelles vérifications ciblées et 16 719 vérifications rapides
passent également. Le linter rapporte 639 scripts et 0 diagnostic. Les 7 tests Python des
outils, le contrôle des traductions et le catalogue de 303 références sont valides. Aucun
export ni essai visuel/tactile ou mesure de fluidité sur S23/Windows réalisé ici ; task_358
suit ces contrôles appareil.

Prochaine étape : terminer la séparation de l’état durable personnage/monde/expédition, avec
schémas et politique d’import versionnés, puis une première région persistante. Les hypothèses
R0 seront ajustées si la direction de conception évolue ; aucun paramètre de mort n’est figé
par le code livré ici.
