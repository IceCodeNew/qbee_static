FROM quay.io/icecodenew/qbee_static:build_base AS qbee
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/IceCodeNew/qBittorrent-Enhanced-Edition/commits?per_page=1
ARG qbee_latest_commit_hash='22290226034a3ff98cf5fbdfba8a5007d970a215'
ARG dockerfile_workdir=/build_root/qbee
WORKDIR $dockerfile_workdir
RUN curl --retry 5 --retry-delay 10 --retry-max-time 60 -fsSL "https://github.com/IceCodeNew/qBittorrent-Enhanced-Edition/archive/v4_4_x.tar.gz" | bsdtar -xf- --strip-components 1 \
    && CFLAGS="$CFLAGS -fPIC" \
    && CXXFLAGS="$CXXFLAGS -fPIC" \
    && LDFLAGS="-static -s" \
    && export CFLAGS CXXFLAGS LDFLAGS \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=/build_root/qbittorrent-build -G Ninja -B build \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" -DCMAKE_SKIP_RPATH=ON -DCMAKE_SKIP_INSTALL_RPATH=ON -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    -DBoost_NO_BOOST_CMAKE=ON \
    -DQT6=ON -DGUI=OFF -DVERBOSE_CONFIGURE=ON -DWEBUI=ON -DSTACKTRACE=OFF \
    -DLibtorrentRasterbar_DIR=/build_root/qbittorrent-build/lib64/cmake/LibtorrentRasterbar \
    -DCMAKE_CXX_STANDARD_LIBRARIES=/usr/lib/libexecinfo.a \
    && sed -i -E -e 's|/usr/lib/libexecinfo\.so||g' -e 's|\.so|\.a|g' build/build.ninja \
    && mold -run cmake --build build --parallel \
    && cmake --install build --strip \
    && readelf -p .comment /build_root/qbittorrent-build/bin/qbittorrent-nox \
    && rm -rf -- "$dockerfile_workdir"

FROM quay.io/icecodenew/alpine:latest AS collection
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
COPY --from=qbee /build_root/qbittorrent-build/bin/qbittorrent-nox /build_root/qbittorrent-build/bin/qbittorrent-nox
RUN apk update; apk --no-progress --no-cache add \
    bash coreutils curl file; \
    apk --no-progress --no-cache upgrade; \
    rm -rf /var/cache/apk/*
