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
   L'étape 7.3 (arrosage et soins) a été faite sur la branche `claude/serene-allen-q2ncn8`,
   partie du même commit (« Display settings ») : la fusionner dans la branche principale.
3. Copier-coller ce message pour démarrer :

   > Lis `CLAUDE.md` et `CLAUDE-README.md`, vérifie que le projet compile et que les tests
   > passent, puis résume-moi où on en est. Attends mon « go » avant de commencer la suite.

4. Dire **« go »** : Claude reprend à la **section 5** (phase 7 ; la phase 6 est en pause). Les phases suivantes se lancent
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
| Style (phase 5 et suite) | **Ne pas s'inspirer du style de Minecraft** : interface, présentation et mots à nous (jauge de vitalité au lieu des cœurs, « Tu as perdu connaissance… »), **monstres originaux** ; la logique de jeu reste à la Minecraft. |
| Plateformes | PC d'abord (installable, Steam/Epic un jour), puis **iOS et Android**. Graphismes poussés au maximum, en tirant parti de la carte graphique… sans la faire tourner à 100 % pour rien (limite d'images par seconde). |
| Graphismes | Claude crée tout lui-même, de façon procédurale (aucune ressource externe). |
| Joueurs | Solo d'abord, avec un code prêt pour le multijoueur (serveur intégré, messages). |
| Modes de jeu | **Créatif, Survie, Hardcore**, et le nouveau mode **Arcade** (phase 8, section 6). |
| Priorités | Explorer, construire, admirer, survivre, combattre. |
| Langues | Français et anglais, réglables dans le jeu. |
| Dépôt | Privé, compilation automatique par GitHub (Windows, Linux, macOS). |
| Temps | Durée d'une journée réglable **par monde** (5 à 120 min), réglage « **Synchroniser avec l'appareil** » (1 journée = 24 h, heure du jeu = heure de l'appareil), et temps figé. La faim, la cuisson, les cultures… s'adaptent **légèrement** : rythme = clamp((durée/20 min)^0,25 ; 0,7 ; 2,5), synchronisé = ×2,5. Rattrapage hors-ligne **seulement en mode synchronisé, limité à 1 journée de jeu**. |
| Caméra | Vue de dessus inclinée façon Stardew par défaut (60°, « pixel parfaite »), **orbite à la souris** autour du joueur (clic droit ou molette enfoncée), zoom à la molette en gardant le clic molette enfoncé (ou Ctrl+molette, +/-). On peut **baisser la caméra jusqu'à 15°** sans que les objets s'étirent : les hauteurs gardent leur taille à l'écran, le sol se resserre, et près de l'horizon on retrouve les vraies proportions (un cube est un cube). **1re personne automatique en entrant dans une grotte** (réglage désactivable dans le menu pause) et **à tout moment avec V** (F5 jusqu'à la phase 6 ; C maintenu zoome en 1re personne), avec une **plongée** de la caméra dans la tête du joueur ; V vaut jusqu'à la prochaine entrée ou sortie de grotte. |
| Déplacements | **Pas d'escaliers générés** : le joueur **saute d'un bloc** (1,25 niveau, comme Minecraft), tombe des bords. |
| Monde | **Vrais voxels 3D** comme Minecraft (choix de la phase 3) : chunks de 16×16 colonnes sur **128 blocs de haut** (64 sous le niveau de la mer, le relief jusqu'à +32, de la place pour construire au-dessus). Grottes 3D sous la surface, plus de « couches » séparées. L'eau et la lave **coulent** quand on ouvre une poche (phase 6, ligne 6.3) ; on y nage (phase 5). |
| Eau | **Transparente** : on voit le fond, de moins en moins avec la profondeur (pour voir plus tard les poissons nager, pêcher, admirer la végétation sous-marine), avec une **ondulation du fond** et des reflets dansants. Limpidité par type : eaux chaudes tropicales très claires (~10 blocs), rivières et lacs clairs (~6), océans plus bleus (~4-5), marais troubles (1-2). Lave et glace restent opaques. |
| Sous terre | **Vue en coupe** : dès qu'il y a un plafond au-dessus du joueur (grotte, galerie, toit), tout ce qui dépasse sa tête est coupé, la roche coupée s'affiche en sombre. |
| Arbres, plantes | Restent des **modèles voxel détaillés** posés dans une case (pas des troncs en blocs) : miner le pied abattra l'arbre entier. Arbres **grands, épais et tous différents** (8 versions par espèce, troncs de hauteurs et d'épaisseurs variées), **réalistes en restant en pixel art** (1 voxel = 1 pixel : troncs penchés sur racines, branches fourchues, grappes de feuilles éclairées, écorce sillonnée, mousse). **Seul le tronc bloque**, et jamais deux objets solides côte à côte : on passe toujours entre les arbres. |
| Sauvegardes | **Dès la phase 3** (fait) : chunks modifiés + joueur, sauvegarde auto toutes les 2 min, en ouvrant le menu pause et à la fermeture (« Monde sauvegardé » s'affiche sous l'horloge) ; un seul monde en attendant l'écran titre. |
| Contrôles (phase 3) | Clic gauche maintenu = miner, clic droit court = poser, clic droit glissé = tourner la caméra ; **molette = objet en main** (zoom en vue de dessus : molette en gardant le clic molette enfoncé, ou Ctrl+molette, et +/-), touches 1 à 9 ; manette : gâchettes miner/poser, LB/RB changer d'objet ; F7 (debug) : outils. |
| Outils avant le craft | **Tout se mine à la main** (lentement, chaque bloc donne quelque chose) ; les outils (pioche, hache, pelle, en 6 matériaux) minent plus vite ce pour quoi ils sont faits ; en attendant le craft (phase 4), **F7** (debug) donne les outils du matériau suivant. Fait à l'étape 3.5 (vitesses de Minecraft, temps de minage en temps réel, pas adapté au rythme du monde). |
| Livre du joueur | Une **10e case** à part, à droite de la barre (les 9 restent centrées), tient un **livre ancré** : on ne peut ni le jeter ni le déplacer. 0 le prend en main (0 encore, ou clic droit, l'ouvre) ; il montre les touches (celles du clavier du joueur : ZQSD en AZERTY), la manette, des astuces, les outils et bientôt les recettes. Se désactive dans le menu pause (activé par défaut). |
| Établi | **Modèle voxel sur 2 cases**, d'après la photo d'un établi de menuisier en hêtre envoyée par le propriétaire : plateau épais en lamelles, étau à gauche, étagère ouverte sous le plateau, 4 petits tiroirs, 2 grands et une porte à charnières, pieds en traîneau ; dessus, des détails du jeu : une petite enclume, un marteau et une scie en fer. Il se pose face au joueur. |
| Craft | Recettes comme Minecraft : une forme placée n'importe où dans la grille (en miroir aussi) ou sans forme, ingrédients d'un même groupe interchangeables (n'importe quelles planches). **Grille 3×3 dans l'inventaire (E)**, **établi 5×5** (clic droit dessus). Les outils se font à l'établi, avec **les formes classiques de Minecraft** ; la grille 5×5 est prévue pour de futurs objets plus grands. Clic sur le résultat pour le prendre, Maj+clic pour en faire le plus possible ; ce qui reste dans la grille revient dans le sac à la fermeture. Les recettes s'affichent dans le livre du joueur. |
| Chargement | Tout ce qui est visible doit être chargé, même dézoomé au maximum sur l'écran ultra-large du propriétaire (3440×1440, fenêtré). Carte graphique du propriétaire : NVIDIA GeForce RTX 5050 (8 Go). |

---

## 3. État actuel : ce qui est fait

Godot **4.7.2** (GDScript), rendu Forward+. 259 tests unitaires, lint propre.

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
| 4.1b Établi en modèle | L'établi devient un modèle voxel de 2 cases (`WorkbenchModel` : établi de menuisier en hêtre, étau, tiroirs, porte, enclume, marteau et scie en fer dessus), posé face au joueur (4 orientations : `WORKBENCH`, `_WEST`, `_NORTH`, `_EAST`, plus son autre bout `WORKBENCH_END_X/_Z` sans modèle) sur la case visée et celle de sa droite (sinon de sa gauche), libres et posées sur des cubes (`Mining.placement`) ; casser un bout casse tout l'établi et rend un établi (`Mining.object_cells`) ; collisions sur les deux cases, cadre de visée autour de l'établi entier ; icône, objet en main et au sol avec le même modèle ; sa texture de cube est retirée des atlas | `97dc394` |
| 4.2 Établi 5×5 | Clic droit sur un établi posé (n'importe quel bout ; à la manette, gâchette gauche) : l'écran « Établi » avec la grille 5×5 (`InventoryScreen.open(width)`), le serveur l'accepte si l'établi est à portée (`Msg.OPEN_WORKBENCH`, `PlayerSession.craft_width` jusqu'à la fermeture) ; recettes des 18 outils aux formes classiques de Minecraft, seulement à l'établi (planches, n'importe quelle pierre, lingots de cuivre/fer/or, diamants ; bâtons) ; lingots de cuivre, de fer et d'or (objets en voxels, pas encore fabricables : le four viendra à l'étape 5) ; grès (4 sable) et glace compacte (9 glace) ; le livre classe les recettes (inventaire, puis « À l'établi », une entrée par sorte d'outil qui fait défiler les matériaux) ; `--grid` par lignes | `600a254` |
| 4.3 Usure des outils | Solidité de Minecraft par matériau (bois 59 blocs, pierre 131, cuivre 190, fer 250, or 32, diamant 1561 : l'or rapide mais fragile) ; chaque bloc cassé (sauf ce qui part d'un coup, les plantes) use l'outil en main, qui se casse quand il est usé (éclats de sa tête, « Pioche en fer cassée ! » au-dessus de la barre) ; l'usure suit l'outil partout (déplacé, lancé, ramassé, sauvegardé) ; barre d'usure verte → rouge sous l'icône ; le livre donne la vitesse et la solidité de chaque matériau | `05b81e3` |
| 4.4 Coffres | Coffre en voxels (planches, coins et cerclage de fer, serrure dorée), recette de Minecraft (8 planches en anneau), posé face au joueur ; clic droit : l'écran « Coffre » (ses 27 cases au-dessus du sac), clics et Maj+clic comme dans Minecraft (l'usure des outils suit) ; le contenu est gardé par le serveur dans le chunk (`ChunkData.chests`) et sauvegardé avec la région ; tous ceux qui l'ont ouvert voient ses changements ; cassé, il répand son contenu et rend un coffre | `1a19fe4` |
| 4.5 Fours | **Four alimentaire** (un four à pain en voxels : dôme de briques d'argile sur un socle de pierres, bouche voûtée, cheminée, une miche sur le rebord ; 8 pierres) : baies → baies déshydratées, champignons → ragoût de champignons ; du minerai fondu dedans le **casse** (four cassé inutilisable, qui rend des pierres ; le minerai est perdu, le reste se répand, « Le four alimentaire s'est cassé… » annoncé). **Four d'usine** (briques sombres cerclées de fer, porte à grille, tuyau de poêle ; 8 pierres autour d'un charbon, à l'établi) : minerais → lingots de cuivre, fer, or ; bûches → charbon de bois ; la nourriture ressort **carbonisée**. Combustibles (charbon et charbon de bois 8 objets, bois 1,5, bâton 0,5) ; 10 s par objet via `WorldClock.scale_duration()` ; feu allumé visible (le bloc passe en version allumée : feu lumineux, lumière autour) ; écran du four (ce qui cuit, flamme qui baisse, combustible, flèche qui se remplit, résultat), Maj+clic range au bon endroit ; état gardé par le serveur dans le chunk et sauvegardé ; chapitre « Fours » du livre | `6d87955` |
| 4.5b Noms au survol | Le nom de l'objet sous le pointeur s'affiche à côté de lui (cadre sombre, texte traduit), dans l'inventaire (toutes les cases : sac, barre, livre, grille et résultat, coffre, four ; masqué quand on tient une pile) et dans le livre (cases des recettes, icônes des outils et des combustibles) | `b93c1e1` |
| 4.5c Cadre de visée fin | En 1re personne, le cadre autour du bloc ou de l'objet visé fait environ 2 pixels d'écran quelle que soit la distance (au moins un texel de la vue) au lieu d'un pixel du dessin (énorme de près) ; vue de dessus inchangé (un pixel du dessin) | `5032583` |
| 4.5d Monter sur les meubles | On ne passe plus au travers de l'établi, des coffres et des fours en sautant dessus : on se tient sur leur dessus, à la hauteur de leur modèle (établi 15/16, coffre 13/16, fours 14/16 : `ObjectShapes.TOPS`), et on en redescend ou on monte de là sur un bloc sans sauter ; les objets lâchés s'y posent aussi ; un joueur sauvegardé debout sur un meuble y revient | `165221b` |
| 4.5e Glisser au clic droit | Comme dans Minecraft : avec une pile au curseur, maintenir le clic droit et bouger la souris pose un objet dans chaque case survolée (une fois par case et par glissé ; les cases qui ne l'acceptent pas sont sautées), dans le sac, la barre, la grille de fabrication (inventaire et établi), les coffres et les fours (entrée et combustible) | `2cdbe29` |
| 4.5f Glisser au clic gauche | Comme dans Minecraft : avec une pile au curseur, maintenir le clic gauche et passer sur des cases répartit la pile à parts égales entre elles (le reste de la division reste en main ; pas plus de cases que d'objets ; les cases qui ne l'acceptent pas sont sautées), l'aperçu se met à jour pendant le glissé et le serveur reçoit la répartition au relâchement (`Inventory.spread`, `Msg.SLOT_SPREAD`) ; appuyer et relâcher sur une seule case reste un clic normal ; mêmes endroits que le glissé au clic droit ; le nom de l'objet survolé se cache pendant un glissé | `bef6cf1` |
| 4.6 Blocs de construction | Six blocs cubes à poser, textures pixel art de `gen_art.py` : **briques de pierre** (4 pierres → 4), **briques d'ardoise des abîmes** (4 ardoises → 4), **grès taillé** (4 grès → 4), **briques** (4 briques → 1 ; la brique sort du four d'usine à partir de boue), **pierre lisse** (pierre au four d'usine), **verre** (sable ou sable rouge au four d'usine) ; le verre est **transparent** (cadre et reflets opaques, le reste découpé : on voit le sol, les fleurs et les blocs derrière, vue de dessus comme en 1re personne, la lumière passe ; deux vitres collées ne montrent pas de face entre elles), il casse vite ; icônes en cubes (le verre transparent) ; tous à la pioche ; recettes dans le livre ; poser en visant une petite plante la remplace (comme dans Minecraft) | `faa28b1` |
| 4.7 Tab et E | **Tab** ouvre l'inventaire (et le ferme) ; **E** (B à la manette) utilise le bloc visé : ouvre l'établi, un coffre, un four (E, Tab ou Échap referment) ; le clic droit ne sert plus qu'à poser un bloc (et ouvrir le livre en main) ; le livre nomme les touches comme elles sont réglées (`{use}`, `{inventory}` dans les textes) | `3edfdb0` |
| 5.1 Vitalité et dégâts | 20 points de vitalité gardés par le serveur et sauvegardés, une **jauge** à nous au-dessus de la moitié gauche de la barre (cristal de vie, cadre de bois, crans tous les 2 points, la part perdue reste pâle un instant puis fond, la jauge bat quand il reste peu) ; **chutes** : au-delà de 3 niveaux, un point par niveau, mesurées depuis le plus haut du saut, **rien si l'on atterrit dans l'eau** ; **lave** : on peut y entrer (lente), elle brûle 2 points toutes les ½ s ; le corps rougit et les bords de l'écran palpitent en rouge ; la vitalité revient doucement (un point toutes les 4 s après 6 s sans blessure, au rythme du monde) ; à 0, **« Tu as perdu connaissance… »** : le monde s'assombrit, la cause est dite, ce que l'on portait reste sur place, le corps s'allonge, bouton « Se relever » (au point d'apparition) ; rien en mode créatif ; astuce dans le livre | `35f8b03` |
| 5.1b Outils droits | Les outils sont tenus **droits** au lieu d'à plat : sur le corps, manche levé, tournés de 45° autour du manche (lisibles de face, de profil et de dos) ; en 1re personne, droits en bas à droite, tournés pour montrer leur épaisseur ; la lanterne passe dans la main gauche (elle n'éblouit plus l'outil) ; l'objet en main ne projette plus d'**ombre géante** à la lumière de la lanterne (il est, comme le corps, hors de ses ombres ; le soleil et la lune gardent la leur) | `fb5e3cf` |
| 5.2 Faim et nourriture | **Jauge de satiété** à nous (ambrée, une petite miche, sur la moitié droite au-dessus de la barre ; elle bat quand on a faim) : 20 points qui baissent avec le temps (un point toutes les 50 s au rythme du monde), la marche et le minage ; **manger en maintenant le clic droit** (gâchette gauche à la manette) avec de la nourriture en main : le bras porte l'aliment à la bouche, des miettes volent, un aliment toutes les 1,4 s (« Tu n'as pas faim. » si l'on est rassasié) ; ragoût +8, baies déshydratées +4, baies +2, champignons +1, nourriture carbonisée +1, **le champignon rouge cru rend malade** (-2 de vitalité) : cuisiner paie ; la vitalité ne revient que **bien nourri** (14 points et plus) et coûte un peu de satiété ; **affamé** (0), on perd un point de vitalité toutes les 6 s ; trop faible (moins de 4), on ne peut plus courir ; rien en créatif ; chapitre « Survie » du livre (jauges, comment manger, ce qui nourrit) | `97286ac` |
| 5.3 Nage et noyade | On ne marche plus sur l'eau : on **nage** (eau et lave) ; on coule doucement, **Saut maintenu** fait remonter et flotter la tête hors de l'eau, **contre une berge, Saut fait bondir dehors** ; plus lent dans l'eau (encore plus dans la lave) ; une chute dans l'eau ne blesse jamais ; **souffle** : 12 s la tête sous l'eau (petite jauge bleue avec une bulle au-dessus de la satiété, elle clignote presque vide), il revient vite à l'air libre ; ensuite on se **noie** (2 points par seconde, « Tu as manqué d'air. ») ; on voit le joueur sous l'eau vue de dessus (l'eau n'est pas un toit : pas de coupe ni de passage en 1re personne), voile bleuté en 1re personne sous l'eau, nage animée (bras et jambes), éclaboussure en entrant dans l'eau ; texte dans le chapitre « Survie » | `de4e9a0` |
| 5.3b Double-clic | Comme dans Minecraft : un **double-clic** sur une pile rassemble sur le curseur toutes les mêmes ressources éparpillées (grille de fabrication, coffre ou four ouvert, sac, barre ; les piles entamées d'abord, jusqu'à une pile pleine), vérifié par le serveur (`Inventory.collect`, `Msg.SLOT_COLLECT`) ; la gestion de l'écran d'inventaire passe dans `InventoryActions` | `5e7dde2` |
| 5.3c Murs coupés | Sous un toit, la vue de dessus coupe ce qui dépasse la tête : les **blocs de construction** coupés (planches, briques, pierre lisse, grès taillé, verre) montrent maintenant leur dessus à la coupe (un peu plus sombre, avec un liseré là où le mur tombe) au lieu d'un aplat gris-bleu ; la roche naturelle garde sa section sombre (grottes) | `a170ae5` |
| 5.3d Poutres coupées | Sous un toit, une **poutre ou un linteau** posé pile au niveau de la coupe (au-dessus d'ouvertures) cachait le plancher sous un aplat gris-bleu (ou des hachures) : le dessous de ce que la coupe enlève disparaît avec elle (`underside_cut`) ; les grottes au plafond bas y gagnent aussi (leur sol n'est plus caché) | `41860ef` |
| 5.4 Modes de jeu | **Créatif** : on **vole** (Saut deux fois vite ; Saut monte, Maj descend, toucher le sol fait atterrir ; 2,5 fois plus vite que la marche), les blocs posés ne s'épuisent pas, **tout se casse d'un coup** sans rien donner (une courte pause entre deux), les outils ne s'usent pas, ni dégâts ni faim (pas de jauges), un **catalogue** de tous les objets dans l'inventaire (Tab ; à la place de la grille 3×3 : blocs, puis objets posés, matériaux, nourriture, outils ; clic : une pile, clic droit : un objet, Maj + clic : une pile dans le sac, cliquer avec autre chose en main le jette ; molette ou barre pour défiler), et les **outils de debug** (carte, Page ↑/↓, F4, F6, F7) réservés à ce mode (refusés par le serveur ailleurs) ; **Survie** inchangée ; **Hardcore** : une seule vie, perdre connaissance met fin à l'aventure (« Ton aventure s'achève… », bouton « Regarder le monde ») et l'on ne fait plus que **regarder le monde en spectateur** (fantôme invisible qui vole à travers tout, sans barre ni jauges, une ligne en bas de l'écran ; sauvegardé : on revient spectateur) ; choix du mode à la création (`--game-mode`) et dans le **menu pause** (« Mode de jeu » : Survie ⇄ Créatif, un monde Hardcore le reste) ; chapitre « Modes de jeu » du livre (les touches de debug y passent), onglets du livre ajustés à leur nom | `67be9e4` |
| 5.5 Premiers animaux | Quatre espèces en voxel animé, à notre façon : **mouton** (toison crème bouclée, tête sombre ; plaines, prairies, bosquets), **sanglier** (sombre, crinière, défenses ; forêts, forêts sombres, marais), **poule sauvage** (coq de jungle roux, queue vert sombre, crête ; plaines, savanes, jungles) et **cerf** (fauve, croupe blanche, les mâles portent des bois ; forêts, bois de bouleaux, taïgas, prairies). **Gérés par le serveur** et synchronisés (`Msg.ENTITY_*`) : chaque chunk reçoit son troupeau (ou rien) la première fois qu'il est chargé, le même pour une graine, jamais dans un chunk où l'on a construit ; ils vivent à moins de 3 chunks d'un joueur (la moitié à chaque tick) et sont **sauvegardés** (`creatures.cfg`). Ils broutent (la tête baissée), se promènent par des **chemins** (A* : un niveau à la fois en montant, trois au plus en descendant, jamais dans l'eau ni la lave), nagent s'ils y tombent. **On les frappe** au clic gauche (une hache frappe le plus fort, une main 1) : ils rougissent, sont repoussés, **s'enfuient avec leur troupeau** ; morts, ils basculent, s'effacent en touffes et laissent **laine, viandes, plumes, peaux**. Viandes à **rôtir au four alimentaire** (gigot, rôti de sanglier, poulet rôti, steak de cerf ; le poulet cru rend malade), **bloc de laine** pour construire ; chapitre « Animaux » du livre, l'animal visé à l'écran F3, `--animals=sheep:3,...` pour en amener autour du joueur | `4e68d2a` |
| 5.5b Pluie | La pluie (et la neige) **ne traverse plus les blocs** : chaque goutte s'arrête sur le premier obstacle vu du ciel (toit, feuillage), grâce à un relevé de hauteur des alentours redessiné quand on se déplace ou que des blocs changent ; gouttes **plus fines** en 1re personne et en rendu HD (vue de dessus normale : un pixel d'art) ; coût non mesurable | `708ce82` |
| 5.6 Monstres | Quatre monstres à nous, en voxel animé : la **Phalène-lanterne** (grandes ailes pâles aux ocelles lumineux ; dehors la nuit, elle tourne autour du joueur et fonce sur lui : son coup **éteint la lanterne** 8 s), le **Rôdeur d'ombre** (silhouette voûtée aux yeux pâles ; dehors la nuit et dans les grottes, il approche dans le noir, **se fige et pâlit à la lumière** — lave, four allumé, jour — et fond au jour), le **Faux-rocher** (rocher moussu des grottes, **endormi** jusqu'à ce qu'on passe près de lui ou qu'on le frappe : il bondit sur six pattes, yeux ambrés et gueule dentée, et se rendort seul) et le **Feu follet** (orbe vert qui éclaire autour de lui ; au-dessus des marais la nuit, il **recule pour attirer** puis fonce brûler). Ils sortent autour des joueurs qu'ils peuvent chasser (jamais en créatif ni pour un spectateur), un à la fois, à 16-32 cases, là où il fait noir (lumière calculée par le serveur : ciel ouvert le jour, lave et feux à 4 cases), 6 au plus autour d'un joueur ; ils partent au loin (64 cases) ou fondent au jour à découvert ; jamais sauvegardés. Leurs coups font perdre de la vitalité (causes à eux : « Ce rocher n'en était pas un. »…) et **repoussent le joueur** ; on les frappe comme les animaux ; ils laissent poudre de phalène, essence d'ombre, pierres et fer, ou une **braise de follet**, combustible qui brûle 200 s. Base commune `Creature` (animaux et monstres), chapitre « Monstres » du livre | `8bebacb` |
| 5.7 Combat et armures | **Épées** des 6 matériaux à l'établi (bois 4 points par coup, pierre 5, cuivre 5, fer 6, or 4, diamant 7 ; la hache frappe presque aussi fort) ; chaque coup **repousse** ce qu'il touche, qui reste **invulnérable un instant** ; **arc et flèches** (ficelle filée de la laine, flèche : pointe de pierre, bâton, plume ; arc à l'établi) : **maintenir le clic droit** (gâchette gauche) bande l'arc, une jauge au-dessus de la tête se remplit, les bras se lèvent et l'arc vient en travers de la poitrine ; relâcher tire : plus l'arc est bandé, plus la flèche va loin et frappe fort ; elle suit une **trajectoire en cloche** qui retombe là où pointe la souris (au centre d'une créature visée), le long du viseur en 1re personne (l'arc s'y redresse) ; la flèche est gérée par le serveur (même vol partout), blesse la créature traversée ou **se plante** là où elle tombe (à ramasser) ; une flèche par tir, l'arc s'use (rien en créatif) ; **armures** casque, plastron, jambières, bottes en **peau**, cuivre, fer, or et diamant, à l'établi (formes de Minecraft) : portées en voxel sur le corps (coques autour de la tête, du torse et des épaules, des jambes, des pieds), **quatre cases d'armure** sous le titre de l'inventaire (silhouette de la pièce quand la case est vide, Maj + clic pour enfiler) avec un bouclier qui compte les points ; chaque point retire 4 % des coups des **monstres** (80 % au plus ; ni chutes, ni lave, ni noyade, ni faim), chaque coup reçu use toutes les pièces, perdues en perdant connaissance ; jauge d'acier au-dessus de la vitalité ; icônes d'armure en silhouettes plates ; chapitre « Combat » du livre, dont les **onglets passent sur le bord droit** (onze chapitres ne tenaient plus en haut) | `f918c89` |
| 5.7b Maisons vues de dehors | Les **pièces d'une maison se voient de dehors** à travers ses fenêtres et sa porte (plancher, murs intérieurs, meubles) au lieu d'un trou bleu-gris : un toit ou un plancher en blocs de construction ne fait plus de ce qui est dessous une « grotte » cachée tant qu'on est dehors, seules deux couches de roche naturelle d'affilée le font ; sous un toit, la **visée passe à travers ce que la vue coupe** (le toit, ce qui se tient dessus) : on vise, casse, pose et ouvre (coffres, fours, établi) le plancher et les meubles en 3e personne | `db8594d` |
| 5.7c Coupe limitée à la maison | Sous un toit, la vue ne coupe plus **que la maison** où l'on se trouve (la pièce reliée au joueur et ses murs, trouvée de proche en proche, masque envoyé aux shaders) : dehors, les **montagnes et le feuillage des arbres restent** ; sous la roche (grottes, tunnels) la coupe reste partout comme avant | `cfd6452` |
| 6.0 Maison et jardin | Douze nouveaux objets, avec leurs recettes : **support mural de torche** (fer ; il tiendra une torche à l'étape suivante) et **rideaux** (lin, tirés de chaque côté) qui **s'accrochent au mur** (on vise le côté d'un bloc ; ils tombent avec lui), **fenêtre** (bloc vitré à cadre en bois, on voit au travers), **vitre** (plaque fine), **évier** (placard, bac en pierre avec de l'eau, robinet), **toilettes**, **table** et **chaise** (en noyer, on peut monter dessus), **barrière** (elle se raccorde aux barrières, portails et blocs voisins ; personne ne saute par-dessus, les animaux restent dans leur enclos), **portillon** et **portail** sur deux cases (battants cintrés, ferrures), qui **s'ouvrent et se ferment avec E** (pas sur quelqu'un), **feu de camp** (pierres, bûches, flammes qui s'éclairent elles-mêmes ; il éclaire et tient les monstres à distance) ; chapitre « Maison et jardin » du livre ; les objets accrochés en hauteur s'affichent (`ChunkData.raised`) | `6266452` |
| 6.0b Identifiants élargis | Les voxels passent d'un octet (191 sortes de blocs au plus, dont 61 libres) à **16 bits : des dizaines de milliers de sortes de blocs**, orientations et stades de culture compris ; les textures de cubes passent de 31 à **255**, les sols de 32 à 64 dans les shaders ; même vitesse de génération et de maillage (mesurée), un peu plus de mémoire (environ +10 Mo à la distance de vue par défaut) ; les mondes déjà sauvegardés se chargent tels quels et sont réécrits au nouveau format quand un chunk change (vérifié sur une copie du monde du propriétaire) | `b87d49c` |
| 6.1 Torches et lanternes | **Torche** (charbon ou charbon de bois sur un bâton → 4) posée **au sol** ou **dans un support mural** (on vise le support vide, la torche en main ; jamais directement contre un mur), **lanterne** (une torche entre deux lingots de fer) **au sol, au mur** (sur un bras en fer) ou **suspendue au plafond** par une chaîne : on vise le dessous d'un bloc en 1re personne, ou **le sol avec Maj** en vue de dessus (la caméra ne voit jamais le dessous d'un plafond) ; elles **éclairent** (couleur et intensité à elles, les flammes **vacillent**, les lanternes à peine) et **tiennent les monstres à distance** ; une lanterne suspendue tombe avec son plafond, pas avec le sol ; un support allumé rend support et torche ; ce qui ne bloque pas se pose même là où l'on se tient ; les objets posés par le joueur ne sont plus remplacés comme une plante quand on pose un bloc dessus ; section « Lumières » du chapitre Maison et jardin | `31299f3` |
| 6.2 Lumière des grottes | Un **niveau de lumière** de 0 à 15 (`LightField`, partagé) : le **jour descend** jusqu'au premier cube (le verre et les fenêtres le laissent passer, l'eau l'atténue), puis **entre par les ouvertures** en perdant un niveau par case ; le rendu le cuit dans chaque face et chaque objet : **sans lumière, une grotte ou une pièce fermée est noire**, seules la lanterne, les torches, les feux, la lave et les minerais brillants éclairent ; le joueur et les créatures s'assombrissent dans le noir ; la **lanterne** s'allume selon la lumière où l'on se tient et, en vue de dessus sous un plafond, pend sous le plafond (avant, elle flottait dans la roche) ; le **serveur** mesure la lumière d'une case (ciel le jour, faible la nuit, torches, lanternes, feux, fours, lave ; jamais la lanterne du joueur) : les **monstres ne sortent que là où elle est sous 7**, le rôdeur se fige au-dessus ; textes du livre mis à jour | `49e3562` |
| 6.3 Coulées d'eau et de lave | L'eau et la lave du monde **restent immobiles jusqu'à ce qu'on touche à côté** ; alors elles **s'écoulent** (`Fluids`, serveur) : l'eau un pas tous les quarts de seconde, à **4 cases** sur le plat, la lave toutes les 1,5 s, à **2 cases**, en baissant d'un niveau par case (la surface descend par pixels), et toutes deux **tombent** à chaque à-pic (cascades) puis repartent en bas ; coupées de leur source elles **sèchent** ; deux sources d'eau côte à côte en remplissent une troisième ; elles noient l'herbe et les fleurs mais pas ce qu'on a posé ; un bloc posé en travers les arrête ; **eau + lave = pierre** ; on marche dans une coulée mince et on nage dans l'eau profonde ; casser un bloc à côté de l'eau ne la remplit plus d'un coup : elle coule dedans ; rendu : surfaces abaissées, **cascades** (côtés de l'eau en filets qui descendent, lave qui coule) ; la lave brille par elle-même (plus blanche en plein soleil) ; astuce 16 du livre | `fba46bf` |
| 7.0 Touches V et C | La 1re personne se bascule avec **V** (au lieu de F5) ; **C maintenu** zoome en 1re personne (70° → 20°, en douceur ; le regard tourne moins vite, l'objet en main se baisse) ; les deux touches dans la page Touches du livre | `9853880` |
| 7.1 Végétation qui pousse | Le moteur de croissance du serveur (`Growth`) : un arbre abattu donne **une ou deux pousses** de son espèce (7 espèces), plantées dans l'herbe ou la terre (pas dans l'eau) ; à la lumière (le jour, ou près d'une torche ou d'une lanterne ; la nuit et le noir les arrêtent) elles deviennent de **jeunes arbres** (modèles à eux : petit tronc, petite couronne) puis des **arbres**, s'il y a la place au-dessus et qu'aucun rocher ni arbre n'est juste à côté ; un épicéa qui grandit dans la neige sort enneigé ; un jeune arbre abattu rend sa pousse ; la **terre nue reverdit** à côté de l'herbe (trous creusés, terre posée) ; durées adaptées au rythme du monde (une pousse devient un arbre en un jour de jeu environ) ; chapitre « La ferme » du livre ; corrigé au passage : l'inventaire ouvert dans les toutes premières secondes faisait planter le jeu | `29087df` |
| 7.2 Houe, champs, graines | **Houe** (6 matériaux, à l'établi) : clic droit sur l'herbe ou la terre → **terre labourée** (l'herbe haute dessus s'en va), **humide et sombre à moins de 4 pas de l'eau** (même rangée ou une au-dessus), sèche sinon ; sèche et sans rien de semé, elle **redevient de la terre** au bout d'un moment ; **graines de blé** (hautes herbes), **carottes** et **pommes de terre** (parfois dans les hautes herbes) semées sur la terre labourée seulement ; **4 stades visibles** (blé du vert au doré, collets orange des carottes, pommes de terre en fleur), à la lumière, **plus vite sur une terre humide** (3 fois plus lent au sec) ; mûre, une culture donne sa récolte (blé + graines, 2 à 4 carottes ou pommes de terre), trop tôt seulement sa graine ; **3 blés → pâte à pain**, le **four alimentaire** la cuit en **pain** et les pommes de terre en **pommes de terre cuites** ; carottes et pommes de terre se mangent (clic droit maintenu) sauf quand on vise une terre labourée (on sème) ; livre : Outils (houe) et Ferme (Champs) | `31d442e` |
| 7.2b Correctif : poser des blocs | On ne pouvait plus poser de blocs dans une bande de niveaux (-1 à 4 chez le propriétaire) : des **animaux « perdus »** (un sanglier…) avaient une position NaN (un pas de chemin divisé par une distance nulle quand le point suivant était pile au-dessus d'eux), et une position NaN « chevauche » toutes les cases du monde à sa hauteur ; la division est corrigée, un pas qui casserait la position la remet où elle était, et les créatures sauvegardées perdues sont écartées au chargement (3 dans le monde du propriétaire) ; c'était aussi la cause des erreurs « transform non fini » | `37d8ae3` |
| 7.2c Ciel | Le ciel en **1re personne** (la vue de dessus ne voit jamais le ciel, seulement l'ombre des nuages au sol) : dégradé de l'horizon (la couleur de la brume) au zénith, **levers et couchers** (lueur orange vers le soleil, rose autour, bande rose à l'opposé), **soleil** (disque et halos en paliers, plus grand et plus rouge bas sur l'horizon, qui se couche vraiment sous l'horizon), **lune dans sa phase** (pleine, croissants, demi ; mers sombres ; nette au zoom C), **étoiles** qui tournent avec la nuit et scintillent, **voie lactée**, **nuages** pixel (le même bruit, la même échelle et la même dérive que leurs ombres au sol), éclairés du côté du soleil, pêche au couchant, sombres la nuit, gris sous la pluie ; coût mesuré : +0,07 ms par image en HD ; corrigé au passage : les particules (feuilles éclairées par la lanterne, lucioles) collées à l'œil en 1re personne remplissaient l'écran | `65ecad3` |
| 7.2d Réglages d'affichage | Menu pause en trois sections (**Affichage**, **Graphismes**, **Jeu**) : **mode d'affichage** (fenêtré, plein écran sans bords à la résolution de l'écran, plein écran exclusif), **écran** (s'il y en a plusieurs), **résolution** de la fenêtre (tailles qui tiennent dans l'écran, centrée), **synchro verticale** (activée, désactivée, adaptative), **images par seconde max** (30, 60, **100**, 120, 144, 165, 240, fréquence de l'écran, illimitées), **compteur d'images**, **distance de vue en 1re personne** (4 à 12 chunks, la brume suit), **luminosité**, **taille de l'interface**, **champ de vision** (60° à 110°) et **sensibilité de la souris** en 1re personne ; un jeu ne peut pas changer la fréquence (Hz) ni la résolution de l'écran lui-même (c'est Windows) : l'écran du propriétaire est détecté à 100 Hz | `1f9e133` |
| 7.3 Arrosage et soins | **Arrosoir** en cuivre (5 lingots) : clic droit en visant l'eau (même qui coule) ou un **évier** pour le remplir (20 cases d'eau, jauge bleue sous son icône), puis clic droit sur une terre labourée (ou la culture dessus) : elle devient **humide un quart de journée** (au rythme du monde), même loin de l'eau ; vide, « L'arrosoir est vide » ; rien ne s'use en créatif. La **pluie arrose** les champs à ciel ouvert (pas sous un toit ni sous le verre), qui restent humides un moment après. Les **rigoles** d'eau qui coule irriguent comme l'eau dormante (4 cases). **Composteur** (7 planches, caisse à claire-voie) : clic droit ou E avec un déchet végétal (graines, fleurs, pousses, récoltes, pain, nourriture carbonisée…) le remplit d'un niveau, visible entre les planches ; plein (7), il se change en **compost** en une minute environ (même dans le noir), qu'on sort de la même façon ; cassé prêt, il rend aussi son compost. Le **compost** sur une culture ou une pousse la fait **grandir d'un stade** tout de suite (un arbre a toujours besoin de place). Cultures **sous serre** (le jour passe le verre) et **à la lanterne** sous terre vérifiées par les tests ; section « Arrosage et soins » du chapitre La ferme | `9ff8129` |
| 7.4 Plus de cultures | **Plantes sauvages** pour trouver les premières graines, selon les biomes (betteraves, choux et lin dans les plaines et prairies, choux sur les plages, fraises et vignes en forêt, maïs en savane, tomates et pastèques en jungle, citrouilles en plaine, forêt et taïga, riz sur les marais et les rivières ; elles ne prennent que des cases vides : le reste du monde ne bouge pas) ; **semées sur terre labourée**, 4 stades chacune : betterave, chou, maïs (un épi), tomate (sur tuteur), fraise, lin, citrouille et pastèque, dont la **tige pose son fruit sur une case libre à côté** (et un autre une fois pris ; une pastèque se casse en tranches) ; **riz** semé en visant l'eau dormante d'un seul niveau (rizière) ; **canne à sucre** plantée sur la terre ou le sable au bord de l'eau, qui **repousse une fois coupée** ; **vigne** sur un **treillis** (7 bâtons → 2) ; **cueillette** (clic droit ou E) des tomates, fraises, raisin, canne et fruits : dans le sac, la plante mûrit de nouveau ; **arbres fruitiers** (pommier, cerisier rose en fleur, oranger) à la place d'une partie des chênes, bouleaux, acacias et arbres de jungle selon les biomes, **en fleur puis en fruits**, cueillis puis refleurissent, pépins (grille) → nouvel arbre ; **sucre** (canne ou betterave), **ficelle** et **toile de lin** (rideaux), maïs grillé et riz cuit au four ; tout se composte ; sections « Autres cultures » et « Arbres fruitiers » du chapitre La ferme | `081bd85` |
| 7.4b Framboises et pêches | Demandées par le propriétaire : **framboisiers** semés d'une framboise sur terre labourée (4 stades : cannes, fleurs blanches, framboises), **cueillis** encore et encore ; **framboisiers sauvages** dans les forêts et les taïgas ; **pêchers** (rose vif en fleur, pêches orangé pâle rougies au soleil) parmi les chênes des plaines et des forêts fleuries et les acacias des savanes, cueillis puis refleurissent ; une pêche donne un **noyau** qui fait pousser un pêcher ; framboises et pêches se mangent et se compostent ; le livre en parle | `5b87f76` |
| 7.5 Élevage | **Nourrir** (clic droit) deux bêtes adultes de la même espèce avec ce qu'elles aiment (moutons : blé, chou ; sangliers : carottes, pommes de terre, betteraves, pommes ; poules : graines, riz, maïs ; cerfs : pommes, chou, carottes) : elles se cherchent (des bulles roses) et un **petit** naît, plus petit, qui **grandit** en une journée environ (plus vite nourri) ; **corde** (4 ficelles → 2) : la bête suit son joueur (une corde dessinée jusqu'à la main), lâchée d'un autre clic droit, elle **casse** trop loin ; les **enclos** (barrières, portails) gardent le troupeau ; **cisailles** (2 lingots de fer) : la laine tombe, le mouton est tondu (peau visible) et elle repousse ; **seau** (3 lingots de fer) : du lait de brebis (seau de lait, se boit et rend le seau) ; **pondoir** (planches autour de blé) : les poules y pondent (jusqu'à 3 œufs, ramassés d'un clic droit ou E), sinon par terre ; **œuf au plat** au four ; **affection** (0 à 5) : une caresse et un repas par jour, une journée sans soins en retire un point ; aimées, les bêtes donnent plus (laine en plus, lait et œufs plus tôt, parfois deux œufs) ; **la nuit** elles dorment couchées, et celles qui t'aiment vont sous un **toit** proche (poulailler, étable : une nuit à l'abri compte comme un soin) ; un message dit ce qui se passe (affection, n'a pas faim, trop jeune…) ; section « Élevage » du chapitre Animaux. Vache et chèvre à l'étape suivante | `8e56361` |
| 7.5b Four d'usine à 4 cuissons | Demandé par le propriétaire : le four d'usine cuit **jusqu'à quatre variétés à la fois** sur un seul feu, qui brûle **d'autant plus vite** qu'il y a de cuissons (×1 à ×4) ; une sorte par cuisson ; à gauche un coffre **« À cuire »** (3 rangées de 6 : le four y prend tout seul une pile d'une sorte qu'aucune cuisson n'a, ou on la pose à la main dans une cuisson libre) et un coffre **« Combustible »** (2 rangées de 6), à droite un coffre **« Cuit »** (5 rangées de 6) où attend tout ce qui est cuit ; chaque cuisson a sa barre de progression, la flamme montre « ×N » ; Maj+clic depuis le sac range ce qui cuit et ce qui brûle ; les fours d'usine déjà posés gardent leur contenu (rangé dans les coffres) ; le four alimentaire ne change pas | `c3e2510` |
| 7.6 Animaux de ferme | **Vaches** (brunes tachées de blanc ; plaines, prairies, savanes) : lait au seau, cuir et bœuf ; **chèvres** (grises, cornes recourbées ; pentes enneigées, bosquets, sommets) : lait au seau ; **canards** (colverts ; rivières, marais) : ils **nagent** à travers l'eau en flottant dessus et pondent des œufs (pondoir ou par terre) ; **lapins** (forêts, taïgas, neige, désert) qui sautillent ; **cochons** : les petits des sangliers nés à la ferme sont des cochons roses (jamais dans la nature) ; chacun mange ce qui lui plaît et se reproduit comme à l'étape 7.5 ; viandes de bœuf, lapin, canard (crue, le canard rend malade) rôties au four. **Abeilles** : **nids sauvages** sur une souche dans les plaines, prairies et forêts fleuries, **ruche** (planches autour de rayons de miel) ; le jour, leurs abeilles sortent butiner les fleurs et les cultures autour, la ruche se remplit de miel (4 niveaux, d'autant plus vite qu'il y a de fleurs ; le miel coule le long de sa façade) ; pleine, un **bocal en verre** (3 verres → 3) donne un **pot de miel** (nourrissant, le bocal reste), des **cisailles** donnent 3 **rayons de miel** ; les cultures à 8 cases d'une ruche **poussent plus vite** (pollinisation) ; la nuit, les abeilles rentrent ; section « Abeilles » du livre | `8815bd7` |
| Chat et commandes | Demandés par le propriétaire : **T** ouvre le **chat** (en bas à gauche, au-dessus de la barre d'objets : les lignes s'effacent après 10 s ; en écrivant, un panneau de bois sombre, la molette remonte l'historique, les flèches rappellent ce qu'on a envoyé, Échap ferme, Entrée envoie) ; ce qu'on écrit passe par le serveur et va à tous les joueurs avec le nom de l'auteur ; **« / »** ouvre une **commande**, exécutée par le serveur, qui répond dans le chat dans la langue de chacun ; commandes en anglais ou en français, avec ou sans accents : pour tous **/aide** (/help), **/joueurs**, **/mp** (chuchoter), **/où**, **/graine** ; pour les **admins** **/tp** (hasard : un endroit sûr sur la terre ferme, à 600-3000 cases ; départ ; un joueur ; x z ; x niveau z ; ~ relatif), **/heure** (jour, midi, soir, nuit, minuit, 7h30, fige, reprend), **/météo** (beau, pluie, orage), **/mode** (survie, créatif), **/donne** (un objet nommé en français ou en anglais, ou par le début de son nom), **/invoque** (animaux et monstres, jusqu'à 10), **/soigne**, **/admin** (liste, ajoute, retire) ; la liste des admins est sauvegardée avec le monde, le premier joueur à y entrer (son créateur en solo) est admin ; chapitre « Commandes » du livre | `94bdcd3` |
| Clic molette, /vide, Tab | Demandés par le propriétaire : en **1re personne**, le **clic molette** sur un bloc le met en main ; en **créatif**, même sans l'avoir (une pile dans la barre rapide, ce qui occupait la case part dans le sac) ; en **survie/hardcore**, seulement si le joueur en a : la case de la barre rapide qui en contient est choisie, sinon la pile du sac vient dans la barre rapide (échangée), rien n'est créé ; les blocs orientés, allumés ou à un stade donnent leur objet (four allumé → four, blé qui pousse → graines) ; pas dans le livre. **/vide** (/clear, pour tous) vide l'inventaire (barre rapide, sac, grille, armure portée) ou un seul objet (`/vide pierre`). **Tab** complète dans le chat le nom d'une commande (dans la langue du joueur, sinon en anglais), son premier mot (jour, midi, beau, pluie, survie…), un objet ou une créature ; plusieurs possibilités : le début commun d'abord, puis chacune à son tour (Maj+Tab en arrière), la liste affichée au-dessus de la saisie | `1df94aa` |
| Clic droit = E | Demandé par le propriétaire : viser un établi, un coffre, un four ou un portail et faire un **clic droit** fait la même chose que **E** (ouvrir, ouvrir le portail), quel que soit l'objet en main (pas de pose de bloc, pas de repas, l'arc ne se tend pas) ; **Maj + clic droit** pose un bloc contre (comme dans Minecraft) ; le livre le dit | `a3ce779` |
| Économies et Extrême | Demandé par le propriétaire après des mesures sur son monde (jeu limité par le fil principal du processeur, carte graphique en attente) : en 1re personne, les chunks au-delà de la brume sont cachés (le zoom 1 en vue de dessus en gardait ~360 chargés) ; les petites plantes au loin ou très dézoomées ne projettent plus d'ombre ; les bêtes hors de l'écran ne sont plus animées, les minuscules une image sur deux (les petites sans ombre) ; la pousse des plantes est vérifiée chunk par chunk sur 5 s (plus d'à-coup toutes les 5 s) ; le zoom x1 apparaît dans le menu. Mesuré : 1re personne 47 → 111 FPS, vue de dessus zoom 1 45 → 72 FPS. Case **Extrême** (triangle « ! » bordeaux, ses pour et contre au survol) : tout au maximum (Ultra, HD, 12 chunks, détails deux fois plus loin) et aucune de ces économies ; les réglages du joueur reviennent quand elle est décochée | `1c06ca4` |
| 7.7 Animaux sauvages et ravageurs | **Loups** en meute (forêts, taïgas, bosquets, plaines enneigées) : ils chassent les moutons, lapins, poules, cerfs, canards, chèvres et cochons (la proie tuée est mangée, la meute rassasiée un moment ; les enclos protègent), **la nuit le joueur resté dans le noir** (une torche, une lanterne posée, un feu les tiennent à distance), et si on en frappe un **toute la meute se retourne** contre le joueur ; peaux. **Ours brun** (taïgas) : il **se dresse pour prévenir** quand on approche à 5 cases, **charge** si on reste 2,5 s, se défend durement, **dort la nuit** ; peau et bœuf. **Grenouilles** (marais, rivières) qui sautillent et nagent ; **tortues de mer** (plages) qui **pondent dans le sable** (un nid d'œufs qui se fendillent puis **éclosent** en petites tortues ; un œuf se ramasse et se repose sur le sable) ; **castors** (rivières, marais) qui **bâtissent un barrage** de branches et de boue dans l'eau calme près de la berge, morceau par morceau (on marche dessus ; cassé, des bâtons) ; **poissons** dans les rivières, mers et marais, toujours sous l'eau (poisson cru, grillé au four). Loups, ours et poissons restent **sauvages** (« ne se laisse pas apprivoiser »). Créatures à nous, autour des champs de 6 cultures ou plus : la **taupe** creuse sous le champ (la terre jaillit), **ronge les cultures par en dessous** (des **taupinières**), remonte un instant après chacune (seulement là, on peut la frapper : elle s'en va) ; le jour, les **corbeaux** viennent **picorer les semis** (semés ou à peine levés), s'envolent si l'on approche, la nuit ou frappés, et un **épouvantail** (citrouille, blé, bâtons) protège les cultures à 8 cases ; la nuit, les **bourdons-lanternes** sortent parmi les fleurs et les champs : leur abdomen lumineux éclaire et **fait pousser les cultures à 6 cases dans le noir** (et plus vite, comme pollinisées), ils rentrent à l'aube. Le livre (Animaux : Animaux sauvages ; Ferme : Ravageurs) | `f3685af` |
| Outils en main | Demandé par le propriétaire : **refonte des outils, des épées et de l'arc**. Nouveaux modèles plus réalistes (bois veiné, poignée gainée de cuir, tête dans la couleur du matériau avec un œil plus sombre, tranchants et pointes affûtés plus clairs ; épée à pommeau, garde, gouttière et fil ; arc qui **se courbe en trois temps** quand on le bande, corde et flèche en traits fins) ; mêmes dessins pour les icônes et les objets au sol. **1re personne** : le **bras droit** (avec la manche de l'armure) tient l'objet en bas à droite, dessiné avec **son propre champ de vision** : il garde sa taille et sa place quel que soit le FOV (60° comme 110°) et **ne traverse plus les murs**, ni la pluie. Il se balance en marchant, traîne un peu quand on tourne la tête, descend et remonte quand on change d'objet. Animations : la pioche se lève puis **frappe vers le réticule**, l'épée **tranche en travers**, un bloc ou la main **pousse en avant**, la nourriture va à la bouche, l'arc vient devant l'œil, penché, la flèche encochée, et tremble bandé à fond. **3e personne** : l'objet est enfin dans la **vraie main droite** ; les outils sont tenus dans le plan du bras et **ne passent plus dans la tête** (vérifié par un test sur tout le coup) ; coups avec élan, frappe rapide et retour ; arc debout en main, en travers de la poitrine bandé | `9f8ca7c` |
| 7.8 Cuisine | Le **plan de cuisine** (de la pierre sur un four alimentaire et des planches, à l'établi ; il se pose face au joueur : tiroirs, four rougeoyant, plan carrelé, planche à découper, marmite en cuivre) s'ouvre au clic droit ou E : sa grille ne fait **que des plats**, avec leurs ingrédients dans n'importe quel ordre : **pain** (3 farines), **soupe de légumes**, **ragoût de viande** (n'importe quelle viande cuite, pomme de terre, carotte, champignon), **tarte aux fruits**, **omelette**, **gâteau**, **crêpes**, **gratin dauphinois**, **confiture** (dans un bocal), **tartine** ; le seau du lait ou le bocal de la confiture **restent dans la grille**. **Machines** (clic droit ou E avec ce qu'elles prennent en main ; on voit à leur modèle qu'elles travaillent puis que c'est prêt) : **moulin** (blé ou maïs → farine, 16 d'un coup), **baratte** (lait → 2 beurres, le seau revient), **tonneau** (jusqu'à 8 fruits → jus de pomme ou jus de fruits ; le jus de pomme laissé plus longtemps devient du **cidre** ; on le tire dans des bocaux en verre), **cave à fromage** (lait → 3 fromages) ; cassées, elles rendent ce qu'elles tenaient. **Plats à effets** (des insignes au-dessus de la vitalité, une barre qui se vide) : **régénération** (un point toutes les 3 s, quelle que soit la satiété), **rassasié** (la faim vient deux fois moins vite), **vivacité** (on marche un cinquième plus vite), **vigueur** (+2 par coup), **adresse** (on casse un tiers plus vite) ; un plat à effets se mange même rassasié. Le livre : chapitre **Cuisine** (recettes, machines, effets) | « Kitchen » |

**Pas encore fait** (prévu) : structures, menus de départ, sons, mode Arcade,
mobile.

---

## 4. Repères pour Claude (en plus de `CLAUDE.md`)

### Où se trouve quoi

| Domaine | Fichiers |
|---|---|
| Point d'entrée | `src/main.gd` (crée le serveur, le client, options de développement, captures) |
| Serveur | `src/sim/game_server.gd` (sessions, envoi des chunks, messages, météo, temps, sauvegarde), `src/sim/game_modes.gd` (règles des modes, catalogue, commandes de debug), `src/sim/chat/` (chat, commandes, admins), `src/sim/survival/` (vitalité, faim, souffle), `src/sim/save/world_storage.gd` (fichiers du monde sauvegardé) |
| Monde | `src/sim/world/` (`voxels.gd` : ids et propriétés des voxels ; `chunk_data.gd` : 16×16×128 voxels, biome et sommet du terrain par colonne ; `world_state.gd` : chunks du serveur, recherche d'un sol pour les déplacements de debug), `generation/` (climat, relief, biomes, surface → colonnes, `cave_generator.gd` : grottes 3D et minerais) |
| Minage | `src/sim/world/mining.gd` (règles, durée selon le bloc et l'outil : `break_seconds`, `tool_for`), `src/sim/world/voxel_ray.gd` (visée), `src/client/interaction/` (visée et rendu côté client : cadre, fissures, éclats, arbres qui tombent) |
| Créatures | `src/sim/creatures/` (`species.gd` espèces, `creature.gd` base commune, `animal.gd` et `monster.gd` comportements, `monsters.gd` apparition, chasse et coups des monstres, `light.gd` lumière côté serveur, `pathfinder.gd` chemins, `creatures.gd` troupeaux, vie près des joueurs, synchronisation, coups des joueurs ; `combat.gd` dégâts), `src/client/creatures/` (`creatures_view.gd`, `creature_body.gd` animations), `src/client/models/creature_models.gd` et `monster_models.gd` (modèles en pièces) |
| Objets | `src/sim/items/` (`items.gd` registre, ce que donne chaque bloc, outils et leurs vitesses, `recipes.gd` recettes, `inventory.gd`, `dropped_item.gd`), `src/client/items/` (modèles, icônes rendues hors écran, objets au sol), `src/ui/hotbar.gd`, `inventory_screen.gd`, `item_slot.gd` |
| Physique | `src/sim/physics/player_body.gd` (marche, saut, chute, plafonds, parmi les voxels), `tile_collider.gd` (déplacement parmi des boîtes d'obstacles : case entière, tronc, rocher) ; `src/sim/world/object_shapes.gd` (versions des objets, troncs, emprise au sol : partagé avec les modèles) |
| Combat | `src/sim/creatures/combat.gd` (coups, dégâts des outils et des épées), `src/sim/combat/archery.gd` (tirs et vol des flèches côté serveur), `src/sim/items/armor.gd` (pièces, points de protection, usure, cases d'armure), `src/client/combat/` (`archer.gd` bander et tirer, `arrows_view.gd` les flèches en vol), `src/client/models/armor_models.gd` (armures portées et icônes) |
| Maison et jardin | `src/client/models/decor_models.gd` (les modèles : support mural, rideaux, vitre, évier, toilettes, table, chaise, barrière, portillon, portail, feu de camp), `src/sim/world/object_shapes.gd` (objets orientés, sur deux cases, accrochés au mur, barrières, portes), `src/sim/world/mining.gd` (pose, objets entiers, portes qui s'ouvrent), `src/sim/world/fixtures.gd` (côté serveur : ouvrir une porte, ce qui tombe avec son mur) |
| Messages | `src/net/msg.gd` (tous les échanges client ⇄ serveur) |
| Client | `src/client/game_client.gd` (assemble la scène 3D, entrées, caméra), `client_messages.gd` (ce que fait le client de chaque message du serveur), `src/ui/chat_box.gd` (le chat), `local_player.gd` (marche, vol), `modes/game_mode_view.gd` (mode de jeu, spectateur, touches de debug), `survival/vitals_view.gd` |
| Rendu 3D | `src/client/render/` : `world_viewport.gd` (SubViewport pixel parfait, caméra orbitale), `render_3d.gd` (repères, étirement de la racine du monde), `cut_region.gd` (où la coupe de la vue s'applique sous un toit), `chunk_mesher.gd` (maillage des voxels sur les fils de travail, carte de surface du shader), `chunk_view_3d.gd` (terrain, grottes, objets 3D, lave d'un chunk) / `world_view_3d.gd` (tâches de maillage, coupe sous terre, niveaux de détail), `player_model.gd`, `prop_library.gd` |
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
`--grid=ligne/ligne` (remplir la grille de fabrication, 5×5 au plus : lignes séparées par `/`, cases par
`,`, `none` = case vide ; `--place` visant un établi l'ouvre) (voir
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

## 5. Prochaine étape au « go » : Phase 7 — Agriculture et élevage (en cours)

**Décision du propriétaire (octobre 2026)** : on passe tout de suite à la phase 7 ; la phase 6
est **en pause après son étape 3** (coulées d'eau et de lave) et reprendra plus tard à son
étape 4 (profondeurs), voir plus bas. Le propriétaire garde **toutes** les idées proposées pour
la phase 7, **avec les saisons**, le **chien et le chat** ; le **cheval (monture) plus tard** ;
**oui aux produits sans tuer** (tonte, lait, œufs). Une étape par « go », chacune avec tests,
captures, commit et retour :

1. ✅ **Végétation qui pousse** (voir section 3, ligne 7.1) : le moteur de croissance du serveur (`Growth`) ;
   pousses d'arbres de chaque espèce (un arbre abattu en donne), plantées sur de la terre ou de
   l'herbe, qui deviennent de **jeunes arbres** puis des **arbres** à la lumière (les nuits et
   le noir les arrêtent, une torche les fait pousser) s'il y a la place ; l'herbe **repousse**
   sur la terre nue à côté de l'herbe. Base de la phase 8 (la nature qui repousse).
2. ✅ **Houe, champs, graines** (voir section 3, ligne 7.2) : labourer l'herbe ou la terre en terre labourée (humide près de
   l'eau, sinon elle sèche), graines (hautes herbes, récoltes), blé, carotte, pomme de terre en
   stades visibles, récolte, pain au four.
3. ✅ **Arrosage et soins** (voir section 3, ligne 7.3) : arrosoir (rempli à l'eau), la pluie arrose, irrigation par canaux
   (l'eau qui coule), composteur et compost (un stade de plus), lumière nécessaire (serres,
   fermes souterraines à la lanterne). Pas fait (à proposer) : des arrosoirs améliorés (fer :
   3 cases d'un coup, plus d'eau).
4. ✅ **Plus de cultures** (voir section 3, ligne 7.4) : betterave, maïs, tomate, fraise, chou,
   citrouille et pastèque (le fruit pousse à côté de la tige), riz (dans l'eau peu profonde),
   canne à sucre (au bord de l'eau, repousse une fois coupée), lin (ficelle, toile ; le coton
   laissé de côté), vigne sur treillis ; arbres fruitiers (pommier, cerisier, oranger) ;
   cueillette ; plantes sauvages pour trouver les graines. Puis, à la demande du propriétaire,
   framboises et pêches (ligne 7.4b).
5. ✅ **Élevage** (voir section 3, ligne 7.5) : nourrir pour reproduire (bébés qui grandissent), mener à la corde, enclos,
   produits sans tuer (tondre aux cisailles, traire au seau, œufs dans un pondoir), affection
   (caresser et nourrir chaque jour : de meilleurs produits), abris (poulailler, étable : les
   bêtes y dorment la nuit).
6. ✅ **Animaux de ferme** (voir section 3, ligne 7.6) : vache (lait, cuir), chèvre (lait,
   montagnes), canard (œufs, nage), lapin, cochon (sanglier né à la ferme), abeilles et ruches
   (miel ; les cultures voisines poussent plus vite).
7. ✅ **Animaux sauvages, prédateurs et ravageurs** (voir section 3, ligne 7.7) : loup (en
   meute), ours (taïga), grenouille, tortue (œufs sur les plages), castor (bâtit des barrages), poissons ;
   créatures à nous : taupe qui ravage les champs par en dessous, corbeaux qui picorent les semis
   (chassés par l'épouvantail), bourdon-lanterne qui pollinise la nuit. Pas fait (à proposer) :
   un piège à taupes, des nids de corbeaux dans les arbres, des terriers de lapins, des loups
   qui hurlent (avec les sons).
8. ✅ **Cuisine** (voir section 3, ligne 7.8) : plan de cuisine (recettes à plusieurs ingrédients : pain, soupe, ragoût, tarte,
   omelette, gâteau, confiture), moulin (farine), baratte (beurre), tonneau (jus, cidre), cave
   à fromage ; des plats à effets (satiété, régénération, bonus temporaires). Pas fait (à
   proposer) : poser un gâteau sur une table et en manger des parts, un garde-manger qui garde
   les plats, d'autres boissons (lait de chèvre, thé), des effets plus rares (vision nocturne
   dans les grottes, résistance au froid avec les saisons).
9. **Pêche** (prochaine étape) : canne, poissons selon le biome, l'heure et la météo, appâts, nasses.
9A. **Bateau et filet de pêche** (demandé par le propriétaire ; après la 7.9, dont le filet reprend
   les tables de poissons ; le détail ci-dessous est la proposition de Claude, à confirmer au « go ») :
   - **Pièces fabriquées à l'établi** : proue, section de coque, poupe (avec la barre et la place
     du pilote), chaudière (lingots de fer autour d'un four d'usine), hélice (cuivre), moteur à
     charbon (chaudière + hélice + fer), banc, filet de pêche (ficelle, plombs en fer), pots de
     peinture.
   - **Assemblage** : la coque se monte sur une ligne de la grille 5x5 de l'établi (proue, 0 à 3
     sections, poupe), ce qui donne une coque de **2 à 5 places**. On la pose sur l'eau visée,
     comme le riz. La place du pilote, à la poupe, s'ajoute à ces places.
   - **Écran du bateau** (clic droit ou E sur le bateau, E à bord) : le bateau vu de dessus avec
     ses cases : moteur, combustible (charbon, charbon de bois), filet et, pour chaque place, **un
     banc ou un coffre** (un coffre ordinaire, ses 27 cases ; retiré seulement vide). Tout se
     retire à tout moment, le filet compris.
   - **Naviguer** :
     - monter : clic droit (place du pilote, sinon un banc libre) ;
     - commandes : Z/S les gaz, Q/D la barre, Maj le plein régime ;
     - descendre : Espace (sur la rive la plus proche, sinon dans l'eau) ;
     - de l'inertie, et un long bateau tourne moins vite ;
     - le courant des rivières pousse le bateau, la terre et la glace l'arrêtent, la lave le
       brûle.
   - **Moteur à charbon** :
     - le charbon brûle tant que le moteur tourne, plus vite au plein régime ;
     - une fumée sort de la cheminée, l'hélice tourne, un sillage suit le bateau ;
     - une jauge de combustible s'affiche quand on pilote ;
     - sans charbon ou sans moteur, on rame lentement : on n'est jamais coincé.
   - **Animaux** : en solo, un animal mené à la corde monte sur un banc libre (pour emmener ses
     bêtes sur une île).
   - **Filet** :
     - une touche à bord le met à l'eau ou le relève ;
     - à l'eau, à l'arrêt ou au ralenti dans au moins 2 d'eau, il prend de temps en temps un
       poisson (tables de la 7.9 : biome, heure, météo, profondeur) ou un déchet (algues, bois
       flotté) ;
     - la prise va dans les coffres du bateau ; sinon le filet en garde 8 (visibles), puis ne
       prend plus rien.
   - **Usure du filet** :
     - un peu par minute passée dans l'eau et à chaque prise ;
     - trois fois plus vite traîné à pleine vitesse, et il ne prend alors rien ;
     - relevé, il ne s'use pas ;
     - une barre d'usure comme celle des outils ;
     - usé, il se déchire (sa prise est perdue) ;
     - on le raccommode à l'établi avec de la ficelle.
   - **Couleur, par la peinture** :
     - un pot de peinture = un pigment + de l'huile de lin (graines de lin au moulin, dans un
       bocal) ;
     - pigments : fleurs rouges, jaunes, bleues, blanches et roses, betterave, cactus (vert),
       charbon (noir), lapis ; des mélanges pour l'orange et le violet ;
     - deux couleurs : le clic droit avec un pot peint la coque, Maj + clic droit la bande ;
     - un pot fait 4 couches, la hache décape ;
     - la couleur passe par le shader : pas de modèle par couleur.
   - **Casser le bateau** à la hache (personne à bord) : il rend la coque, le moteur, le filet
     (avec son usure), les bancs, les coffres et leur contenu, et le combustible. La peinture est
     perdue : garder le bateau entier dans l'inventaire demanderait des objets portant des données.
   - **Serveur** : le bateau est une entité sauvegardée, comme les créatures, et le pilote le
     prédit comme son propre corps. C'est le premier « véhicule », il servira pour le cheval.
   - **Plus tard** : d'autres énergies (une voile selon le vent de la météo, l'énergie de la
     phase 8).
10. **Compagnons** : chien (suit, garde le troupeau, aboie contre les monstres), chat (chasse les
    ravageurs).
11. **Saisons** (réglage du monde) : cultures de saison, neige en hiver, arbres qui roussissent
    à l'automne.

Plus tard (après la phase 7) : le **cheval** que l'on monte.

### Chat et commandes : fait

Voir la ligne « Chat et commandes » de la section 3. Idées de commandes à proposer plus tard
(demander au propriétaire) : `/maison` et `/fixemaison` (un point de retour par joueur), `/retour`
(là où on était avant un `/tp`), `/tue` (les monstres autour), `/sauve` (sauvegarder tout de
suite), `/expulse` et `/bannis` (multijoueur), et les touches de débogage (F4, F6, F7, Page
préc./suiv., M) en commandes. `/vide` et la complétion avec Tab sont faits (ligne « Clic molette,
/vide, Tab »).

### Phase 6 — en pause après l'étape 3

La phase 5 (survie et combat) est terminée : voir les lignes 5.1 à 5.7 de la section 3
(vitalité, faim, nage, modes de jeu, animaux, monstres originaux, combat et armures ; tout ce
style-là est à nous, pas celui de Minecraft).

But de la phase 6 : rendre le souterrain vivant et semer le monde de lieux à explorer.
Découpage proposé, **à valider avec le propriétaire avant de commencer**, une étape par « go »,
chacune avec tests, captures, commit et retour :

0. ✅ **Nouveaux items / Nouvelles recettes** (voir section 3, ligne 6.0) : support mural de
   torche, feu de camp, rideaux, fenêtre, vitre, évier, toilettes, table, chaise, barrière,
   portillon et portail (ouverts avec E). Le plan du propriétaire : créer un support mural de
   torche, un feu de camp, des éléments de décoration d'intérieur (ex : rideaux, fenêtres, vitres,
   évier, toilettes, et d'autres...), des éléments de décoration extérieure (ex : barrières,
   portails, portillons, et d'autres...), et d'autres...
0b. ✅ **Identifiants élargis** (voir section 3, ligne 6.0b), demandé par le propriétaire pour
   ajouter beaucoup d'objets, de blocs, d'orientations et de cultures : plus de limite pratique.
1. ✅ **Torches et lumières posées** (voir section 3, ligne 6.1) : torche (bâton + charbon ou charbon de bois) posée au sol ou
   contre un mur (dans un support mural de torche), lanterne posable (au sol, au plafond, aux murs) ; elles éclairent (lumières du rendu) et tiennent les monstres
   à distance (`Light`).
2. ✅ **Lumière des grottes** (voir section 3, ligne 6.2) : un niveau de lumière calculé par le serveur (ciel qui descend par les
   ouvertures, lumières posées, lave), des grottes vraiment noires sans lumière, les monstres
   qui sortent selon ce niveau.
3. ✅ **Coulées d'eau et de lave simples** (voir section 3, ligne 6.3) : l'eau et la lave s'écoulent quand on ouvre une poche
   (sources, descente, étalement limité), lave + eau = pierre.
4. **Profondeurs** (reprise de la phase 6, quand le propriétaire le dira) : biomes souterrains (grottes luxuriantes, grottes de cristal, profondeurs de
   magma), des niveaux profonds plus dangereux (monstres des profondeurs, à inventer).
5. **Ruines et donjons** : salles enfouies générées par graine, coffres avec du butin.
6. **Mines abandonnées** : galeries étayées de bois, coffres.
7. **Villages** : maisons, chemins, puits (habitants plus tard).

## 6. Feuille de route détaillée (phases restantes)

### Phase 5 — Survie et combat ✅ (lignes 5.1 à 5.7 de la section 3)
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

### Phase 7 — Agriculture et élevage (en cours : voir la section 5)
- Labourer, semer, arroser, cultures qui poussent (durées adaptées au rythme), récoltes.
- Élevage (nourrir, enclos, reproduction, produits sans tuer), nouveaux animaux, cuisine,
  pêche, compagnons, saisons. Le cheval plus tard.

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

- **Carte graphique** : mesuré sur le monde du propriétaire (ligne « Économies et Extrême ») : le
  jeu est limité par le fil principal du processeur (logique, serveur intégré, appels de dessin),
  la RTX 5050 attend. Pistes suivantes (phase 9) : regrouper les objets de plusieurs chunks pour
  moins d'appels de dessin, faire tourner le serveur sur son propre fil.
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
