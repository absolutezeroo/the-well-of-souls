# Modifier Kagari dans Godot

Le village joué est décrit dans `data/village/kagari.tres`. La scène
`src/village/village_hub.tscn` le construit au lancement : elle paraît donc vide dans l’éditeur.
Pour travailler visuellement, ouvre **`tools/village/layout.tscn`** dans l’onglet **2D**.
Cet aperçu ne lance ni partie, ni profil, ni horaires de PNJ.

## Déplacer un bâtiment ou un point

1. Ouvre `tools/village/layout.tscn` depuis le panneau **Système de fichiers**.
2. Dans l’arbre de scène, développe **VillageLayout → Layout**. Sélectionne un repère,
   puis appuie sur **F** pour le cadrer. Les `Prop_XX` sont les décors et bâtiments ; leurs
   rectangles orangés montrent les collisions. Les sprites suivent leur repère.
3. Avec l’outil de déplacement, glisse le repère dans la vue 2D, ou renseigne sa
   **Transform → Position** dans l’inspecteur. Active l’aimant : pas de 2 pixels pour les objets,
   de 16 ou 32 pour les chemins. **Ctrl+Z** annule un déplacement avant application.
4. Sélectionne **VillageLayout**, puis clique **Apply positions to village data** dans
   l’inspecteur. La sortie indique combien de fichiers `.tres` ont été enregistrés.
   **C’est ce bouton qui applique au jeu ; Ctrl+S seul sur la scène d’aperçu ne suffit pas.**
5. Ouvre `src/village/village_hub.tscn` et lance **F6** pour essayer tes déplacements.
   **F5** lance le jeu complet, depuis le titre.

**Reload from village data** reconstruit l’aperçu et abandonne les déplacements non appliqués.
La scène reconstruit aussi son aperçu à l’ouverture. Ne te sers pas d’une sauvegarde de la scène
`layout.tscn` pour conserver des modifications : applique-les dans les données.
Après application, les positions deviennent le nouveau point de départ. Pour annuler un
ensemble déjà appliqué, remets les positions et applique à nouveau, ou restaure les fichiers
concernés avec Git. L’outil n’est pas un éditeur de sauvegardes de joueurs.

## Quels repères déplacer ensemble ?

| Repère | Effet |
|---|---|
| `Prop_XX` | Décor, avec sa collision locale ; aucune porte n’est déplacée automatiquement. |
| `Well`, `Spawn`, `Noticeboard`, `Memorial` | Puits, arrivée du héros, tableau de quêtes, statue. |
| `Path_XX` | Début d’une zone pavée ; sa taille reste inchangée. |
| `Home_nom` | Position d’origine/écho d’un habitant. |
| `Animal_nom` | Place d’un animal (poules, chat, chien) : il y dort et se promène dans le cadre bleu autour. Garde-la à moins de 3 tuiles de son propriétaire (potager, étal, cabane). |
| `nom_08h_…` | Destination d’une activité à cette heure. Chaque horaire reste indépendant. |
| `temple_door`, `temple_return_position` | Entrée extérieure et endroit où ressort le héros. |
| `temple_spawn`, `temple_exit`, `temple_shrine` | Arrivée, sortie et sanctuaire dans la salle. |
| `temple_camera_center` | Centre du cadrage intérieur. |

Si tu déplaces le **temple**, déplace aussi sa porte et son point de retour. Si tu déplaces une
maison, pense au point `Home_…` et aux destinations des horaires qui s’y rendent. L’intérieur
est dessiné à droite de la place : ses positions sont converties automatiquement en coordonnées
locales lors de l’application. Il n’est pas nécessaire de calculer son décalage toi-même.

Garde les entrées devant les façades, hors des collisions, et un passage assez large entre
les obstacles. L’outil ne devine pas un chemin praticable : vérifie à pied et observe les PNJ.
Il montre tous les décors, y compris les racines supprimées par les quêtes ; les états de
restauration, la nuit, les animations et les horaires se vérifient dans le jeu.

## Ajouter et régler du contenu

Ouvre les `.tres` dans l’inspecteur, enregistre-les, puis recharge l’aperçu :

- **Décors/bâtiments :** dans `kagari.tres`, agrandis `Props`, crée un `VillagePropDef` et
  renseigne `Texture`, `Region`, `Position`, `Art Scale` et `Collision`. La position est au
  milieu du bas du sprite ; la collision est locale. Ne duplique pas une référence partagée
  pour créer un nouvel objet : utilise **Rendre unique** ou une nouvelle ressource.
- **Décors animés :** un `VillagePropDef` dont `Frames` vaut plus de 1 joue les images du pack
  posées côte à côte à partir de `Region` (drapeaux, fleur qui se balance), une toutes les
  `Frame Time` secondes. Copie la feuille du pack telle quelle (dossier `Backgrounds/Animated`).
- **Animaux :** `Animals` dans `kagari.tres` (`VillageAnimalDef`) : feuille du pack
  (`Actor/Animal`), `Home`, `Roam` (demi-taille du cadre de promenade, 3 tuiles au plus),
  `Idle Frames`/`Walk Frames`, vitesse, pauses et heures de veille (`Wakes At`, `Sleeps At`).
- **Sols/chemins :** `Ground`, `Ground Region`, `Paths`, `Path Texture` et `Path Region`.
  L’aperçu déplace les chemins ; leurs dimensions se règlent dans `Paths`.
- **Temple :** `data/village/temple.tres`, avec `Tiles`, `Props`, `Walls`, `Walk Bounds`,
  les portes et le cadrage. Pour une autre maison jouable, crée un autre
  `VillageInteriorDef` et ajoute-le à `Interiors` sur le village.
- **PNJ :** `keeper.tres`, `ren.tres`, `sayo.tres`, `wanderer.tres`. `Schedule` contient les
  horaires ; `Destination` donne le lieu et `Room` l’intérieur éventuel. Les horaires commencent
  à minuit et restent triés. `Idle Frames` et `Walk Frames` décrivent l’animation du spritesheet.
- **Dialogues :** les salutations, réactions et `Topics` sont dans ces ressources.
  Le texte source est en anglais ; sa traduction française va dans `locale/strings.csv`.
- **Jour/nuit :** `data/village/clock.tres` (durée d’une journée et couleurs).
- **Âmes, lampes et descente :** `data/village/atmosphere.tres` (quantité, vitesse, rayon,
  palette et durées). Les durées des quatre phases doivent rester strictement positives.

Le pack du temple ne fournit pas de maisons résidentielles : les façades provisoires restent
à remplacer avec les assets adaptés. Le guide [ajouter du contenu](adding-content.md) détaille
les ressources. Après une modification de disposition, exécute au minimum les tests
`unit.village` et `title.village` décrits dans [testing.md](testing.md).
