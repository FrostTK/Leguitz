#!/bin/bash
# Pterodactyl's installation of a Leguitz dedicated server (the egg's
# script, egg-leguitz.json; run in the installer container, the server's
# files in /mnt/server). It downloads the server's archive from SERVER_URL,
# else from the GitHub release SERVER_VERSION of GITHUB_REPO (GITHUB_TOKEN
# for a private repository), and unpacks it. Running it again (Reinstall)
# updates the server; the worlds and settings stay.
set -euo pipefail
apt-get update -qq >/dev/null
apt-get install -y -qq curl jq ca-certificates tar >/dev/null
mkdir -p /mnt/server
cd /mnt/server
archive=/tmp/leguitz-server.tar.gz
auth=()
[ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
if [ -n "${SERVER_URL:-}" ]; then
	echo "Downloading ${SERVER_URL}"
	curl -fSL --retry 3 -o "$archive" "${SERVER_URL}"
else
	repo="${GITHUB_REPO:?GITHUB_REPO or SERVER_URL}"
	version="${SERVER_VERSION:-latest}"
	api="https://api.github.com/repos/${repo}/releases/latest"
	[ "$version" != "latest" ] && api="https://api.github.com/repos/${repo}/releases/tags/${version}"
	echo "Looking for the server in ${repo}'s release ${version}"
	release="$(curl -fsSL --retry 3 -H "Accept: application/vnd.github+json" "${auth[@]}" "$api")" || {
		echo "No such release (a private repository needs GITHUB_TOKEN)."
		exit 1
	}
	asset="$(jq -r '[.assets[] | select(.name | test("^leguitz-server-.*-linux-x86_64\\.tar\\.gz$"))][0].id // empty' <<<"$release")"
	if [ -z "$asset" ]; then
		echo "That release holds no leguitz-server-*-linux-x86_64.tar.gz."
		exit 1
	fi
	curl -fSL --retry 3 -H "Accept: application/octet-stream" "${auth[@]}" \
		-o "$archive" "https://api.github.com/repos/${repo}/releases/assets/${asset}"
	echo "Downloaded $(jq -r '.tag_name' <<<"$release")."
fi
tar -xzf "$archive" -C /tmp
cp /tmp/leguitz-server/LeguitzServer.x86_64 /mnt/server/
cp /tmp/leguitz-server/VERSION /mnt/server/ 2>/dev/null || true
chmod 755 /mnt/server/LeguitzServer.x86_64
rm -rf "$archive" /tmp/leguitz-server
# The settings' file, to be seen in the panel before the first start.
if [ ! -f /mnt/server/server.cfg ]; then
	HOME=/mnt/server ./LeguitzServer.x86_64 --headless --data=/mnt/server --init || true
fi
echo "Leguitz server $(cat /mnt/server/VERSION 2>/dev/null || echo) installed."
