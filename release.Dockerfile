# syntax=docker.io/docker/dockerfile-upstream:1.2.0
FROM quay.io/icecodenew/qbee_static:latest AS qbee_upload
SHELL ["/bin/bash", "-ox", "pipefail", "-c"]
ARG TAG_NAME='v4.1.9.1-20201206-b2112f2'
COPY got_github_release.sh /tmp/got_github_release.sh
WORKDIR /build_root/qbittorrent-build/bin
# import secret:
RUN --mount=type=secret,id=GIT_AUTH_TOKEN,dst=/tmp/secret_token export GITHUB_TOKEN="$(cat /tmp/secret_token)" \
    && bash /tmp/got_github_release.sh \
    && github-release release \
    --user IceCodeNew \
    --repo qBittorrent-Enhanced-Edition \
    --tag "$TAG_NAME" \
    --name "$TAG_NAME"; \
    github-release upload \
    --user IceCodeNew \
    --repo qBittorrent-Enhanced-Edition \
    --tag "$TAG_NAME" \
    --name "qbittorrent-nox" \
    --file "/build_root/qbittorrent-build/bin/qbittorrent-nox"
