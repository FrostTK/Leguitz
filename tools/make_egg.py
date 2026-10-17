"""Writes deploy/pterodactyl/egg-leguitz.json, the Pterodactyl egg of the Leguitz
dedicated server, with deploy/pterodactyl/install.sh as its installation script.
Run it again after changing the script or the variables:
    py tools/make_egg.py      (python3 tools/make_egg.py on Linux)
CI checks that the egg holds the script as it is."""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
FOLDER = ROOT / "deploy" / "pterodactyl"

STARTUP = (
    "./LeguitzServer.x86_64 --headless --data=/home/container --ip=0.0.0.0"
    " --port={{SERVER_PORT}} --world={{WORLD}} --seed=\"{{WORLD_SEED}}\""
    " --game-mode={{GAME_MODE}} --max-players={{MAX_PLAYERS}}"
    " --password=\"{{SERVER_PASSWORD}}\" --view-distance={{VIEW_DISTANCE}}"
    " --language={{CONSOLE_LANGUAGE}} --accounts={{ACCOUNTS}}"
    " --default-role={{DEFAULT_ROLE}}"
)

# name, env, description, default, rules, seen by the server's users, changed by them
VARIABLES = [
    ("Monde", "WORLD", "Le dossier du monde (dans worlds/). Un autre nom fait un autre monde.",
     "world", "required|string|max:40|regex:/^[A-Za-z0-9_-]+$/", True, True),
    ("Graine", "WORLD_SEED", "La graine d'un nouveau monde (vide : au hasard). Ne sert qu'à le créer.",
     "", "nullable|string|max:64", True, True),
    ("Mode de jeu", "GAME_MODE", "survival, creative ou hardcore. Ne sert qu'à créer le monde.",
     "survival", "required|string|in:survival,creative,hardcore", True, True),
    ("Joueurs au plus", "MAX_PLAYERS", "Combien de joueurs à la fois.",
     "10", "required|integer|between:1,200", True, True),
    ("Mot de passe du serveur", "SERVER_PASSWORD",
     "Ce que les joueurs tapent pour entrer (vide : personne ne le demande).",
     "", "nullable|string|max:64", True, True),
    ("Distance de vue", "VIEW_DISTANCE", "Jusqu'où les joueurs voient, en chunks (2 à 16).",
     "12", "required|integer|between:2,16", True, True),
    ("Langue de la console", "CONSOLE_LANGUAGE", "fr ou en.",
     "fr", "required|string|in:fr,en", True, True),
    ("Comptes", "ACCOUNTS",
     "true : chaque pseudo appartient à son premier joueur, protégé par son mot de passe.",
     "true", "required|string|in:true,false", True, True),
    ("Rôle des nouveaux venus", "DEFAULT_ROLE",
     "player, ou visitor (ils regardent sans rien changer tant qu'un admin ne leur donne pas un rôle).",
     "player", "required|string|in:player,visitor", True, True),
    ("Lien de l'archive du serveur", "SERVER_URL",
     "Un lien direct vers leguitz-server-...-linux-x86_64.tar.gz (vide : la version GitHub ci-dessous)."
     " Sert à l'installation et à la réinstallation (mise à jour).",
     "", "nullable|string|max:500", False, False),
    ("Dépôt GitHub", "GITHUB_REPO", "Le dépôt dont les versions publient le serveur.",
     "FrostTK/Leguitz", "nullable|string|max:100", False, False),
    ("Version", "SERVER_VERSION", "La version à installer (v0.6.0...), ou latest : la dernière.",
     "latest", "required|string|max:40", False, False),
    ("Jeton GitHub", "GITHUB_TOKEN",
     "Pour un dépôt privé : un jeton « fine-grained » qui peut lire son contenu (vide : dépôt public).",
     "", "nullable|string|max:200", False, False),
]


def main():
    script = (FOLDER / "install.sh").read_text(encoding="utf-8")
    egg = {
        "_comment": "DO NOT EDIT: made by tools/make_egg.py. Import it in Pterodactyl (Admin, Nests).",
        "meta": {"version": "PTDL_v2", "update_url": None},
        "exported_at": "2026-10-18T00:00:00+00:00",
        "name": "Leguitz",
        "author": "ego@gxitou.fr",
        "description": "Serveur dédié Leguitz | Connexions chiffrées (DTLS), comptes par pseudo, sauvegardes de secours.",
        "features": None,
        "docker_images": {"Debian": "ghcr.io/pterodactyl/yolks:debian"},
        "file_denylist": [],
        "startup": STARTUP,
        "config": {
            "files": "{}",
            "startup": json.dumps({"done": "Leguitz server ready"}),
            "logs": "{}",
            "stop": "stop",
        },
        "scripts": {
            "installation": {
                "script": script,
                "container": "ghcr.io/pterodactyl/installers:debian",
                "entrypoint": "bash",
            }
        },
        "variables": [
            {
                "name": name,
                "description": description,
                "env_variable": env,
                "default_value": default,
                "user_viewable": seen,
                "user_editable": changed,
                "rules": rules,
                "field_type": "text",
            }
            for name, env, description, default, rules, seen, changed in VARIABLES
        ],
    }
    path = FOLDER / "egg-leguitz.json"
    path.write_text(json.dumps(egg, indent=4, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print("Wrote", path.relative_to(ROOT))


if __name__ == "__main__":
    main()
