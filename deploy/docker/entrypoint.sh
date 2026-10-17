#!/bin/sh
# Starts a Leguitz dedicated server in a container (its data in
# LEGUITZ_DATA, /data), the options given passed on. Docker's stop (SIGTERM)
# becomes a clean stop: the file "stop" is dropped in the data folder, the
# server saves the world, lets the players go and quits.
data="${LEGUITZ_DATA:-/data}"
/opt/leguitz-server/LeguitzServer.x86_64 --headless --data="$data" "$@" &
pid=$!
trap '/opt/leguitz-server/stop-server.sh "$data"' TERM INT
status=0
# wait returns early when a signal comes: wait again until the server went.
while kill -0 "$pid" 2>/dev/null; do
	wait "$pid"
	status=$?
done
exit "$status"
