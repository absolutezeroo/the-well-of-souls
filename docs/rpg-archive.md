# Prototype RPG archivé — projet séparé ultérieur

Décision confirmée du joueur le 26 octobre 2026 : **Le Puits des Âmes reste le roguelike**.
Le futur RPG sera un nouveau projet, et non une conversion ou un second mode de ce dépôt.

Le prototype complet et ses documents/tests sont conservés sur
[archive/rpg-prototype-2026-10-26](https://github.com/absolutezeroo/the-well-of-souls/tree/archive/rpg-prototype-2026-10-26),
au commit `1996ff6cdd8738fcf3224afa3d45483a388c7819`. Cette archive contient la roadmap RPG,
la campagne de quatre lieux, les prototypes et contrats de persistance. Elle sert de référence
pour une création de projet future ; aucun nouveau dépôt RPG n’est créé maintenant.

Sur main, le titre et Game retrouvent le parcours roguelike : descentes procédurales,
progression de run, choix de perks, sanctuaire/âmes, quotidien, records et fin de run. Les
campagnes, atlas et régions fixes, lanceur, progression persistante RPG, coordinateurs et
leurs tests spécifiques sont retirés de main ; ils restent intégralement dans l’archive.

Les corrections et outils communs utiles au roguelike sont conservés :

- commandes de héros typées/réutilisées, entrée locale commune et tickets protégeant les
  anciennes continuations de mort/descente/fondu après redémarrage ;
- garde de double transfert/réentrance pour les objets et piles d’or ;
- apparitions différées liées à la génération d’étage, avec cibles faibles, pour éviter les
  rejetons/pièges/butins déposés dans un nouvel étage ou une cible déjà libérée ;
- callback de préchauffage du shader avec référence faible et vérification du sprite vivant ;
- contrôle de validité du héros précédemment lié à l’inventaire ;
- catalogue de 321 références et alias déjà publiés : ne pas revenir au catalogue de 303
  entrées et rendre illisibles des références écrites pendant les versions intermédiaires.

Aucun fichier utilisateur n’est lu, supprimé ou converti par ce changement de code. run.json,
profile.json, consentements, compte et choix locaux restent dans leur espace habituel.
Les éventuels campaign.json, backups et verrous RPG restent sur l’appareil, sans être importés
ni écrasés par le roguelike. L’archive pourra servir à les ouvrir lors d’un travail explicite.
config/custom_user_dir_name, RunSave.VERSION et FLOOR_FORMAT ne changent pas.

Les cartes RPG historiques restent dans Godoban pour conserver l’historique, avec leurs
phases marquées « Archivé · projet séparé » et leurs travaux non achevés en backlog. Elles ne
constituent pas le backlog actif du roguelike. task_372 suit ce retour au produit initial.

Les assertions des systèmes roguelike restent exécutées, notamment sauvegardes, génération,
combat, boss, Seuil, quotidien, menus, consentement et services en ligne simulés. Les tests
spécifiques au produit RPG supprimé restent dans la branche d’archive, pas transformés en
assertions toujours vraies. Les tests de commandes/session, historiquement nommés
rpg_foundations, sont maintenus parce qu’ils protègent le roguelike lui-même ; ce nom de test
n’ajoute aucun mode RPG. unit.roguelike_entry verrouille le véritable point d’entrée F5/export.

Aucun export ni essai visuel/tactile appareil n’est effectué ici. Le retour jouable doit encore
être essayé sur S23/Windows ; la carte de revue dédiée suit ce contrôle.

Validation du retour sous Godot 4.7 headless, seed 347348 : **19 695 vérifications, 0 échec** ;
16 738 rapides sans échec ; 639 scripts, 0 diagnostic GDScript ; 7 tests Python, 3 006 textes
traduits et catalogue de 321 références valides. Le vrai titre démarre en headless sans nouvelle
erreur. Ces contrôles ne remplacent pas la revue S23/Windows de task_373.
