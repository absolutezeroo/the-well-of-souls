# RPG : état durable et checkpoints de campagne

Deuxième lot de fondations, 26 octobre 2026. Voir la [roadmap](rpg-roadmap.md) et le
[contrat du prototype](rpg-foundation-contract.md). Les règles actuelles du roguelike et ses
fichiers restent inchangés ; ce backend n’active pas encore un mode RPG dans le menu.

## Propriétaires et schéma courant

Le deuxième lot a livré le schéma 1, le [troisième](rpg-regions.md) les objets régionaux v2.
Le [quatrième](rpg-population.md) écrit v3 avec coffres, monstres et or ; lecture/migration de
v1/v2 conservées.

Les records runtime sont des classes typées. Les dictionnaires du bloc PlayerSave restent
un format de disque réutilisé, conservé dans une copie privée, sans référence au héros vivant.

| Record | Champs persistants | Propriétaire et contrainte |
|---|---|---|
| CampaignState | id, revision, content_version, hero, world | Une campagne solo, un personnage pour ce prototype ; révision commune au commit. |
| CharacterState | id, world_id, region_id, position, claimed_rewards, player | Progression personnelle ; le monde et la région doivent exister dans le même snapshot. |
| player | level, xp, hp, base_stats, equipment, inventory, belt, gold, perks, learned_skill | Format PlayerSave actuel ; équipement amélioré, affixes, runes et mémoire durable de passifs compris. |
| CampaignWorldState | id, facts, regions | Faits communs à la campagne ; aucun nœud World sérialisé. |
| RegionState | id, layout_version, facts, initialized, layout_stamp, objects, gold, monsters, chests, population_initialized, population_stamp | Faits indexés par id de région ; la version de disposition est explicite. |
| GameSession.campaign | Référence runtime optionnelle au CampaignState | Survit à leave_expedition ; jamais incluse dans RunSave automatiquement. |

Les identités de campagne, monde et personnage ont un préfixe de domaine et 128 bits issus de
Crypto, indépendants du RNG des étages. Un NodePath, RID, get_instance_id ou numéro de génération
runtime ne constitue pas un identifiant durable. Les objets individuels d’inventaire n’ont pas
encore leur identité d’instance : cela reste une partie de R1.2/R6.

Un coffre peut conserver un fait commun dans RegionState.facts et des droits personnels dans
CharacterState.claimed_rewards. Ces deux maps ne déterminent pas encore la politique d’une
récompense ni son calcul : le futur système de quêtes/économie devra appliquer les commandes
et la portée convenues. Aucun inventaire de compte ou de groupe n’est fusionné ici.

content_version garde la version applicative du contenu au moment de la capture. Son changement
ne supprime aucun fait et ne régénère pas une région. layout_version prépare une migration
explicite de disposition ; aucune migration de carte n’est déjà implémentée.

## Capture et restauration

CampaignState.create(player, region_id) est une capture **explicite de prototype**, pas un
import produit de la sauvegarde roguelike. Elle crée une campagne à révision zéro et une
première région. GameSession.attach_campaign valide le snapshot ; capture_character copie
le bloc PlayerSave et la position du héros. Les coordinateurs de régions mettent à jour leurs
faits avant de demander un commit commun.

CharacterState.restore applique le bloc PlayerSave à un héros déjà initialisé. Le chargement de
la bonne région, le placement sûr, les caméras et la restauration du contexte d’expédition sont
à la charge du coordinateur RPG. RegionCoordinator les assure pour la preuve de lieux. La
position est conservée mais pas appliquée avant que
la région soit chargée. Les captures de héros morts ou avec Santé nulle sont refusées : la
mort, le retour au lieu sûr et les sauvegardes pendant ces transitions restent à implémenter.

Les données sont copiées aux frontières ; modifier un dictionnaire sérialisé ne modifie pas
le record source. Aucun Node/Resource ou vecteur runtime n’entre dans le JSON. Les StringName
de mémoire de passif sont des chaînes JSON ; les coordonnées sont deux nombres finis. Les
nombres entiers doivent rester exactement représentables en JSON. Les versions, champs,
références de contenu et propriétaires inconnus sont refusés plutôt que filtrés avec perte.
Les ids de contenu publiés restent ceux de ContentCatalog ; les chemins historiques nécessitent
un futur import explicite. Ces contrôles locaux ne remplacent pas une autorité de jeu réseau.

## Publication cohérente

CampaignSave reçoit un **chemin explicite**, vide et inactif par défaut. Aucun appel de
sauvegarde automatique ni accès au cloud n’est ajouté au jeu actuel. Le futur lanceur devra
fournir un emplacement propre à la campagne, distinct de run.json et profile.json.

Le checkpoint contient personnage, droits personnels, faits du monde et toutes les régions de
ce prototype dans **une même enveloppe atomique**. Il ne s’agit pas de plusieurs fichiers
personnage/région écrits indépendamment. Ce choix borné évite un manifeste multi-fichiers avant
le streaming ; les grandes cartes demanderont une autre implémentation transactionnelle.

L’enveloppe porte format=well.campaign, version=3 (lecture de v1/v2 conservée), une chaîne payload JSON et son SHA-256.
Le checksum porte sur les octets logiques exacts de payload, sans dépendre d’une nouvelle
sérialisation des nombres après lecture. C’est un contrôle d’intégrité, pas une signature.

Ordre du commit synchrone :

1. Valider une copie complète du snapshot. Acquérir un répertoire verrou exclusif `<chemin>.lock`.
2. Relire la génération publiée ; comparer id de campagne, personnage, monde et révision attendue.
3. Préparer la révision suivante dans la copie, sans modifier celle de l’appelant.
4. Écrire le dernier fichier principal validé vers `<chemin>.bak`, par SafeFile.
5. Publier la nouvelle enveloppe principale, par SafeFile : temporaire, contrôle des octets,
   puis remplacement. Le remplacement est le point de commit des deux domaines.
6. Actualiser la révision de l’appelant seulement après succès, puis libérer le verrou.

Un échec de sauvegarde de la copie précédente bloque la publication. Une réparation après
récupération ne copie jamais le principal corrompu sur le backup valide. Une réponse perdue
après publication laisse une révision périmée chez l’appelant : il doit relire avant de réessayer.
Les droits de récompense relus permettent au futur service de décider si une commande a déjà
été appliquée ; ce lot n’implémente pas ce service.

## Reprise et erreurs

load_state expose last_failure et recovered. Un principal absent, illisible ou avec checksum
incorrect peut utiliser **le backup validé**, en signalant la récupération. Un `.tmp`, même
valide, n’est jamais une publication ; `.bak.tmp` ne l’est pas davantage. Une version future,
un schéma non reconnu, un contenu indisponible ou une propriété incohérente bloque la lecture
et l’écriture : aucun retour silencieux à un ancien inventaire pour rendre le fichier lisible.

Les échecs sont distincts : désactivé, absent, I/O, corrompu, incompatible, snapshot invalide,
conflit de révision, verrou occupé et interruption simulée. Le futur écran RPG doit les afficher
et proposer les actions adaptées ; aucune interface ne masque ici ces erreurs par un nouveau héros.

Un processus arrêté avant de libérer son verrou laisse celui-ci présent. Les prochains commits
répondent BUSY ; les lectures restent possibles. Il ne faut pas supprimer automatiquement un
verrou qui pourrait appartenir à un autre écrivain. La récupération explicite, avec les autres
écrivains fermés, reste un travail avant branchement public. Le backend ne résout pas les conflits
multi-appareils. L’absence de fsync du répertoire et les particularités des systèmes de fichiers
ne permettent pas de promettre la survie à toute panne électrique ; les garanties reposent sur
SafeFile et le remplacement atomique du système cible, à mesurer sur appareils.

## Limites et suite

- Enveloppe limitée à 16 MiB avant écriture/lecture ; valeurs JSON à imbrication bornée. La
  sérialisation et la copie peuvent allouer au checkpoint, jamais par image. Latence et mémoire
  sur S23 restent à mesurer avant l’autosave ; le budget n’est pas une preuve de fluidité.
- RegionState stocke des faits et des objets au sol. Le troisième lot traverse deux cartes
  fixes chargées, compatibles par stamp. Coffres, monstres et or sont ajoutés par le
  [lot de population](rpg-population.md). PNJ, portes et activités restent à persister.
- Aucun import des âmes, arbre, serments, chroniques ou ancienne partie ; aucun transfert vers
  CloudSave. Compte, mot de passe, consentements, préférences et identifiants réseau sont exclus.
- Aucun nouveau mode public, mort RPG, quête transactionnelle, multi-personnage ou réseau.
- R1.1/R1.2/R2.1/R2.2 restent partiels ; R2.3, R2.4 et R2.5 suivent le chargement des régions,
  l’import et la synchronisation. Les droits et identités d’objets doivent être complétés.

Les définitions, le coordinateur et les objets de deux lieux sont livrés dans le troisième
lot. Le quatrième ajoute la population de combat et ses récompenses ; PNJ, portes, activités et
chargement de secteurs restent à poursuivre.

## Vérification

unit.campaign couvre identités, copie des données, schéma, références inconnues, intégrité,
révisions périmées, verrou, échec de backup et interruptions avant/après publication d’une
première génération ou d’une mise à jour. game.campaign capture et restaure un héros réel avec
équipement amélioré/runes/passif, conserve des faits de deux régions et vérifie que quitter
l’expédition ou relancer le roguelike n’efface pas la campagne séparément écrite.

Les tests de frontières injectent un arrêt logique ; ils ne coupent pas réellement l’alimentation.
Le test Python de short write vérifie séparément SafeFile avec une limite de fichier imposée
par Linux. Les essais S23/Windows et l’interface de récupération restent requis.

Validation historique du deuxième lot sous Godot 4.7 headless, seed 347348 : **19 736 vérifications, 0 échec**
dans la suite complète ; 63 ciblées et 16 773 rapides passent. Le linter rapporte
647 scripts et 0 diagnostic. Les 7 tests Python, traductions et 303 références de contenu
sont valides. Aucun export ni essai appareil réalisé ; récupération publique et mesures
S23/Windows suivies par task_360 et task_361.
