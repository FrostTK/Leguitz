#!/bin/bash
# Installs (or updates) a Leguitz dedicated server on Debian or Ubuntu as a
# systemd service: a user of its own, the server in /opt/leguitz-server, its
# data (settings, worlds, backups) in /srv/leguitz, started at boot. Run as
# root, from the folder of an unpacked leguitz-server archive:
#   sudo ./install.sh
# or let it download the archive (see fetch-server.sh):
#   sudo ./install.sh --github=OWNER/REPO --token=TOKEN [--version=v0.6.0]
#   sudo ./install.sh --url=https://example.org/leguitz-server.tar.gz
#   sudo ./install.sh --archive=/root/leguitz-server-v0.6.0-linux-x86_64.tar.gz
# Options: --ip=ADDRESS (listen on that address only: a dedicated IP),
# --port=N (UDP, 27420), --data=FOLDER, --user=NAME, --open-port (opens the
# port in ufw or firewalld), --no-start.
# Running it again updates the server; the data stays.
set -euo pipefail

PREFIX=/opt/leguitz-server
DATA=/srv/leguitz
USER_NAME=leguitz
IP=""
PORT=""
OPEN_PORT=no
START=yes
FETCH=()
ARCHIVE=""
here="$(cd "$(dirname "$0")" && pwd)"

for arg in "$@"; do
	case "$arg" in
	--ip=*) IP="${arg#*=}" ;;
	--port=*) PORT="${arg#*=}" ;;
	--data=*) DATA="${arg#*=}" ;;
	--user=*) USER_NAME="${arg#*=}" ;;
	--open-port) OPEN_PORT=yes ;;
	--no-start) START=no ;;
	--archive=*) ARCHIVE="${arg#*=}" ;;
	--url=* | --github=* | --version=* | --token=*) FETCH+=("$arg") ;;
	-h | --help) sed -n '2,17p' "$0"; exit 0 ;;
	*) echo "Unknown option: $arg (--help lists them)" >&2; exit 2 ;;
	esac
done

if [ "$(id -u)" -ne 0 ]; then
	echo "Run it as root: sudo $0 $*" >&2
	exit 1
fi
if ! command -v systemctl >/dev/null; then
	echo "systemd is needed (Debian or Ubuntu)." >&2
	exit 1
fi

# The server's files: an archive given or downloaded, else this folder.
source_dir="$here"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
if [ "${#FETCH[@]}" -gt 0 ]; then
	if ! command -v curl >/dev/null || ! command -v jq >/dev/null; then
		apt-get update -qq && apt-get install -y -qq curl jq ca-certificates
	fi
	ARCHIVE="$work/leguitz-server.tar.gz"
	sh "$here/fetch-server.sh" "$ARCHIVE" "${FETCH[@]}"
fi
if [ -n "$ARCHIVE" ]; then
	tar -xzf "$ARCHIVE" -C "$work"
	source_dir="$work/leguitz-server"
fi
if [ ! -f "$source_dir/LeguitzServer.x86_64" ]; then
	echo "No LeguitzServer.x86_64 in $source_dir: unpack the archive first, or give --archive, --url or --github." >&2
	exit 1
fi

# A user of its own, owning the data.
if ! id "$USER_NAME" >/dev/null 2>&1; then
	useradd --system --home-dir "$DATA" --no-create-home --shell /usr/sbin/nologin "$USER_NAME"
fi
mkdir -p "$DATA" "$PREFIX"
chown "$USER_NAME:$USER_NAME" "$DATA"
chmod 750 "$DATA"

# Updating: the server stops first (it saves the world).
was_running=no
if systemctl is-active --quiet leguitz-server; then
	was_running=yes
	echo "Stopping the server (it saves the world)..."
	systemctl stop leguitz-server
fi
install -m 755 "$source_dir/LeguitzServer.x86_64" "$PREFIX/LeguitzServer.x86_64"
for helper in stop-server.sh leguitz-console fetch-server.sh install.sh; do
	[ -f "$source_dir/$helper" ] && install -m 755 "$source_dir/$helper" "$PREFIX/$helper"
done
[ -f "$source_dir/VERSION" ] && install -m 644 "$source_dir/VERSION" "$PREFIX/VERSION"
cat > /usr/local/bin/leguitz-console <<EOF
#!/bin/sh
LEGUITZ_DATA="$DATA" exec "$PREFIX/leguitz-console" "\$@"
EOF
chmod 755 /usr/local/bin/leguitz-console

# The settings, written once (then yours to change): the address and port.
if [ ! -f "$DATA/server.cfg" ]; then
	# From the data folder: Godot goes back to where it started, which that user may not read.
	(cd "$DATA" && runuser -u "$USER_NAME" -- env HOME="$DATA" "$PREFIX/LeguitzServer.x86_64" --headless --data="$DATA" --init)
fi
[ -n "$IP" ] && sed -i "s|^ip=.*|ip=\"$IP\"|" "$DATA/server.cfg"
[ -n "$PORT" ] && sed -i "s|^port=.*|port=$PORT|" "$DATA/server.cfg"
port_now="$(sed -n 's/^port=\([0-9]*\).*/\1/p' "$DATA/server.cfg")"
port_now="${port_now:-27420}"

# The service.
sed -e "s|@PREFIX@|$PREFIX|g" -e "s|@DATA@|$DATA|g" -e "s|@USER@|$USER_NAME|g" \
	"$source_dir/leguitz-server.service" > /etc/systemd/system/leguitz-server.service
systemctl daemon-reload
systemctl enable leguitz-server >/dev/null

# The port (UDP).
if [ "$OPEN_PORT" = yes ]; then
	if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
		ufw allow "$port_now/udp"
	elif command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
		firewall-cmd --permanent --add-port="$port_now/udp" && firewall-cmd --reload
	else
		echo "No ufw nor firewalld running: open UDP port $port_now yourself if a firewall filters it."
	fi
fi

if [ "$START" = yes ]; then
	systemctl restart leguitz-server
fi
version="$(cat "$PREFIX/VERSION" 2>/dev/null || echo "?")"
echo
[ "$was_running" = yes ] && echo "Leguitz server updated to $version." || echo "Leguitz server $version installed."
echo "  Settings:   $DATA/server.cfg (restart after a change: systemctl restart leguitz-server)"
echo "  Worlds:     $DATA/worlds   Backups: $DATA/backups"
echo "  Log:        journalctl -u leguitz-server -f"
echo "  Console:    leguitz-console list   (say, save, kick, ban, backups, help...)"
echo "  Stop/start: systemctl stop|start|restart leguitz-server"
echo "  Players join on UDP port $port_now${IP:+ at $IP}."
