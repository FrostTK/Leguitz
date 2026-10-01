# Leguitz — reprise de la conversation avec Claude

Ce document permet de reprendre le projet dans une **nouvelle conversation** avec Claude
sans rien perdre : la vision et toutes les décisions prises, l'état exact du jeu, les points
en suspens, la **prochaine étape à lancer au « go »**, puis la feuille de route détaillée
jusqu'à la fin (y compris le nouveau **mode Arcade**).

`CLAUDE.md` (règles techniques, lu automatiquement par Claude) reste la référence pour les
conventions de code ; ce fichier-ci raconte le projet.

---

## 1. Comment reprendre

1. Ouvrir une nouvelle conversation Claude Code sur le dépôt `FrostTK/Leguitz`.
2. Tout le travail est sur la branche **`claude/2d-pixel-minecraft-game-0y9hwf`** (aucune pull
   request n'a été créée, `main` n'a pas reçu ce travail). Si la nouvelle conversation travaille
   sur une autre branche, partir de celle-ci (la fusionner dans la nouvelle branche en premier).
3. Copier-coller ce message pour démarrer :

   > Lis `CLAUDE.md` et `CLAUDE-README.md`, vérifie que le projet compile et que les tests
   > passent, puis résume-moi où on en est. Attends mon « go » avant de commencer la suite.

4. Dire **« go »** : Claude reprend à la **section 5** (phase 3). Les phases suivantes se lancent
   de la même façon, une par une, chacune avec son « go ».

**Manière de travailler convenue** : phase par phase ; Claude explique son plan, attend le
« go », développe, vérifie avec des tests et des captures d'écran, pousse sur la branche, vérifie
que la compilation GitHub est verte, puis montre le résultat en français et attend les retours.
Les questions de goût ou les choix lourds de conséquences sont posés avant de coder.

---

## 2. La vision et les décisions du propriétaire

| Sujet | Décision |
|---|---|
| Concept | Monde ouvert inspiré de **Minecraft** pour la logique (blocs, construction, craft, survie, combat, génération procédurale comme Minecraft) et de **Stardew Valley** pour le visuel (vue de dessus inclinée, pixel art chaleureux). |
| Rendu | D'abord en 2D, puis **vraie 3D pixel art** (phase 2), puis **full 3D** : le terrain en cubes texturés en pixel art, et **tout le reste en modèles 3D voxel** (1 voxel = 1 pixel du dessin) : joueur, arbres, plantes, rochers… **Tous les futurs objets (items) aussi en 3D voxel.** Viser les meilleurs graphismes possibles. |
| Plateformes | PC d'abord (installable, Steam/Epic un jour), puis **iOS et Android**. Graphismes poussés au maximum, en tirant parti de la carte graphique… sans la faire tourner à 100 % pour rien (limite d'images par seconde). |
| Graphismes | Claude crée tout lui-même, de façon procédurale (aucune ressource externe). |
| Joueurs | Solo d'abord, avec un code prêt pour le multijoueur (serveur intégré, messages). |
| Modes de jeu | **Créatif, Survie, Hardcore**, et le nouveau mode **Arcade** (phase 8, section 6). |
| Priorités | Explorer, construire, admirer, survivre, combattre. |
| Langues | Français et anglais, réglables dans le jeu. |
| Dépôt | Privé, compilation automatique par GitHub (Windows, Linux, macOS). |
| Temps | Durée d'une journée réglable **par monde** (5 à 120 min), réglage « **Synchroniser avec l'appareil** » (1 journée = 24 h, heure du jeu = heure de l'appareil), et temps figé. La faim, la cuisson, les cultures… s'adaptent **légèrement** : rythme = clamp((durée/20 min)^0,25 ; 0,7 ; 2,5), synchronisé = ×2,5. Rattrapage hors-ligne **seulement en mode synchronisé, limité à 1 journée de jeu**. |
| Caméra | Vue de dessus inclinée façon Stardew par défaut (60°, « pixel parfaite »), **orbite à la souris** autour du joueur (clic droit ou molette enfoncée), zoom à la molette. On peut **baisser la caméra jusqu'à 15°** sans que les objets s'étirent : les hauteurs gardent leur taille à l'écran, le sol se resserre, et près de l'horizon on retrouve les vraies proportions (un cube est un cube). |
| Déplacements | **Pas d'escaliers générés** : le joueur **saute d'un bloc** (1,25 niveau, comme Minecraft), tombe des bords. |
| Chargement | Tout ce qui est visible doit être chargé, même dézoomé au maximum sur l'écran ultra-large du propriétaire (3440×1440, fenêtré). Carte graphique du propriétaire : NVIDIA GeForce RTX 5050 (8 Go). |

---

## 3. État actuel : ce qui est fait

Godot **4.7.2** (GDScript), rendu Forward+. 69 tests unitaires, lint propre, compilation GitHub verte.

| Phase | Contenu | Commits |
|---|---|---|
| 0 Fondations | Serveur intégré + client par messages (prêt pour le multi), chunks 16×16, déplacements clavier/manette, horloge du monde (durée, synchro appareil, figé, rythme, rattrapage), menu pause, écran F3, FR/EN, tests, compilation GitHub | `8141e83` |
| 1 Génération | 5 bruits climatiques de Minecraft, relief par courbes, rivières, 33 biomes, paliers de hauteur, végétation par biome, 6 niveaux souterrains (grottes, lacs, lave, minerais), génération multi-cœurs, carte de debug (M) | `996c647` |
| 2 Visuels 3D | Rendu 3D pixel art (vue « pixel parfait » à 60°), soleil/lune avec vraies ombres, ambiance jour/nuit, brume, météo (pluie, orage, neige, ombres de nuages), eau et lave animées, lanterne, qualité graphique et rendu HD | `c3e413d`, `80097f8` |
| 2+ Caméra | Orbite à la souris/manette, déplacements relatifs à l'écran | `bf8058a` |
| 2+ Saut | Escaliers supprimés, saut d'un bloc, physique partagée client/serveur (`PlayerBody`) | `b5938b4` |
| 2+ Full 3D | Modèles voxel procéduraux (8 arbres, buissons, herbes, fougères, 5 fleurs, champignons, cactus, canne à sucre, nénuphars, rochers) + joueur animé ; feuillage transparent autour du joueur | `89563c1`, `2cfa843` |
| 2+ Chargement | Rayon de chunks calculé d'après la vue (zoom, fenêtre, angle) | `96b5b52` |
| 2+ Carte graphique | Modèles simplifiés de loin (3 niveaux de détail), limite d'images par seconde (60 par défaut, 15 en arrière-plan), rendu suspendu en pause | `09261cf` |
| 2+ Caméra basse | Caméra jusqu'à 15° sans étirer les objets (étirement selon l'inclinaison), trou transparent aussi dans les falaises, ombres et pluie qui suivent la vue, reflets du soleil adoucis sur l'eau, options de dev jamais enregistrées dans les réglages | « Lower camera without stretching » |

**Pas encore fait** (prévu) : interactions avec les blocs, objets et inventaire, craft,
survie/combat, créatures, structures, agriculture, sauvegardes, menus de départ, sons, mode Arcade,
mobile.

---

## 4. Repères pour Claude (en plus de `CLAUDE.md`)

### Où se trouve quoi

| Domaine | Fichiers |
|---|---|
| Point d'entrée | `src/main.gd` (crée le serveur, le client, options de développement, captures) |
| Serveur | `src/sim/game_server.gd` (sessions, envoi des chunks, messages, météo, temps) |
| Monde | `src/sim/world/` (`chunk_data.gd` : sol, bloc, niveau, forme, biome par tuile ; `top_height()` pour la physique), `generation/` (climat, relief, biomes, surface, grottes) |
| Physique | `src/sim/physics/player_body.gd` (marche, saut, chute), `tile_collider.gd` |
| Messages | `src/net/msg.gd` (tous les échanges client ⇄ serveur) |
| Client | `src/client/game_client.gd` (assemble la scène 3D, entrées, caméra), `local_player.gd` |
| Rendu 3D | `src/client/render/` : `world_viewport.gd` (SubViewport pixel parfait, caméra orbitale), `render_3d.gd` (repères, étirement de la racine du monde), `chunk_mesher.gd` (maillage du terrain), `chunk_view_3d.gd` / `world_view_3d.gd` (chunks, objets 3D, niveaux de détail), `player_model.gd`, `prop_library.gd` |
| Modèles voxel | `src/client/models/` : `voxel_grid.gd`, `voxel_mesher.gd` (faces fusionnées + occlusion), `voxel_models.gd` (tous les modèles procéduraux) |
| Shaders | `src/client/shaders/` : `terrain3d_top`, `terrain3d_faces`, `voxel`, `cloud_shadows` |
| Lumière, météo | `src/client/effects/lighting_controller.gd`, `weather_effects.gd`, `cloud_shadows_3d.gd` |
| Interface | `src/ui/` (menu pause, F3, horloge, carte) ; textes dans `i18n/strings.csv` |

### Outils

```bash
python3 tools/gen_art.py                                   # textures du terrain (+ normales, émission)
godot --headless --path . -s res://tools/gen_models.gd     # modèles voxel -> assets/models/ (à committer)
godot --headless --path . -s res://tools/render_world_map.gd -- --seed=42 --size=512 --scale=8 --out=/tmp/carte.png
```

Options de développement (après `--`) : `--seed`, `--spawn=X,Y`, `--time`, `--time-mode`,
`--day-minutes`, `--game-mode`, `--debug`, `--lang`, `--zoom`, `--screenshot=chemin`,
`--screenshot-delay`, `--autowalk=DX,DY`, `--jump`, `--pause-menu`, `--layer`, `--noclip`,
`--map`, `--weather`, `--quality`, `--hd`, `--camera=LACET,INCLINAISON` (voir `src/core/dev_options.gd`).

Lieux utiles avec la graine 42 : rivière `4,-6` ; plaine `-12,21` ; montagnes `76,123` ;
forêt sombre `-123,261` ; désert `338,-228` ; badlands `474,-232` ; jungle `-334,-498` ;
taïga enneigée `-219,147` ; champignons `163,347` ; marais `-119,-12`.

### Sur le PC Windows du propriétaire

Godot 4.7.2 est dans `C:\Users\guill\godot\` (utiliser la version `_console` pour lire la
sortie), gdtoolkit/Pillow/numpy sont installés pour `py` (Python 3.14 ; `python` est un autre
Python, celui de Laragon). Commandes depuis Git Bash : voir `CLAUDE.md`. Les captures utilisent la
vraie carte graphique (pas de xvfb) et ouvrent brièvement une fenêtre ; elles lisent les réglages du
propriétaire (HD, qualité Ultra). Une fenêtre en arrière-plan tourne à 15 images/s : le compteur
d'images de l'écran F3 n'y veut rien dire.

### Captures d'écran dans le conteneur cloud

Le rendu y est logiciel (Vulkan lavapipe, ~1 image/s en forêt) : garder des captures de
960×540 au zoom 2 et lancer les séries longues en arrière-plan (limite de 10 min par commande).

```bash
xvfb-run -a -s "-screen 0 960x540x24" godot --path . --audio-driver Dummy --resolution 960x540 \
  -- --seed=42 --lang=fr --zoom=2 --spawn=4,-6 --time=15 --camera=-30,50 --screenshot=/tmp/s.png
```

### Pièges Godot déjà rencontrés

- Shaders : `TEXTURE`/`TIME` inutilisables dans les fonctions auxiliaires ; ne pas passer une
  texture en argument. `world_vertex_coords` + MultiMesh fonctionne. `IN_SHADOW_PASS` et
  `MAIN_CAM_INV_VIEW_MATRIX` existent en 4.7.
- Les tableaux « packed » sont des valeurs : redimensionner chaque membre directement.
- Les lumières ne supportent pas l'échelle non uniforme de la racine du monde : les mettre hors
  de la racine (ou `top_level`).
- Un script d'outil (`-s`) qui ne compile pas **bloque** sans quitter : vérifier les erreurs
  d'analyse d'abord (un `timeout` est indispensable).
- `pkill -f motif` tue aussi le shell qui contient le motif : filtrer avec `[g]odot`.
- Ne jamais garder de ressources dans des variables statiques (fuites à la fermeture).
- Options de développement : passer par `Settings.override()`, jamais par les variables de
  `Settings` (sinon la prochaine sauvegarde les écrit dans les réglages du joueur).
- Caméra orthographique : la direction de vue est la même partout, un reflet du soleil couvre
  donc toute l'eau d'un coup (d'où la rugosité de l'eau qui augmente à angle rasant).

---

## 5. Prochaine étape au « go » : Phase 3 — Joueur et interactions

But : miner, construire, ramasser et gérer des objets, comme dans Minecraft, dans le monde 3D.

### 3.0 Décisions à valider avec le propriétaire avant de coder

1. **Construire en hauteur.** Aujourd'hui une tuile = un sol + un niveau + un seul bloc. Pour
   empiler des blocs (murs, maisons à étages), il faut soit des **piles de blocs par tuile**
   (2,5D, simple, garde toute la génération), soit des **chunks en vrais voxels 3D** (16×16×H,
   plus proche de Minecraft, plus lourd). Recommandation : piles de blocs par tuile (hauteur
   limitée, par ex. 32 niveaux) avec maillage en cubes, compatible avec le terrain actuel.
2. **Sauvegardes dès la phase 3** (prévues en phase 9) : construire sans pouvoir sauvegarder est
   frustrant. Recommandation : sauvegarde des chunks modifiés + joueur dans `user://` dès maintenant.
3. Contrôles : clic gauche = miner/frapper, clic droit = poser/utiliser (le clic droit sert aussi
   à tourner la caméra : distinguer clic court et glisser), molette = changer d'objet en main
   (le zoom passerait alors sur Ctrl+molette ou +/-) — à confirmer.

### 3.1 Viser un bloc
- Rayon depuis la souris dans la vue 3D (caméra orthographique) jusqu'au terrain et aux objets ;
  à la manette, la tuile devant le joueur.
- Portée limitée (≈ 4-5 tuiles), contour 3D du bloc visé, curseur.

### 3.2 Modifier le monde (serveur autoritaire)
- Messages `BLOCK_BREAK` / `BLOCK_PLACE` (client → serveur), validation (portée, mode de jeu,
  bloc présent), mise à jour du `ChunkData` (`modified = true`), diffusion `BLOCK_CHANGED`.
- Client : mise à jour du chunk et reconstruction **incrémentale** du maillage (terrain + objets
  du chunk et des voisins en bordure), prédiction locale annulée si le serveur refuse.
- Miner un arbre donne du bois ; creuser le sol abaisse la tuile ou retire la couche (selon 3.0) ;
  poser un bloc plein monte la colonne.

### 3.3 Objets et inventaire
- Registre des objets (id, nom traduit, pile max, type : bloc, outil, nourriture…), données plutôt
  que code.
- **Objets en 3D voxel** : petits modèles générés (réutiliser `VoxelModels`/`VoxelMesher`), icônes
  d'inventaire rendues depuis ces modèles (rendu hors écran mis en cache).
- Objets lâchés au sol : petits modèles qui tournent et flottent, ramassés en passant à côté.
- Inventaire : barre d'action de 9 cases + sac de 27 cases, glisser-déposer, séparer les piles,
  manette et souris ; synchronisé par messages (le serveur fait foi).

### 3.4 Outils et minage
- Dureté des blocs, temps de minage selon l'outil (main, hache, pioche, pelle), fissures qui
  apparaissent sur le bloc, petits débris voxel.
- Les durées passent par `WorldClock.scale_duration()` quand elles dépendent du temps de jeu.

### 3.5 Vérifications
- Tests : messages bloc, validation de portée, inventaire (empilement, déplacement), sauvegarde.
- Captures : miner un arbre, construire un petit mur, inventaire ouvert, sous plusieurs angles.

---

## 6. Feuille de route détaillée (phases restantes)

### Phase 4 — Craft
- Recettes en données (forme et sans forme), grille 2×2 dans l'inventaire, **établi** 3×3.
- **Four** : combustible, cuisson et fonte au fil du temps (durées adaptées au rythme du monde).
- **Coffres** (stockage par bloc, données de bloc côté serveur), outils par matériau (bois,
  pierre, cuivre, fer, or, diamant…), usure.
- Tous les objets fabriqués en 3D voxel ; blocs à poser variés (planches, briques, verre…).

### Phase 5 — Survie et combat
- Vie, faim (rythme adapté), dégâts de chute (la physique de saut existe déjà), noyade, lave,
  réapparition, mort.
- **Modes de jeu** : Créatif (vol, blocs illimités, outils de debug), Survie, Hardcore (une seule
  vie). Choix à la création du monde.
- **Créatures** en voxel animé : animaux paisibles (errance, fuite, reproduction plus tard),
  monstres la nuit et dans le noir (apparition selon la lumière), recherche de chemin sur les
  hauteurs (sauts d'un niveau).
- Combat : corps à corps, arc, recul, armures ; entités gérées par le serveur et synchronisées.

### Phase 6 — Souterrain et structures
- Torches et lumières posées, éclairage des grottes, minerais à miner, coulées d'eau et de lave
  simples.
- Structures générées : villages, ruines, donjons, mines abandonnées, avec coffres.
- Niveaux profonds plus dangereux, biomes souterrains.

### Phase 7 — Agriculture et élevage
- Labourer, semer, arroser, cultures qui poussent (durées adaptées au rythme), récoltes.
- Élevage (nourrir, enclos, reproduction), cuisine.

### Phase 8 — Mode Arcade (nouvelle idée du propriétaire)

Le mode **Arcade** propose des parties à objectif, sur des cartes spéciales. **Arcade n°1 :
« Restauration »**, idée du propriétaire, telle quelle :

> Au début de la partie, le joueur arrive sur une terre complètement désolée et se réveille sur
> une parcelle de terre dépolluée et dotée de végétation avec un équipement de base pour démarrer
> simplement sa partie et doit utiliser différents bâtiments pour restaurer progressivement
> l'environnement. Des éoliennes permettent de produire de l'énergie, tandis que des irrigateurs,
> des purificateurs et d'autres machines servent à rendre les sols fertiles, nettoyer l'eau et
> faire repousser la végétation. En combinant intelligemment ces bâtiments, il est possible de
> créer des forêts, des rivières et différents habitats pour faire revenir les animaux. Une fois
> l'écosystème entièrement restauré, les bâtiments sont recyclés afin de laisser la nature
> reprendre ses droits et laisser le joueur continuer sa survie sur la map qu'il a rétablie.

Découpage proposé (à affiner avec le propriétaire avant de commencer) :

1. **Choix du mode** : « Arcade » dans la création de monde, avec une liste de scénarios
   (Restauration en premier) ; textes FR/EN.
2. **Monde désolé** : variante du générateur (même relief et mêmes rivières que la graine, mais
   sols morts, cendre, eau polluée, arbres morts, aucune vie) et la **parcelle de départ**
   restaurée (quelques tuiles fertiles, végétation, eau propre) avec un **kit de base**.
3. **Écosystème simulé par tuile** (côté serveur, dans les chunks) : pollution, fertilité,
   humidité, qualité de l'eau, biodiversité. Mise à jour lente et progressive (durées adaptées au
   rythme du monde), diffusion entre tuiles voisines.
4. **Rendu de la restauration** : les textures et couleurs passent progressivement du désolé au
   vivant selon l'état de chaque tuile (shader du terrain), la végétation repousse d'elle-même
   (herbe qui s'étend, jeunes pousses qui deviennent des arbres).
5. **Énergie** : **éoliennes** (production selon le vent de la météo, pales animées), réseau
   électrique simple (portée ou câbles), stockage éventuel.
6. **Machines** : **irrigateurs** (humidité dans un rayon), **purificateurs** (nettoient l'eau,
   rivières qui redeviennent propres), régénérateurs de sol (fertilité), semoirs et pépinières
   (forêts), autres machines à imaginer ensemble. Toutes en 3D voxel, avec rayon d'action visible.
7. **Habitats et animaux** : forêt, rivière, zone humide, prairie… quand les conditions d'un
   habitat sont réunies, les animaux correspondants reviennent (créatures de la phase 5).
8. **Progression** : pourcentage de restauration de la carte, objectifs par étape, déblocage de
   nouveaux bâtiments.
9. **Fin du scénario** : écosystème entièrement restauré → les bâtiments sont **recyclés**
   (démontage animé, ressources rendues) et la partie continue **en Survie** sur la carte rétablie.

Dépend des phases 3 (construction), 4 (craft), 5 (créatures, modes de jeu) et 7 (végétation qui
pousse) : c'est pourquoi elle vient juste après.

### Phase 9 — Finitions PC
- Écran titre, création et chargement de mondes (graine, mode, réglages du temps), sauvegardes
  complètes (si pas déjà faites en phase 3), sons et musiques, réglages complets (touches,
  graphismes, audio), succès, intégration Steam.
- Performance : maillage des chunks sur des fils parallèles, niveaux de détail du terrain,
  modèles plus légers au besoin ; menu pause défilant sur petites fenêtres.

### Phase 10 — Mobile (iOS, Android)
- Contrôles tactiles (stick virtuel, toucher pour miner/poser, deux doigts pour tourner la
  caméra), rendu mobile, budgets de performance, interface adaptée, exports et boutiques.

---

## 7. Points en suspens et retours attendus

- **Carte graphique** : après la limite à 60 images/s et les modèles simplifiés, vérifier chez le
  propriétaire l'utilisation de la RTX 5050 (zoom normal et dézoom maximum).
- **Menu pause** trop haut sur petites fenêtres (960×540) : le rendre défilant.
- **Maillage des chunks** sur le fil principal (budget de 6 ms par image) : à paralléliser.
- **Le serveur ne vérifie pas encore les collisions** des déplacements (seulement la distance) :
  utiliser `PlayerBody` côté serveur avant le multijoueur.
- **Carrés plus sombres dans l'herbe**, de la taille d'une tuile, visibles en montagne (déjà là
  avant la caméra basse) : origine à trouver (ombres, occlusion ambiante ?).
- À angle bas sur très grand écran, plus de terrain est visible : les modèles simplifiés arrivent
  plus tôt (zoom 2 sur 3440×1440). Pire cas mesuré : 961 chunks, 60 images/s sur la RTX 5050.
