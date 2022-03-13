# syntax=docker.io/docker/dockerfile-upstream:1.2.0
FROM quay.io/icecodenew/qbee_static:latest AS qbee_upload
SHELL ["/bin/bash", "-ox", "pipefail", "-c"]
ARG TAG_NAME='v4.1.9.1-20201206-b2112f2'
ARG BRANCH='v4_4_x'
COPY got_github_release.sh /tmp/got_github_release.sh
WORKDIR /git/qBittorrent-Enhanced-Edition/
# import secret:
RUN --mount=type=secret,id=GIT_AUTH_TOKEN,dst=/tmp/secret_token export GITHUB_TOKEN="$(cat /tmp/secret_token)" \
    && bash /tmp/got_github_release.sh \
    && git clone -j "$(nproc)" --single-branch --branch "$BRANCH" -- "https://IceCodeNew:${GITHUB_TOKEN}@github.com/IceCodeNew/qBittorrent-Enhanced-Edition.git" . \
    && git config --global user.email "32576256+IceCodeNew@users.noreply.github.com" \
    && git config --global user.name "IceCodeNew" \
    && git fetch origin --prune --prune-tags \
    && git remote -v; \
    echo '' \
    && echo '$$$$$$$$ github-release $$$$$$$$' \
    && echo '' \
    && set -x; \
    grep -Fq "$TAG_NAME" <(git tag) \
    && github-release delete \
    --user IceCodeNew \
    --repo qBittorrent-Enhanced-Edition \
    --tag "$TAG_NAME" \
    && git push origin -d "$TAG_NAME" \
    && git tag -d "$TAG_NAME"; \
    git tag -a "$TAG_NAME" -m "$TAG_NAME" "$(git rev-parse --short origin/${BRANCH})" \
    && git push origin "$TAG_NAME" \
    && github-release release \
    --user IceCodeNew \
    --repo qBittorrent-Enhanced-Edition \
    --pre-release \
    --tag "$TAG_NAME" \
    --name "$TAG_NAME"; \
    sleep 3s \
    && github-release upload \
    --user IceCodeNew \
    --repo qBittorrent-Enhanced-Edition \
    --tag "$TAG_NAME" \
    --name "qbittorrent-nox" \
    --file "/build_root/qbittorrent-build/bin/qbittorrent-nox"
