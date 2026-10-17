# Héberger un serveur Leguitz

Ce guide installe un **serveur dédié Leguitz** que les joueurs rejoignent depuis le jeu (menu
pause → Multijoueur → « Rejoindre un serveur… »). Il y a trois façons de l'héberger :

- [sur un VPS Debian ou Ubuntu](#2-sur-un-vps-debian-ou-ubuntu-systemd), comme un service
  systemd : la plus simple sur une machine à toi ;
- [avec Docker](#3-avec-docker) ;
- [avec Pterodactyl](#4-avec-pterodactyl), grâce à l'egg fourni.

## 1. Ce qu'il faut savoir

- **Le port** : **UDP 27420** par défaut (réglage `port`). C'est de l'UDP, pas du TCP : ouvre
  bien l'UDP dans ton pare-feu et chez ton hébergeur.
- **La version** : le jeu et le serveur doivent avoir **la même version**. Quand tu mets le
  serveur à jour, mets aussi à jour le jeu des joueurs (et inversement).
- **Les connexions sont chiffrées** (DTLS). Le serveur crée sa clé au premier démarrage, dans
  `tls/` de son dossier de données : garde-la pour toi.
- **Les comptes** : chaque pseudo appartient à son premier joueur. Celui-ci choisit un mot de
  passe la première fois, puis lui seul joue sous ce pseudo. Le premier joueur à entrer devient
  **administrateur**.
- **Le dossier de données** contient tout ce qui compte :

  | Chemin | Contenu |
  |---|---|
  | `server.cfg` | Les réglages, commentés. Redémarre le serveur après un changement. |
  | `worlds/` | Les mondes. |
  | `backups/` | Les sauvegardes de secours : un zip au démarrage, puis toutes les 6 h. |
  | `tls/` | La clé du serveur. |
  | `console/` | Les commandes envoyées par `leguitz-console`. |

- **Ce qu'il faut à la machine** : Linux x86_64, 1 cœur et 1 Go de mémoire pour quelques
  joueurs (le serveur seul prend environ 250 Mo). Un serveur démarre en une vingtaine de
  secondes.

### Récupérer le serveur

Le serveur est une archive **`leguitz-server-VERSION-linux-x86_64.tar.gz`**. La CI GitHub la
construit à chaque version (un tag `v…`) et la publie dans les **Releases** du dépôt. On la
trouve aussi dans les artefacts de chaque build (`LeguitzServer-linux`).

L'archive contient le serveur, ce guide et de quoi l'héberger :

| Fichier | À quoi il sert |
|---|---|
| `LeguitzServer.x86_64` | Le serveur. |
| `install.sh` | L'installation sur Debian ou Ubuntu. |
| `leguitz-server.service` | Le service systemd. |
| `leguitz-console` | Envoie une commande au serveur. |
| `stop-server.sh` | L'arrêt propre du serveur. |
| `Dockerfile`, `entrypoint.sh`, `compose.yaml` | L'installation avec Docker. |
| `egg-leguitz.json` | L'egg Pterodactyl. |

Le dépôt est **privé**. Pour faire arriver l'archive sur le serveur, trois choix :

1. **À la main** : télécharge l'archive depuis la page Releases (connecté à GitHub), puis
   copie-la sur la machine (`scp`, ou le gestionnaire de fichiers du panneau).
2. **Avec un jeton GitHub en lecture seule** : les scripts téléchargent eux-mêmes la version
   voulue. Pour le créer :
   - GitHub → Settings → Developer settings → Personal access tokens → **Fine-grained tokens**
     → Generate ;
   - « Repository access » : seulement le dépôt `FrostTK/Leguitz` ;
   - « Permissions » : **Contents: Read-only**.

   Le jeton commence par `github_pat_`. Garde-le secret.
3. **Depuis ton site** : dépose l'archive sur ton propre serveur web (par exemple
   `https://gxitou.fr/leguitz/…`). Les scripts prennent n'importe quel lien direct (`--url=…`).

## 2. Sur un VPS Debian ou Ubuntu (systemd)

Testé sur Debian 12 et Ubuntu 24.04, en root.

### Installer

```bash
# L'archive copiée sur la machine (choix 1) :
tar -xzf leguitz-server-v0.6.0-linux-x86_64.tar.gz
cd leguitz-server
sudo ./install.sh --open-port
```

Ce que fait `install.sh` :

1. Il crée un utilisateur `leguitz`, sans mot de passe ni connexion.
2. Il installe le serveur dans `/opt/leguitz-server` et ses données dans `/srv/leguitz`.
3. Il écrit `server.cfg`.
4. Il installe le service `leguitz-server`, qui démarre avec la machine et redémarre s'il
   plante.
5. Avec `--open-port`, il ouvre le port UDP dans **ufw** ou **firewalld** s'ils tournent.

Les options :

| Option | Effet |
|---|---|
| `--ip=203.0.113.10` | Écoute sur cette adresse seulement (ton **IP dédiée**). |
| `--port=27420` | Le port UDP. |
| `--data=/srv/leguitz` | Le dossier de données. |
| `--user=leguitz` | L'utilisateur du service. |
| `--open-port` | Ouvre le port dans le pare-feu. |
| `--no-start` | Installe sans démarrer (pour régler `server.cfg` d'abord). |
| `--archive=FICHIER` | Installe depuis une archive (sans la décompresser avant). |
| `--url=LIEN` | Télécharge l'archive depuis ce lien (choix 3). |
| `--github=FrostTK/Leguitz --token=github_pat_…` | Télécharge depuis les Releases (choix 2). |
| `--version=v0.6.0` | Avec `--github` : cette version-là plutôt que la dernière. |

Avec un jeton (choix 2), sans rien copier à la main : récupère d'abord les scripts du dépôt (ils
sont dans `deploy/`), puis lance
`sudo ./install.sh --github=FrostTK/Leguitz --token=github_pat_… --open-port`.

### L'IP dédiée

Si ta machine a plusieurs adresses (une IP dédiée en plus de la principale), le serveur peut
n'écouter que sur l'une d'elles.

1. Vérifie qu'elle est bien sur la machine : `ip -4 addr` doit la montrer.
2. Donne-la au serveur : `--ip=…` à l'installation, ou `ip="203.0.113.10"` dans
   `/srv/leguitz/server.cfg`, puis `sudo systemctl restart leguitz-server`.

Les joueurs tapent cette adresse dans le jeu (avec `:port` si ce n'est pas 27420).

### Le pare-feu

- **ufw** : `sudo ufw allow 27420/udp`.
- **nftables** : `sudo nft add rule inet filter input udp dport 27420 accept`. Ajoute aussi la
  règle dans `/etc/nftables.conf` pour qu'elle survive au redémarrage.
- **Chez l'hébergeur** (OVH, Hetzner, Scaleway…), un pare-feu de leur panneau peut aussi
  filtrer : ouvre-y l'**UDP 27420** entrant.

### Au quotidien

| Pour… | Commande |
|---|---|
| Voir s'il tourne | `sudo systemctl status leguitz-server` |
| Lire son journal en direct | `sudo journalctl -u leguitz-server -f` |
| L'arrêter proprement (il sauvegarde) | `sudo systemctl stop leguitz-server` |
| Le démarrer, le redémarrer | `sudo systemctl start leguitz-server` / `restart` |
| Lui donner une commande | `sudo leguitz-console list` (la réponse s'affiche dans le journal) |

Les commandes de la console :

- `list` : qui joue ;
- `say Bonjour` : un message à tous ;
- `save` : sauvegarder le monde ;
- `backups` : la liste des sauvegardes de secours ;
- `restore 1` : remettre la plus récente (le serveur s'arrête, puis
  `sudo systemctl start leguitz-server`) ;
- `kick Pseudo`, `ban Pseudo 2h raison`, `unban`, `whitelist`, `role Pseudo moderator`,
  `admin add Pseudo`, `time`, `weather`… : `help` les liste toutes.

### Mettre à jour

Relance `install.sh` avec la nouvelle archive, ou par exemple
`sudo /opt/leguitz-server/install.sh --github=FrostTK/Leguitz --token=…`. Il arrête le serveur
(qui sauvegarde), remplace le programme et le redémarre. Les mondes et `server.cfg` restent.

### Désinstaller

```bash
sudo systemctl disable --now leguitz-server
sudo rm /etc/systemd/system/leguitz-server.service /usr/local/bin/leguitz-console
sudo rm -r /opt/leguitz-server        # le programme
sudo rm -r /srv/leguitz               # les mondes et les sauvegardes : à garder ailleurs avant !
sudo userdel leguitz
```

## 3. Avec Docker

Depuis le dossier de l'archive décompressée :

```bash
docker build -t leguitz-server .
docker run -d --name leguitz --restart unless-stopped \
  -p 27420:27420/udp -v leguitz-data:/data --stop-timeout 90 leguitz-server
```

Ou avec Docker Compose (le fichier `compose.yaml` est fourni) : `docker compose up -d --build`.

Pour une **IP dédiée**, publie le port sur elle : `-p 203.0.113.10:27420:27420/udp`.

Les données sont dans le volume `leguitz-data`, monté sur `/data` : `server.cfg`, `worlds/`,
`backups/`.

Des options après le nom de l'image passent au serveur et priment sur `server.cfg`, par exemple
`--seed=abc` ou `--max-players=20`.

| Pour… | Commande |
|---|---|
| Lire le journal | `docker logs -f leguitz` |
| Donner une commande | `docker exec leguitz leguitz-console say Bonjour` |
| L'arrêter proprement | `docker stop leguitz` |
| Modifier `server.cfg` | `docker run --rm -it -v leguitz-data:/data debian nano /data/server.cfg` |

`docker stop` déclenche l'arrêt propre (le serveur sauvegarde le monde avant de partir) :
laisse-lui le temps, d'où `--stop-timeout 90`.

**Mettre à jour** : reconstruis l'image avec la nouvelle archive (`docker build -t
leguitz-server .`), puis `docker rm -f leguitz` et relance le même `docker run`. Le volume garde
les mondes.

Avec un dossier de l'hôte (`-v /srv/leguitz:/data`) plutôt qu'un volume, ce dossier doit
appartenir à l'utilisateur 1000 : `sudo chown -R 1000:1000 /srv/leguitz`.

## 4. Avec Pterodactyl

### Importer l'egg

1. Panneau d'administration → **Nests** → **Import Egg**.
2. Choisis le fichier **`egg-leguitz.json`** (dans l'archive, ou `deploy/pterodactyl/` du dépôt)
   et un nest (crée-en un « Leguitz » si tu veux).
3. Sur l'egg importé, onglet **Variables** : règle les valeurs par défaut de l'installation.

   | Variable | Valeur |
   |---|---|
   | Dépôt GitHub | `FrostTK/Leguitz` |
   | Version | `latest` |
   | Jeton GitHub | ton jeton en lecture seule, nécessaire tant que le dépôt est privé (voir plus haut) |
   | Lien de l'archive du serveur | ou bien ce lien direct, qui remplace GitHub |

### Créer un serveur

1. **Servers** → **Create New**, egg « Leguitz ».
2. **Allocation** : l'IP (ton IP dédiée) et le port. Wings ouvre le port en TCP et en UDP ; le
   jeu n'utilise que l'UDP.
3. **Mémoire** : 1024 Mo au moins. **Disque** : 2 Go et plus selon le monde.
4. **Variables du serveur** (les joueurs du panneau les voient) :
   - le monde, la graine et le mode de jeu (ces deux-là ne servent qu'à créer le monde) ;
   - les joueurs au plus, le mot de passe du serveur, la distance de vue ;
   - la langue de la console, les comptes, le rôle des nouveaux venus.
5. L'installation télécharge le serveur (quelques secondes), puis **Start**. Le panneau passe à
   « Running » quand le serveur écrit `Leguitz server ready`.

### Au quotidien

- **La console du panneau** est celle du serveur : `list`, `say`, `save`, `kick`, `backups`…
- **Stop** envoie `stop` : le serveur sauvegarde et s'arrête proprement.
- **`server.cfg`** se règle dans le gestionnaire de fichiers. Les variables du panneau passent
  par-dessus (port, monde, joueurs, mot de passe…).
- **Mettre à jour** : onglet Settings → **Reinstall Server**. Il retélécharge la version
  choisie et garde les mondes. Pour une version précise, change « Version » dans les variables
  de l'egg ou du serveur.

## 5. Rejoindre et administrer

- Dans le jeu : menu pause → **Multijoueur** → « Rejoindre un serveur… ». Tape l'adresse (et
  `:port` si ce n'est pas 27420), ton pseudo, le mot de passe du serveur s'il y en a un, puis
  **ton mot de passe** (choisi la première fois).
- **Le premier joueur entré est administrateur.** Ensuite, dans le chat ou la console :
  - `/admin add Pseudo` : faire un autre administrateur ;
  - `/role Pseudo moderator` : un modérateur (il expulse et voyage) ;
  - `/whitelist on` : seuls les inscrits entrent ;
  - `/ban`, `/kick`.
- **Les sauvegardes de secours** : un zip au démarrage et toutes les 6 h, les 10 dernières
  gardées (`backup_hours`, `backups_kept`). `backup` en fait une tout de suite ; `restore`
  remet une sauvegarde, depuis la console seulement.

## 6. Sécurité

- Le serveur tourne sous son propre utilisateur, jamais en root. Le service systemd ne peut
  écrire que dans son dossier de données.
- Les connexions sont chiffrées : personne sur le réseau ne lit le chat, le monde ni
  l'empreinte du mot de passe d'un joueur. Le serveur ne prouve pas encore qui il est : le jeu
  accepte la clé que le serveur montre.
- Pour un serveur privé, mets un mot de passe (`password`), ou la liste blanche, ou
  `default_role="visitor"` : les nouveaux venus regardent sans rien changer tant qu'un admin ne
  leur donne pas un rôle.
- Ne publie jamais ton jeton GitHub. Ne donne aux joueurs que l'adresse et le port.

## 7. Dépannage

- **« Serveur injoignable »** :
  - le port UDP est fermé (pare-feu de la machine ou de l'hébergeur) ;
  - le serveur n'écoute pas sur cette adresse (`ip` dans `server.cfg`) ;
  - il démarre encore : attends `Leguitz server ready` dans le journal.
- **« Ce serveur tourne avec une autre version du jeu »** : le jeu et le serveur n'ont pas la
  même version. Un jeu d'avant le chiffrement des connexions ne joint pas du tout un serveur
  d'aujourd'hui : il le voit « injoignable ».
- **`TLS handshake error` dans le journal** : quelqu'un a essayé avec un jeu trop ancien (sans
  chiffrement), ou c'est un scanner de ports. Sans gravité.
- **Le serveur ne démarre pas** :
  - lis le journal ;
  - « Cannot listen on … » : le port est déjà pris, ou l'adresse n'est pas sur la machine ;
  - un réglage faux de `server.cfg` est signalé au démarrage, puis ignoré.
- **Il s'arrête sans sauvegarder** : laisse-lui le temps de s'arrêter (90 s avec Docker, 120 s
  avec systemd). Avec Pterodactyl, utilise **Stop**, pas **Kill**.
