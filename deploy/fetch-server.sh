#!/bin/sh
# Downloads a Leguitz dedicated server's archive (leguitz-server-*-linux-
# x86_64.tar.gz) into FILE, from one of:
#   --url=URL            any direct link (your own site, a public release...)
#   --github=OWNER/REPO  a GitHub release's asset: --version=TAG (else the
#                        latest), --token=TOKEN for a private repository (a
#                        fine-grained token that may read its contents)
#   fetch-server.sh FILE --url=... | --github=... [--version=...] [--token=...]
# Needs curl (and jq for GitHub releases).
set -eu
file="${1:?where to write the archive}"
shift
url="" repo="" version="latest" token=""
for arg in "$@"; do
	case "$arg" in
	--url=*) url="${arg#*=}" ;;
	--github=*) repo="${arg#*=}" ;;
	--version=*) version="${arg#*=}" ;;
	--token=*) token="${arg#*=}" ;;
	*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done
if [ -n "$url" ]; then
	echo "Downloading $url"
	curl -fSL --retry 3 -o "$file" "$url"
	exit 0
fi
if [ -z "$repo" ]; then
	echo "Say where the server comes from: --url=... or --github=OWNER/REPO" >&2
	exit 2
fi
api="https://api.github.com/repos/$repo/releases"
if [ "$version" = "latest" ]; then
	api="$api/latest"
else
	api="$api/tags/$version"
fi
auth=""
[ -n "$token" ] && auth="Authorization: Bearer $token"
echo "Looking for the server in $repo's release $version"
release="$(curl -fsSL --retry 3 -H "Accept: application/vnd.github+json" ${auth:+-H "$auth"} "$api")" || {
	echo "No such release (a private repository needs --token)." >&2
	exit 1
}
asset="$(printf '%s' "$release" | jq -r '[.assets[] | select(.name | test("^leguitz-server-.*-linux-x86_64\\.tar\\.gz$"))][0].id // empty')"
if [ -z "$asset" ]; then
	echo "That release holds no leguitz-server-*-linux-x86_64.tar.gz." >&2
	exit 1
fi
curl -fSL --retry 3 -H "Accept: application/octet-stream" ${auth:+-H "$auth"} \
	-o "$file" "https://api.github.com/repos/$repo/releases/assets/$asset"
echo "Downloaded $(printf '%s' "$release" | jq -r '.tag_name')."
