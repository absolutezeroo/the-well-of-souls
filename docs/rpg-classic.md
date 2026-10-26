# RPG classique : parcours principal et campagne persistante

Le lancement normal (F5/export) ouvre désormais **CampaignScreen**, puis une campagne solo.
L’ancienne descente n’est plus le parcours du joueur : pas de seed quotidienne, de nouvelle run
après la mort, d’achat d’âmes au sanctuaire ni de tirage de trois perks. Le code historique et
ses scènes restent dans le dépôt pour protéger les anciennes sauvegardes et les régressions ;
aucun bouton du parcours RPG ne les lance. Il ne faut pas les confondre avec un second mode
produit à maintenir. Le passage au RPG est autorisé par la demande du joueur du 26 octobre 2026.

## Jouer

1. Mettre le dépôt à jour, ouvrir project.godot avec Godot 4.7 et lancer **F5**.
2. Choisir « Commencer l’aventure » s’il n’existe aucune campagne, sinon « Reprendre la campagne ».
3. Le Refuge de la Veille est sans ennemis. Parler à la Veilleuse ouvre le journal ; la lanterne
   propose le repos avec l’action Interagir. Le menu Pause donne aussi accès aux services.
4. Le Passage Inférieur relie le refuge, le Creux des Racines et le Caveau Oublié. Marcher sur
   un escalier traverse le passage nommé dans les données ; il ne génère pas un étage suivant.
5. Accepter les deux demandes au refuge, vaincre les gardiens uniques puis revenir rendre
   les objectifs. Les récompenses en or ne sont payées qu’une fois par personnage.

Le HUD complet reste celui du combat : Santé, XP, équipement, ceinture, compétences d’arme,
sort appris, carte, inventaire, joystick et boutons tactiles, clavier/souris/manette. L’écran
n’affiche plus profondeur, difficulté de run, âmes ou sceau d’escalier. Le bouton de talents
annonce les points disponibles ; le menu Talents est toujours accessible depuis Pause.

## Règles de personnage et de monde

| Action | Résultat |
|---|---|
| Monter de niveau | Bonus de PlayerDef conservés ; un point de talent permanent par niveau après le premier. |
| Apprendre | Choix dans CampaignDef.talents, sans tirage ni reroll ; limites de stacks de PerkDef. Le point dépensé et le talent sont publiés ensemble. |
| Changer de lieu | Même héros vivant, équipement/XP/or/cooldowns conservés ; pas de soin gratuit. |
| Mourir | Capture du personnage **actuel**, y compris les gains depuis le dernier checkpoint ; retour au refuge à pleine Santé, sans dette d’XP ni perte d’or/objets. |
| Revenir après une mort | Le nœud de héros est remplacé pour nettoyer les états transitoires de combat. Ses identités de campagne/personnage/monde, inventaire, talents et droits restent les mêmes. |
| Se reposer au refuge | Pleine Santé. Les ennemis initiaux éligibles et déjà morts des lieux inactifs réapparaissent. Pas de reset d’ennemi vivant, de voleur portant de l’or, de coffre, de butin ni de gardien unique. |
| Revisiter/relancer/attendre | Aucun renouvellement automatique sur le temps civil, chargement ou retour au premier plan. |
| Acheter une provision | Prix, objet et droit de stock personnel publiés ensemble ; chaque entrée du premier stock est disponible une fois par campagne. Le repos et la mort ne rechargent pas ce stock. |
| Explorer | Les cellules découvertes restent connues à la revisite et au redémarrage. |

Les deux « gardiens » de cette tranche sont des monstres ordinaires uniques en données, pas
les boss narratifs à phases de l’ancienne campagne. Le canon de Kagari endormie est conservé ;
Brann et le marchand de Solhar ne sont pas déplacés en surface. Les nouveaux noms décrivent
les premiers lieux souterrains sans révéler Tôma, Hana ou les fins. La campagne étendue et la
mise en scène des révélations restent du contenu à construire.

## Organisation et extension

- CampaignScreen présente le titre et les menus et répond aux requêtes du HUD ; aucun calcul
  de prix, récompense ou progression n’est placé dans les contrôles.
- CampaignRuntime possède la session, la reprise, l’autosave, la mort/reprise et les interactions
  fixes du refuge ; les récompenses attendent la fin des settlements natifs.
- CampaignProgress valide talents/achats/objectifs sur une copie de checkpoint, la publie puis
  applique le changement acquitté au héros vivant. En cas d’échec d’écriture, aucun paiement,
  achat ou point n’est appliqué en avance. Les signaux natifs du transfert sont protégés contre
  les captures réentrantes par WorldSpawner.
- RegionCoordinator possède les transitions, la capture et l’activation des régions ; RegionLoot
  et RegionPopulation continuent de suivre les fabriques/signaux, sans scans par image.
- CampaignDef, CampaignQuestDef et CampaignSupplyDef séparent règles/stock/objectifs du contenu
  de data/campaign/campaign.tres. CampaignQuestDef.completed() est extensible pour de nouveaux
  objectifs, sans chaîne de types dans Actor, World ou l’interface.
- Les lieux sont dans data/regions/campaign/. Ajouter un lieu, un passage, un talent, une
  provision ou un objectif de ce type se fait en ressources. RegionMonsterDef.renew_on_rest
  distingue les ennemis communs des adversaires uniques. La géométrie reste fixée, versionnée.

## Sauvegarde, reprise et erreurs

Le produit fournit explicitement **user://campaign.json** à CampaignSave. L’emplacement est
séparé de run.json et profile.json ; l’ancienne progression n’est ni importée, effacée, convertie
silencieusement, ni publiée au cloud. La campagne peut être jouée sans compte et sans réseau.
Les consentements et options restent dans leurs services existants. Aucun nouvel événement
réseau ni transfert de campagne n’est ajouté. Le titre garde la demande de consentement et les
options de confidentialité ; elle ne vient jamais interrompre une campagne déjà lancée.

Le checkpoint écrit héros et régions dans une seule enveloppe versionnée, avec checksum,
révision, verrou et copie de secours. **Version 4** ajoute l’exploration par région (hex des
bytes 0/1), bornée à la taille maximale d’une carte et vérifiée contre la géométrie. Les formats
1/2/3 restent lisibles ; leur migration ajoute une exploration vide et préserve tous les faits
et objets précédents. Lire ne réécrit pas le fichier source. RunSave/FLOOR_FORMAT restent v3.

Les sauvegardes interviennent au démarrage/reprise, aux passages, transactions, repos, mort,
fermeture de l’inventaire, retour au titre/fermeture de fenêtre, mise en arrière-plan et au
bout de l’intervalle d’autosave de CampaignDef (30 s de jeu actif dans la ressource actuelle).
Les écritures attendent/refusent les transferts incomplets. Un arrêt brutal peut reprendre au
dernier checkpoint acquitté ; cela ne constitue pas une promesse de journal de chaque image.

Un titre avec un principal endommagé indique explicitement que Reprendre récupère le backup
validé. Un schéma/contenu incompatible n’est jamais remplacé par une ancienne richesse ou une
nouvelle partie. Créer sur un fichier existant est refusé. Un conflit de révision interdit à
l’instance périmée d’écraser la nouvelle. Si une mort ne peut être publiée, le héros actuel reste
en mémoire, le monde est mis en pause et le bouton Réessayer reprend ce même état ; aucune
ancienne copie de personnage n’est chargée pour masquer l’échec. Un retour au titre ou une
fermeture normale ne quitte pas le jeu avant acquittement.

Le titre propose une récupération **explicite** d’un verrou abandonné : fermer toutes les
autres instances, lire l’avertissement puis confirmer. Ce bouton ne doit jamais être employé
avec un autre écrivain vivant. Le backend refuse de supprimer un verrou non vide. Aucun timer
ne décide automatiquement qu’un autre processus est mort. Les garanties de publication et
les limites matérielles restent celles de [rpg-persistence.md](rpg-persistence.md).

## Validation et limites

unit.classic_rpg valide la définition, le refuge et le parcours par défaut. game.classic_rpg
exécute création/reprise sur disque, choix de talent, refus d’écriture sans dépense, quête et
paiement unique, achat atomique, exploration A/B/A, repos/refus de repos, mort avec gains récents,
échec et reprise de la mort, persistance du stock, migration v3 et lancement du vrai écran RPG.
Les suites de campagne/région et toutes les anciennes vérifications de combat restent exécutées.

Ce changement livre la **boucle principale RPG solo** sur quatre lieux fixes. Il n’achève pas
un grand monde ouvert, la campagne narrative complète ni la roadmap multijoueur. Restent
notamment : davantage de contenu et de services/stock renouvelable, plusieurs points de repos,
import explicite des anciennes parties, multi-emplacements, boss narratifs et activités
persistantes, identités d’instances d’inventaire, streaming, équilibrage long et réseau autoritaire.
Ces travaux gardent leurs cartes dans Godoban. Aucun checkpoint privé ne doit être envoyé au
cloud existant avant un nouveau contrat explicite.

Les tests headless ne vérifient pas le rendu, la fluidité ni l’ergonomie tactile d’un export.
Les essais S23/Windows et mesures d’I/O restent requis avant de qualifier la tranche de release.

Validation Godot 4.7 headless, seed 347348 : **19 884 vérifications, 0 échec** (173 tests).
Les rapides comptent 16 821 vérifications sans échec ; linter 672 scripts, 0 diagnostic ;
7 tests Python, 3 062 clés traduites et catalogue de 321 références valides. Un démarrage
headless du vrai point d’entrée passe également. Aucun export ni essai visuel/tactile effectué ;
task_371 suit le parcours appareil.
