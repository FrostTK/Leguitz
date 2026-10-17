#!/bin/sh
# Makes a Leguitz dedicated server's archive (CI does, from the exported
# "Linux Server" build):
#   deploy/package.sh build/server/LeguitzServer.x86_64 v0.6.0 build
# -> build/leguitz-server-v0.6.0-linux-x86_64.tar.gz (and its .sha256): one
# folder, leguitz-server/, holding the server, the guide (HEBERGEMENT.md) and
# what each way of hosting it needs (Debian and systemd, Docker, Pterodactyl).
set -eu
binary="${1:?the exported server}"
version="${2:?the version}"
out="${3:?where to write the archive}"
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
folder="$stage/leguitz-server"
mkdir -p "$folder"
install -m 755 "$binary" "$folder/LeguitzServer.x86_64"
printf '%s\n' "$version" > "$folder/VERSION"
for file in linux/install.sh linux/stop-server.sh linux/leguitz-console fetch-server.sh docker/entrypoint.sh; do
	install -m 755 "$here/$file" "$folder/$(basename "$file")"
done
for file in linux/leguitz-server.service docker/Dockerfile docker/compose.yaml pterodactyl/egg-leguitz.json; do
	install -m 644 "$here/$file" "$folder/$(basename "$file")"
done
install -m 644 "$root/docs/hebergement.md" "$folder/HEBERGEMENT.md"
name="leguitz-server-$version-linux-x86_64.tar.gz"
mkdir -p "$out"
tar -czf "$out/$name" -C "$stage" leguitz-server
(cd "$out" && sha256sum "$name" > "$name.sha256")
echo "$out/$name"
