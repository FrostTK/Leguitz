# A Leguitz dedicated server in a container. Built from an unpacked
# leguitz-server archive (this file, entrypoint.sh, leguitz-console,
# stop-server.sh and LeguitzServer.x86_64 side by side):
#   docker build -t leguitz-server .
#   docker run -d --name leguitz -p 27420:27420/udp -v leguitz-data:/data leguitz-server
# Options after the image's name go to the server (--seed=..., --world=...).
FROM debian:bookworm-slim

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates \
	&& rm -rf /var/lib/apt/lists/* \
	&& useradd --system --uid 1000 --home-dir /data --no-create-home --shell /usr/sbin/nologin leguitz \
	&& mkdir -p /data && chown leguitz:leguitz /data

COPY LeguitzServer.x86_64 entrypoint.sh stop-server.sh leguitz-console /opt/leguitz-server/
RUN chmod 755 /opt/leguitz-server/* \
	&& ln -s /opt/leguitz-server/leguitz-console /usr/local/bin/leguitz-console

ENV LEGUITZ_DATA=/data HOME=/data
VOLUME /data
EXPOSE 27420/udp
USER leguitz
WORKDIR /data
STOPSIGNAL SIGTERM
ENTRYPOINT ["/opt/leguitz-server/entrypoint.sh"]
