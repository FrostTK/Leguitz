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

4. Dire **« go »** : Claude reprend à la **section 5** (phase 4). Les phases suivantes se lancent
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
| Caméra | Vue de dessus inclinée façon Stardew par défaut (60°, « pixel parfaite »), **orbite à la souris** autour du joueur (clic droit ou molette enfoncée), zoom à la molette en gardant le clic molette enfoncé (ou Ctrl+molette, +/-). On peut **baisser la caméra jusqu'à 15°** sans que les objets s'étirent : les hauteurs gardent leur taille à l'écran, le sol se resserre, et près de l'horizon on retrouve les vraies proportions (un cube est un cube). **1re personne automatique en entrant dans une grotte** (réglage désactivable dans le menu pause) et **à tout moment avec F5**, avec une **plongée** de la caméra dans la tête du joueur ; F5 vaut jusqu'à la prochaine entrée ou sortie de grotte. |
| Déplacements | **Pas d'escaliers générés** : le joueur **saute d'un bloc** (1,25 niveau, comme Minecraft), tombe des bords. |
| Monde | **Vrais voxels 3D** comme Minecraft (choix de la phase 3) : chunks de 16×16 colonnes sur **128 blocs de haut** (64 sous le niveau de la mer, le relief jusqu'à +32, de la place pour construire au-dessus). Grottes 3D sous la surface, plus de « couches » séparées. **L'eau ne coule pas encore** (on y marche ; coulées en phase 6, nage en phase 5). |
| Eau | **Transparente** : on voit le fond, de moins en moins avec la profondeur (pour voir plus tard les poissons nager, pêcher, admirer la végétation sous-marine), avec une **ondulation du fond** et des reflets dansants. Limpidité par type : eaux chaudes tropicales très claires (~10 blocs), rivières et lacs clairs (~6), océans plus bleus (~4-5), marais troubles (1-2). Lave et glace restent opaques. |
| Sous terre | **Vue en coupe** : dès qu'il y a un plafond au-dessus du joueur (grotte, galerie, toit), tout ce qui dépasse sa tête est coupé, la roche coupée s'affiche en sombre. |
| Arbres, plantes | Restent des **modèles voxel détaillés** posés dans une case (pas des troncs en blocs) : miner le pied abattra l'arbre entier. Arbres **grands, épais et tous différents** (8 versions par espèce, troncs de hauteurs et d'épaisseurs variées), **réalistes en restant en pixel art** (1 voxel = 1 pixel : troncs penchés sur racines, branches fourchues, grappes de feuilles éclairées, écorce sillonnée, mousse). **Seul le tronc bloque**, et jamais deux objets solides côte à côte : on passe toujours entre les arbres. |
| Sauvegardes | **Dès la phase 3** (fait) : chunks modifiés + joueur, sauvegarde auto toutes les 2 min, en ouvrant le menu pause et à la fermeture (« Monde sauvegardé » s'affiche sous l'horloge) ; un seul monde en attendant l'écran titre. |
| Contrôles (phase 3) | Clic gauche maintenu = miner, clic droit court = poser, clic droit glissé = tourner la caméra ; **molette = objet en main** (zoom en vue de dessus : molette en gardant le clic molette enfoncé, ou Ctrl+molette, et +/-), touches 1 à 9 ; manette : gâchettes miner/poser, LB/RB changer d'objet ; F7 (debug) : outils. |
| Outils avant le craft | **Tout se mine à la main** (lentement, chaque bloc donne quelque chose) ; les outils (pioche, hache, pelle, en 6 matériaux) minent plus vite ce pour quoi ils sont faits ; en attendant le craft (phase 4), **F7** (debug) donne les outils du matériau suivant. Fait à l'étape 3.5 (vitesses de Minecraft, temps de minage en temps réel, pas adapté au rythme du monde). |
| Livre du joueur | Une **10e case** à part, à droite de la barre (les 9 restent centrées), tient un **livre ancré** : on ne peut ni le jeter ni le déplacer. 0 le prend en main (0 encore, ou clic droit, l'ouvre) ; il montre les touches (celles du clavier du joueur : ZQSD en AZERTY), la manette, des astuces, les outils et bientôt les recettes. Se désactive dans le menu pause (activé par défaut). |
| Établi | **Modèle voxel sur 2 cases**, d'après la photo d'un établi de menuisier en hêtre envoyée par le propriétaire : plateau épais en lamelles, étau à gauche, étagère ouverte sous le plateau, 4 petits tiroirs, 2 grands et une porte à charnières, pieds en traîneau ; dessus, des détails du jeu : une petite enclume, un marteau et une scie en fer. Il se pose face au joueur. |
| Craft | Recettes comme Minecraft : une forme placée n'importe où dans la grille (en miroir aussi) ou sans forme, ingrédients d'un même groupe interchangeables (n'importe quelles planches). **Grille 3×3 dans l'inventaire (E)**, **établi 5×5** (étape 4.2). Clic sur le résultat pour le prendre, Maj+clic pour en faire le plus possible ; ce qui reste dans la grille revient dans le sac à la fermeture. Les recettes s'affichent dans le livre du joueur. |
| Chargement | Tout ce qui est visible doit être chargé, même dézoomé au maximum sur l'écran ultra-large du propriétaire (3440×1440, fenêtré). Carte graphique du propriétaire : NVIDIA GeForce RTX 5050 (8 Go). |

---

## 3. État actuel : ce qui est fait

Godot **4.7.2** (GDScript), rendu Forward+. 129 tests unitaires, lint propre.

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
| 2+ Caméra basse | Caméra jusqu'à 15° sans étirer les objets (étirement selon l'inclinaison), trou transparent aussi dans les falaises, ombres et pluie qui suivent la vue, reflets du soleil adoucis sur l'eau, options de dev jamais enregistrées dans les réglages | `8e1ed5d` |
| 3.1 Monde en voxels | Chunks 16×16×128 (ids : sols < 64, blocs 64+), génération remplissant les colonnes + grottes 3D (salles, tunnels, lacs, lave, filons de minerai), physique 3D (plafonds, objets hauts de 3), maillage sur les cœurs (faces fusionnées, grottes à part), vue en coupe sous terre, Page ↓/↑ = grotte suivante (`--descend=N`), carte de debug en coupe, chargement aussi rapide qu'avant | `493ff38` |
| 3.1b 1re personne | Automatique dans les grottes (réglage), F5 partout, plongée de la caméra (perspective qui s'ouvre, étirement qui s'efface, corps qui disparaît en tramé, roche traversée transparente), souris capturée, viseur, lanterne à la main, ciel procédural, brume au loin, ombres en cascades, détail des objets selon la distance, plafonds texturés (`--first-person`, `--look`, `--dive`) | « First-person view » |
| 3.1c Arbres | Arbres procéduraux détaillés (`TreeModels`, 8 espèces × 8 versions de tailles différentes), forêts plus denses ; `ObjectShapes` partagé physique/modèles : seul le tronc bloque (boîtes d'obstacles), objets solides jamais voisins ; feuillages jamais sous 2 niveaux (la caméra à la 1re personne reste sous les couronnes) ; détail des objets : hors de l'écran (ombres seules) toujours simplifiés, en 1re personne selon la distance au joueur, réduit en qualité Bas/Moyen ; F3 affiche le temps GPU et les triangles | `1f26962` |
| 3.1d Eau transparente | Surface de l'eau à part (shader `water.gdshader` : textures d'écran et de profondeur), fonds et berges sous l'eau maillés et fondus comme la terre ferme, fondu par paliers selon l'épaisseur d'eau traversée, ondulation du fond par pixels entiers, caustiques dans les bas-fonds, écume et vagues conservées ; lacs des grottes aussi | `7ad0662` |
| 3.2 Sauvegardes | `WorldStorage` (côté serveur) : `user://worlds/world_1/` = world.cfg (réglages, horloge, météo), players/<nom>.cfg, regions/ (chunks modifiés, 32×32 par fichier, compressés) ; écriture à côté puis échange (copie .bak) ; `WorldState.set_voxel` marque le chunk à sauvegarder, chargé au lieu d'être régénéré ; sauvegarde toutes les 2 min, en pause et en quittant ; joueur remis où il était (jamais dans le sol) ; `--seed` seul = monde jetable jamais sauvegardé, `--new-world`, `--world=NOM` | `0ff00bb` |
| 3.3 Viser, miner, poser | `Mining` (portée 5, temps à la main par bloc, règles de pose, l'eau comble les trous voisins) et `VoxelRay` (rayon voxel par voxel, troncs et plantes atteints sur leur corps) partagés ; `BlockInteraction` côté client : visée à la souris (vue de dessus), au viseur (1re personne) ou devant le joueur (manette), cadre d'un pixel du dessin, fissures (10 stades), éclats, bras qui frappe, arbres qui tombent ; prédiction locale, le serveur vérifie et diffuse `BLOCK_CHANGED` ; `--aim`, `--mine`, `--place` | `0a99322` |
| 3.4 Objets et inventaire | Registre `Items` (41 objets traduits ; ce que donne chaque bloc : l'herbe de la terre, un arbre une bûche par niveau de tronc et des bâtons…), `Inventory` partagé (barre de 9 + sac de 27 + pile du curseur, règles de Minecraft), objets au sol (tombent, flottent, ramassés en passant, sauvegardés), modèles voxel des objets et icônes rendues hors écran, barre en bas de l'écran (nom de l'objet en main), inventaire (E : clic, clic droit = moitié/un, Maj+clic, lancer en cliquant à côté), molette et 1-9 (clic molette maintenu + molette, ou Ctrl+molette = zoom), Q pour lancer (Ctrl : la pile), LB/RB à la manette, objet tenu en main (corps et 1re personne) ; on pose le bloc en main | `7d2365d` |
| 3.5 Outils et dureté | 18 outils (`Items.TOOLS` : pioche, hache et pelle en bois, pierre, cuivre, fer, or et diamant ; ils ne s'empilent pas), dureté de chaque bloc et outil qui lui convient (`Mining.break_seconds`, `tool_for` : la pioche pour la pierre, les minerais, la glace et la terre cuite, la pelle pour la terre, l'herbe, le sable, la neige et la boue, la hache pour les arbres et les grands champignons ; rien n'aide pour les plantes) ; vitesses de Minecraft (×2 bois, ×4 pierre, ×5 cuivre, ×6 fer, ×8 diamant, ×12 or), ¼ s entre deux blocs ; modèles voxel en diagonale comme les icônes de Minecraft (icônes face à la caméra, objets plats plus grands au sol), outil tenu par le manche (couché à plat pour se voir de dessus, le poignet frappe ; à la 1re personne en bas à droite, avec le geste) ; **F7** (debug) donne les outils du matériau suivant (annoncé au-dessus de la barre) ; ligne « Visé » de l'écran F3 (bloc, temps de minage avec l'objet en main, outil qui convient) ; une case d'inventaire se redessine quand son icône arrive | `9733d72` |
| 3.6 Livre du joueur | 10e case à part (réglage « Livre du joueur » du menu pause, activé par défaut), livre ancré (ni jeté ni déplacé ; dans l'inventaire, un clic l'ouvre), touche 0 (encore : l'ouvrir), molette et LB/RB passent par lui, clic droit pour l'ouvrir ; `BookScreen` : livre ouvert sur deux pages (onglets des chapitres, page de titre et sommaire, flèches, numéros de page ; flèches, molette, touches de déplacement pour tourner les pages ; Échap, E, 0 ou clic droit pour fermer), texte de `GuideBook` : touches (noms de `InputNames`, selon le clavier du joueur), manette, 11 astuces, outils (icônes, vitesses), fabrication (à venir) ; modèle voxel du livre (en main, en 1re personne) ; le menu pause défile quand la fenêtre est trop petite ; `--book[=N]` | `209f9b7` |
| 4.1 Recettes et grille 3×3 | Registre `Recipes` (avec forme, placée n'importe où et en miroir, ou sans forme ; groupes d'ingrédients comme « n'importe quelles planches » ; recettes réservées à l'établi possibles), grille de fabrication dans l'`Inventory` (5×5 cases, l'inventaire utilise les 3×3 du haut à gauche), clic sur le résultat (Maj : le plus possible), la grille et le curseur reviennent dans le sac à la fermeture, `Msg.CRAFT` vérifié par le serveur ; recettes : bûche → 4 planches de son bois, 2 planches → 4 bâtons, 4 planches → établi ; planches des 6 bois et établi posables (blocs cubes, textures de `gen_art.py` : planches clouées, établi à grille 5×5 et outils sur les côtés), à la hache ; les objets-blocs montrent leurs côtés ; chapitre « Fabrication » du livre (recettes dessinées, les planches défilent) ; `--grid` | `6f011e6` |
| 4.1b Établi en modèle | L'établi devient un modèle voxel de 2 cases (`WorkbenchModel` : établi de menuisier en hêtre, étau, tiroirs, porte, enclume, marteau et scie en fer dessus), posé face au joueur (4 orientations : `WORKBENCH`, `_WEST`, `_NORTH`, `_EAST`, plus son autre bout `WORKBENCH_END_X/_Z` sans modèle) sur la case visée et celle de sa droite (sinon de sa gauche), libres et posées sur des cubes (`Mining.placement`) ; casser un bout casse tout l'établi et rend un établi (`Mining.object_cells`) ; collisions sur les deux cases, cadre de visée autour de l'établi entier ; icône, objet en main et au sol avec le même modèle ; sa texture de cube est retirée des atlas | « Workbench model » |

**Pas encore fait** (prévu) : la suite de la phase 4 (établi 5×5, usure, coffres, fours, blocs de construction), survie/combat, créatures, structures, agriculture, menus de départ, sons,
mode Arcade, mobile.

---

## 4. Repères pour Claude (en plus de `CLAUDE.md`)

### Où se trouve quoi

| Domaine | Fichiers |
|---|---|
| Point d'entrée | `src/main.gd` (crée le serveur, le client, options de développement, captures) |
| Serveur | `src/sim/game_server.gd` (sessions, envoi des chunks, messages, météo, temps, sauvegarde), `src/sim/save/world_storage.gd` (fichiers du monde sauvegardé) |
| Monde | `src/sim/world/` (`voxels.gd` : ids et propriétés des voxels ; `chunk_data.gd` : 16×16×128 voxels, biome et sommet du terrain par colonne ; `world_state.gd` : chunks du serveur, recherche d'un sol pour les déplacements de debug), `generation/` (climat, relief, biomes, surface → colonnes, `cave_generator.gd` : grottes 3D et minerais) |
| Minage | `src/sim/world/mining.gd` (règles, durée selon le bloc et l'outil : `break_seconds`, `tool_for`), `src/sim/world/voxel_ray.gd` (visée), `src/client/interaction/` (visée et rendu côté client : cadre, fissures, éclats, arbres qui tombent) |
| Objets | `src/sim/items/` (`items.gd` registre, ce que donne chaque bloc, outils et leurs vitesses, `recipes.gd` recettes, `inventory.gd`, `dropped_item.gd`), `src/client/items/` (modèles, icônes rendues hors écran, objets au sol), `src/ui/hotbar.gd`, `inventory_screen.gd`, `item_slot.gd` |
| Physique | `src/sim/physics/player_body.gd` (marche, saut, chute, plafonds, parmi les voxels), `tile_collider.gd` (déplacement parmi des boîtes d'obstacles : case entière, tronc, rocher) ; `src/sim/world/object_shapes.gd` (versions des objets, troncs, emprise au sol : partagé avec les modèles) |
| Messages | `src/net/msg.gd` (tous les échanges client ⇄ serveur) |
| Client | `src/client/game_client.gd` (assemble la scène 3D, entrées, caméra), `local_player.gd` |
| Rendu 3D | `src/client/render/` : `world_viewport.gd` (SubViewport pixel parfait, caméra orbitale), `render_3d.gd` (repères, étirement de la racine du monde), `chunk_mesher.gd` (maillage des voxels sur les fils de travail, carte de surface du shader), `chunk_view_3d.gd` (terrain, grottes, objets 3D, lave d'un chunk) / `world_view_3d.gd` (tâches de maillage, coupe sous terre, niveaux de détail), `player_model.gd`, `prop_library.gd` |
| Modèles voxel | `src/client/models/` : `voxel_grid.gd`, `voxel_mesher.gd` (faces fusionnées + occlusion), `voxel_models.gd` (tous les modèles procéduraux), `tree_models.gd` (les arbres détaillés) |
| Shaders | `src/client/shaders/` : `terrain3d_top`, `terrain3d_faces`, `water` (eau transparente), `voxel`, `cloud_shadows`, `terrain3d_surface.gdshaderinc` (carte de surface, transitions entre sols), `see_through.gdshaderinc` (trou transparent, coupe sous terre, roche en coupe) |
| Lumière, météo | `src/client/effects/lighting_controller.gd`, `weather_effects.gd`, `cloud_shadows_3d.gd` |
| Interface | `src/ui/` (menu pause, F3, horloge, carte, barre d'objets, inventaire ; le livre du joueur : `book_screen.gd` le livre ouvert, `guide_book.gd` son texte, `input_names.gd` les noms des touches) ; textes dans `i18n/strings.csv` |

### Outils

```bash
python3 tools/gen_art.py                                   # textures du terrain (+ normales, émission)
godot --headless --path . -s res://tools/gen_models.gd     # modèles voxel -> assets/models/ (à committer)
godot --headless --path . -s res://tools/render_world_map.gd -- --seed=42 --size=512 --scale=8 --out=/tmp/carte.png
```

Options de développement (après `--`) : `--seed`, `--spawn=X,Y`, `--time`, `--time-mode`,
`--day-minutes`, `--game-mode`, `--debug`, `--lang`, `--zoom`, `--screenshot=chemin`,
`--screenshot-delay`, `--autowalk=DX,DY`, `--jump`, `--pause-menu`, `--descend=N`, `--noclip`,
`--map`, `--weather`, `--quality`, `--hd`, `--camera=LACET,INCLINAISON`, `--hide-debug`,
`--first-person`, `--look=INCLINAISON` (1re personne), `--dive=T` (plongée figée à T entre 0 et 1,
pour les captures), `--new-world` (recommencer le monde sauvegardé), `--world=NOM` (un autre monde
sauvegardé), `--aim=X,Y` (viser ce point, en unités de l'interface depuis le centre : pixels divisés par l'échelle de l'interface, « UI x2 » dans l'écran F3), `--mine` (garder le
bouton de minage enfoncé), `--place` (poser un bloc une fois), `--give=objet:N,...` (donner des
objets, noms de `Items.Id` : `dirt:20,diamond:3`), `--inventory` (ouvrir l'inventaire), `--drop`
(lancer la pile en main), `--book[=N]` (ouvrir le livre du joueur à la double page N),
`--grid=objet,...` (remplir la grille de fabrication ligne par ligne, `none` = case vide) (voir
`src/core/dev_options.gd`). **`--seed` seul joue un monde jetable, jamais
sauvegardé** : les captures ne touchent jamais au monde du propriétaire.

Lieux utiles avec la graine 42 : rivière `4,-6` ; plaine `-12,21` ; montagnes `76,123` ;
forêt sombre `-123,261` ; désert `338,-228` ; badlands `474,-232` ; jungle `-334,-498` ;
taïga enneigée `-219,147` ; champignons `163,347` ; marais `-119,-12` ; océan profond `133,55` ;
mer chaude `478,276` ; lac souterrain `-1,-4` (`--descend=1`).

### Sur le PC Windows du propriétaire

Le monde du propriétaire est sauvegardé dans
`C:\Users\guill\AppData\Roaming\Godot\app_userdata\Leguitz\worlds\world_1\` : ne jamais y
toucher (pour tester, `--world=essai`, puis effacer ce dossier).

Godot 4.7.2 est dans `C:\Users\guill\godot\` (utiliser la version `_console` pour lire la
sortie), gdtoolkit/Pillow/numpy sont installés pour `py` (Python 3.14 ; `python` est un autre
Python, celui de Laragon). Commandes depuis Git Bash : voir `CLAUDE.md`. Les captures utilisent la
vraie carte graphique (pas de xvfb) et ouvrent brièvement une fenêtre ; elles lisent les réglages du
propriétaire (HD, qualité Ultra, écran F3 affiché : `--hide-debug` pour des captures propres). Une
fenêtre en arrière-plan tourne à 15 images/s : le compteur d'images de l'écran F3 n'y veut rien
dire. Mesurer le chargement : graine 42 en 1920×1080, monde affiché vers 3,5 s (zoom 3) et 4,3 s
(zoom 1), démarrage de Godot compris (~1,7 s). Mesurer le rendu : l'écran F3 (`--debug`) affiche le
temps GPU du monde et les triangles dessinés ; `--quality=0` (sans ombres du soleil) montre la part
des ombres (60 à 70 % des triangles en forêt). Repères (1280×720, RTX 5050, Ultra) : forêt de la
rivière `4,-6` vue de dessus zoom 3 ≈ 7,7 M triangles, 5,5 ms, 1re personne ≈ 10 M, 9 ms ; jungle
`-334,-498` (le pire cas) ≈ 14 M, 7 ms vue de dessus, ≈ 29 M, 17 ms en 1re personne.
Régénérer tous les modèles prend ~15 min (`-- --only=oak` pour une espèce, ~1 min 45). Les
modèles d'arbres pèsent ~25 Mo et sont committés : ne les régénérer que quand un modèle change
(chaque régénération alourdit l'historique git).

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
- Tester les commandes dans le vrai jeu : un script `-s` qui étend `SceneTree` charge
  `res://scenes/main.tscn` (options de dev après `--`, `--seed` pour un monde jetable), attend que
  le client ait rejoint (`find_children("*", "GameClient", true, false)`) et injecte des événements
  avec `Input.parse_input_event` (renseigner `screen_relative` des mouvements). Si le test change
  un réglage (zoom…), poser d'abord un `override.cfg` à la racine du projet
  (`[application]` `config/use_custom_user_dir=true`, `config/custom_user_dir_name="LeguitzTest"`)
  pour ne pas toucher aux réglages du propriétaire, puis l'effacer avec ce dossier.
- Ne jamais garder de ressources dans des variables statiques (fuites à la fermeture).
- Options de développement : passer par `Settings.override()`, jamais par les variables de
  `Settings` (sinon la prochaine sauvegarde les écrit dans les réglages du joueur).
- Caméra orthographique : la direction de vue est la même partout, un reflet du soleil couvre
  donc toute l'eau d'un coup (d'où la rugosité de l'eau qui augmente à angle rasant).
- `return` est interdit dans `fragment()` : écraser les sorties à la fin (voir la roche en coupe).
- `ArrayMesh.shadow_mesh` est ignoré avec un shader qui déplace les sommets ou utilise `discard`
  (c'est le cas de `voxel.gdshader`) : pas d'ombres simplifiées par ce moyen.
- L'import (`--import`) et les lancements réécrivent `project.godot` (réglages par défaut retirés,
  sections déplacées) : avant un commit, repartir de la version du dépôt et n'y ajouter que les
  vrais changements.
- Fils de travail : le GDScript pur passe à l'échelle, mais les appels aux objets natifs (bruits
  `FastNoiseLite`…) et les allocations presque pas (×1,6 sur 12 fils) : bruits en bloc avec
  `get_image_3d`, pas d'allocation ni d'appel dans les boucles chaudes, tables statiques copiées
  en local. Les tâches « basse priorité » n'ont que 30 % des fils par défaut (porté à 75 % dans
  `project.godot`) ; la priorité haute affame le moteur (compilation des shaders).

---

## 5. Prochaine étape au « go » : Phase 4 — Craft

La phase 3 (joueur et interactions : monde en voxels, sauvegardes, miner et poser, objets et
inventaire, outils) est terminée : voir les lignes 3.1 à 3.5 de la section 3. Les bûches, minerais,
gemmes et plantes ne se posent pas encore (seuls les blocs se posent) : les planches et les blocs
fabriqués viennent avec le craft.

But de la phase 4 : fabriquer ses objets comme dans Minecraft, avec les décisions du propriétaire
(section 6 : **établi 5×5**, **four alimentaire** et **four d'usine**). Découpage proposé, **à
valider avec le propriétaire avant de commencer** (validé, avec la grille 3×3 et l'établi 5×5), une
étape par « go », chacune avec tests, captures, commit et retour :

1. ✅ **Recettes et grille 3×3** (voir section 3). Fait comme prévu ci-dessous ; Maj+clic sur le
   résultat en fait le plus possible. Le plan suivi : registre de recettes en données (avec forme, sans forme), grille
   3×3 dans l'inventaire (E) avec sa case de résultat, le serveur vérifie chaque fabrication ;
   premières recettes : bûche → planches, planches → bâtons, l'établi ; planches de chaque bois
   posables (nouveaux blocs, textures de `tools/gen_art.py`) ; les recettes s'affichent dans le
   chapitre « Fabrication » du livre du joueur (`GuideBook._craft`).
2. **Établi 5×5** (prochaine étape ; au lieu du 3×3 de Minecraft) : l'établi posé s'ouvre au clic droit sur une
   grille 5×5 ; recettes des outils (les 18 existent déjà, étape 3.5) et des blocs de construction.
3. **Usure des outils** : solidité par matériau (l'or rapide mais fragile), barre d'usure dans les
   cases, l'outil casse ; F7 reste une touche de debug (créatif plus tard).
4. **Coffres** : données de bloc côté serveur (un inventaire par coffre, sauvegardé avec la région),
   ouverture au clic droit, contenu répandu quand on le casse.
5. **Fours** : four alimentaire (nourriture seulement ; y fondre du minerai le casse, il devient
   inutilisable) et four d'usine (le reste ; de la nourriture y ressort carbonisée) ; combustible,
   cuisson et fonte au fil du temps (`WorldClock.scale_duration()`), lingots de cuivre, de fer et
   d'or.
6. **Blocs de construction** variés en voxels (planches, briques, verre, pierre taillée…).

## 6. Feuille de route détaillée (phases restantes)

### Phase 4 — Craft
- Recettes en données (forme et sans forme), grille 3×3 dans l'inventaire, **établi** 5×5.
- **Four alimentaire** : dédié à la nourriture (si du minerais est fondu dans ce four alors il se casse et deviens inutilisable), combustible, cuisson et fonte au fil du temps (durées adaptées au rythme du monde).
- **Four d'usine** : dédié aux recettes autres que la nourriture (si de la nourriture est placé dans ce four alors elle ressort carbonisée), combustible, cuisson et fonte au fil du temps (durées adaptées au rythme du monde).
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
- **Grottes** : réglages à affiner en jouant (taille des salles, fréquence des tunnels, lacs ;
  aucune entrée vers la surface pour l'instant : on descend en creusant ou avec Page ↓). La roche
  coupée montre encore de légères variations de gris (faces vues de dos à diverses profondeurs).
- **Ressenti sous terre** : grottes assez sombres (lanterne et lumière ambiante des grottes) ; à
  rééclairer si le propriétaire trouve que c'est trop.
- **1re personne** : à essayer en vrai (sensibilité de la souris, vitesse de la plongée, hauteur
  des yeux). Limites connues : les textures (dessinées pour la vue de dessus, sans mipmaps)
  scintillent au loin en surface ; on voit le bord du monde chargé (6 chunks) dans la brume ; pas
  encore de mains ni d'objet tenu (étape 4) ; à la manette, X bascule la vue.
- **Le serveur ne vérifie pas encore les collisions** des déplacements (seulement la distance), ni
  la durée du minage (un client pourrait casser d'un coup) :
  utiliser `PlayerBody` côté serveur avant le multijoueur.
- **Carrés plus sombres dans l'herbe**, de la taille d'une tuile, visibles en montagne (déjà là
  avant la caméra basse) : origine à trouver (ombres, occlusion ambiante ?).
- À angle bas sur très grand écran, plus de terrain est visible : les modèles simplifiés arrivent
  plus tôt (zoom 2 sur 3440×1440). Pire cas mesuré : 961 chunks, 60 images/s sur la RTX 5050.
