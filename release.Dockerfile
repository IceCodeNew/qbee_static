# syntax=docker.io/docker/dockerfile-upstream:1.2.0
FROM quay.io/icecodenew/qbee_static:latest AS qbee_upload
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG TAG_NAME='v4.1.9.1-20201206-b2112f2'
WORKDIR /build_root/qbittorrent-build/bin
# import secret:
RUN --mount=type=secret,id=GIT_AUTH_TOKEN,dst=/tmp/secret_token export GITHUB_TOKEN="$(cat /tmp/secret_token)" \
    && "/go/bin/github-release" release \
    --user IceCodeNew \
    --repo qBittorrent-Enhanced-Edition \
    --tag "$TAG_NAME" \
    --name "$TAG_NAME"; \
    "/go/bin/github-release" upload \
    --user IceCodeNew \
    --repo qBittorrent-Enhanced-Edition \
    --tag "$TAG_NAME" \
    --name "qbittorrent-nox" \
    --file "/build_root/qbittorrent-build/bin/qbittorrent-nox"
