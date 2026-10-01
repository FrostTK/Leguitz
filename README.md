# Leguitz

Jeu en pixel art, en monde ouvert : **explorer, construire, admirer, survivre et combattre**.
Visuellement inspiré de *Stardew Valley* (vue du dessus inclinée), et de *Minecraft* pour la logique
de jeu : monde infini généré procéduralement, blocs, craft, survie, modes Créatif / Survie / Hardcore.
Le monde est rendu en **vraie 3D pixel art** : les blocs sont de vrais cubes texturés en pixel art,
les personnages et les plantes des sprites, avec de vraies ombres et lumières.

- Moteur : **Godot 4.7** (GDScript), rendu Forward+ (Vulkan / Direct3D 12 / Metal)
- Plateformes : PC (Windows, Linux, macOS) d'abord, puis iOS et Android
- Langues : français et anglais (réglable dans le jeu)

![Leguitz : jour, caméra tournée, coucher de soleil, nuit](docs/screenshots/phase2-3d-jour-nuit.png)

## État actuel : phase 2 (visuels et lumière en 3D)

### Phase 2 : le monde en 3D pixel art

| Fonction | État |
|---|---|
| Rendu 3D : blocs, falaises, murs de roche et escaliers en vrais cubes texturés en pixel art | ✅ |
| Vue par défaut « pixel parfait » : chaque pixel du dessin = un pixel à l'écran, défilement fluide | ✅ |
| Caméra orbitale : tourner et incliner la vue autour du joueur à la souris ou à la manette | ✅ |
| Arbres, plantes et joueur en sprites qui projettent de vraies ombres (et ondulent au vent) | ✅ |
| Soleil et lune qui traversent le ciel, ombres longues le matin et le soir, phases de la lune | ✅ |
| Lanterne du joueur la nuit et sous terre, lave lumineuse, minerais brillants | ✅ |
| Météo : pluie, orage avec éclairs, neige selon le biome, sol mouillé, ombres des nuages | ✅ |
| Ambiance : brume du matin, brume dans les vallées, lucioles, feuilles au vent, poussière des grottes | ✅ |
| Eau animée (vagues, écume sur les rives, reflets), lave animée | ✅ |
| Qualité graphique Bas / Moyen / Élevé / Ultra et rendu HD dans le menu pause | ✅ |
| Saut d'un bloc, chutes, blocs de pierre sur lesquels on peut monter (comme Minecraft) | ✅ |

![Leguitz : neige, orage, badlands, grottes](docs/screenshots/phase2-3d-meteo-biomes.png)

![Biomes de Leguitz (phase 1, carte)](docs/screenshots/phase1-biomes.png)

### Phase 1 : un monde généré comme Minecraft

| Fonction | État |
|---|---|
| 5 paramètres climatiques de Minecraft (continentalité, érosion, bizarrerie, température, humidité) | ✅ |
| Relief par courbes (océans, côtes, plaines, collines, montagnes enneigées), rivières au fond des vallées | ✅ |
| 33 biomes de surface choisis comme dans Minecraft (table température × humidité, plateaux, pentes, pics) | ✅ |
| Paliers de hauteur avec falaises, qu'on gravit en sautant d'un niveau à la fois | ✅ |
| Végétation par biome : 8 sortes d'arbres, fleurs en massifs, cactus, champignons géants, cannes à sucre… | ✅ |
| Affleurements rocheux en montagne, avec charbon, fer, cuivre et émeraudes visibles | ✅ |
| 6 niveaux souterrains : grandes salles, tunnels, lacs, lave, pierre puis ardoise profonde | ✅ |
| 7 minerais répartis par profondeur (charbon, cuivre, fer, or, lapis, rubis, diamant) | ✅ |
| Génération en parallèle sur tous les cœurs du processeur | ✅ |
| Carte de debug (M), changement de niveau (Page ↑ / Page ↓), mode fantôme (F4) | ✅ (outils de debug) |

![Carte d'un monde](docs/screenshots/phase1-carte-monde.png)

![Souterrain et carte](docs/screenshots/phase1-souterrain-carte.png)

### Phase 0 : fondations

| Fonction | État |
|---|---|
| Architecture « serveur intégré » (solo), prête pour le multijoueur | ✅ |
| Monde infini découpé en chunks de 16×16 tuiles, chargés autour du joueur | ✅ |
| Déplacement du joueur avec collisions, clavier (ZQSD/WASD, flèches) et manette | ✅ |
| Caméra fluide, pixel art net, zoom (+ / -) | ✅ |
| Horloge du monde : durée de journée 5 à 120 min, synchronisation avec l'appareil, temps figé | ✅ |
| Rythme de la faim, de la cuisson et des cultures adapté à la durée des journées | ✅ (formule prête, utilisée à partir des phases 4 à 7) |
| Rattrapage hors-ligne en mode synchronisé (limité à 1 journée) | ✅ (calcul prêt, appliqué avec les sauvegardes) |
| Menu pause (temps, langue, zoom), horloge à l'écran, écran de debug (F3) | ✅ |
| Tests automatiques et compilation Windows / Linux / macOS par GitHub | ✅ |

## Jouer

**Version compilée :** onglet *Actions* du dépôt GitHub → dernière exécution de *Build* → section
*Artifacts* : `Leguitz-windows`, `Leguitz-linux` ou `Leguitz-macos`.
Sur macOS, la version n'est pas encore signée : faire clic droit → *Ouvrir* au premier lancement.

**Depuis les sources :** installer [Godot 4.7](https://godotengine.org/download), ouvrir le dossier
du projet, puis appuyer sur F5.

### Contrôles

| Action | Clavier | Manette |
|---|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY), flèches | Stick gauche, croix |
| Courir | Maj | Clic du stick gauche |
| Sauter (1 bloc de haut) | Espace | A |
| Pause | Échap | Start |
| Tourner / incliner la caméra | Glisser avec le clic droit (ou la molette enfoncée) | Stick droit |
| Revenir à la vue par défaut | Début (Home) | Clic du stick droit |
| Zoom | Molette, + / - | RB / LB |
| Carte (debug) : ouvrir, dézoomer, fermer | M | Y |
| Écran de debug | F3 | Select |
| Descendre / monter d'un niveau (debug) | Page ↓ / Page ↑ | |
| Mode fantôme, traverse tout (debug) | F4 | |
| Changer la météo (debug) | F6 | |

Les outils de debug seront réservés au mode Créatif quand les modes de jeu arriveront (phase 5).

## Développement

```bash
bash tools/install_godot.sh --templates desktop   # installe Godot dans ~/godot
export PATH="$HOME/godot:$PATH"

godot --headless --path . --import                # prépare le projet
godot --headless --path . -s res://tests/run_tests.gd   # tests unitaires
gdlint src tests && gdformat --check src tests    # style (pip install "gdtoolkit==4.*")
python3 tools/gen_art.py                          # régénère les textures et sprites (+ normales)

# Carte d'un monde en PNG + statistiques des biomes (+ vitesse de génération)
godot --headless --path . -s res://tools/render_world_map.gd -- --seed=42 --size=512 --scale=8 --out=/tmp/carte.png --bench
```

Des options de développement se passent après `--` (graine, heure, capture d'écran…) :
voir `src/core/dev_options.gd`. Exemple :

```bash
godot --path . -- --seed=42 --time=21 --debug --lang=fr
godot --path . -- --seed=42 --layer=-3 --noclip       # directement dans les grottes
godot --path . -- --seed=42 --weather=thunder --camera=30,45 --quality=3   # orage, vue tournée
```

### Organisation du code

```
src/core/     constantes, coordonnées, hachage déterministe, réglages, contrôles
src/sim/      simulation autoritaire (« serveur ») : monde, chunks, horloge
src/sim/world/generation/   génération : climat, relief, biomes, surface, grottes, carte
src/net/      messages et transports (local en solo, réseau plus tard)
src/client/   affichage : rendu 3D (render/), shaders, lumière, météo, joueur
src/ui/       interface : thème, horloge, menu pause, écran de debug
scenes/       scènes Godot
tests/        tests unitaires (lanceur maison, sans dépendance)
tools/        scripts (installation de Godot, génération des sprites)
i18n/         traductions (strings.csv : clé, en, fr)
```

Le client ne modifie jamais le monde directement : il envoie des messages au serveur
(`src/net/msg.gd`), comme dans Minecraft. En solo, le serveur tourne dans le même processus.
Pour le multijoueur, il suffira de brancher un transport réseau.

## Feuille de route

0. ✅ Fondations
1. ✅ Génération du monde à la Minecraft (bruits climatiques, biomes, rivières, falaises, grottes, minerais)
2. ✅ Visuels et lumière en 3D pixel art (ombres, jour/nuit, eau, vent, météo, caméra orbitale)
3. Joueur et interactions (minage, construction, objets, inventaire)
4. Craft (établi, four, outils, coffres)
5. Survie et combat (vie, faim, animaux, monstres, combat, modes de jeu)
6. Souterrain et structures
7. Agriculture et élevage
8. Finitions PC (menus, sauvegardes, sons, options graphiques, Steam)
9. Mobile (iOS, Android)
