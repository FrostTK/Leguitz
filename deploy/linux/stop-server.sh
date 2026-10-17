#!/bin/sh
# Stops a Leguitz dedicated server cleanly: drops the file "stop" in its data
# folder (the server then saves the world, lets the players go and quits)
# and waits for it to go. Used by the systemd service (ExecStop) and by
# Docker's entrypoint.
#   stop-server.sh DATA_FOLDER [PID] [SECONDS]
data="${1:?the data folder}"
pid="${2:-}"
wait_for="${3:-100}"
touch "$data/stop"
[ -n "$pid" ] || exit 0
while [ "$wait_for" -gt 0 ] && kill -0 "$pid" 2>/dev/null; do
	sleep 1
	wait_for=$((wait_for - 1))
done
exit 0
