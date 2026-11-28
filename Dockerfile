# PathViz — packet path visualizer (https://github.com/iximiuz/pathviz)
#
# Build:
#   sudo docker build -t pathviz .
#
# Run (privileged is needed: root in its own netns, nftables table, NFLOG):
#   sudo docker run --rm -it --privileged --name pathviz \
#       -p 7070:7070 -e DEMO=0 pathviz
#
# Then open http://localhost:7070 — the access token is printed in
# `docker logs -f pathviz` (set PATHVIZ_TOKEN, >=16 chars, for a stable one).
#
# Notes:
#   * PathViz only traces traffic inside its own network namespace.
#     - bridge mode (default): container-local traffic; DEMO=1 generates a
#       loopback demo flow so the UI has something to show out of the box.
#     - `--network host`: trace real traffic on this machine, open
#       http://127.0.0.1:7070 (token from logs).
#   * The kernel module nfnetlink_log must be available; auto-loading it
#     requires the container to run privileged.

FROM golang:1.24 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath \
    -ldflags="-s -w -X main.version=${VERSION}" \
    -o /out/pathviz .

FROM debian:trixie-slim AS runtime
# nft (nftables CLI) and ss (iproute2) are required by pathviz at runtime;
# curl + python3 power the optional built-in demo traffic.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl iproute2 nftables python3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/pathviz /usr/local/bin/pathviz
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Web UI; a random access token is generated on each start (see docker logs).
EXPOSE 7070
ENTRYPOINT ["/entrypoint.sh"]
CMD ["--listen", "0.0.0.0:7070"]
