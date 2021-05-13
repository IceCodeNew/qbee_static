FROM quay.io/icecodenew/qbee_static:build_base AS qbee
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && export PATH=/build_root/qbittorrent-build/bin:$PATH \
    && export CXXFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include -std=c++17" \
    && export CFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include" \
    && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -static-pie -static-libgcc -static-libstdc++ -L/build_root/qbittorrent-build/lib" \
    # && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -static-pie -Wl,--no-as-needed -L/build_root/qbittorrent-build/lib -lpthread -pthread" \
    && mkdir qbee \
    && curl -sS "https://github.com/IceCodeNew/qBittorrent-Enhanced-Edition/archive/v4_4_x.tar.gz" | bsdtar -xf- -C qbee --strip-components 1 \
    && pushd qbee || exit 1 \
    && cmake -G "Ninja" -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/build_root/qbittorrent-build -DGUI=OFF -DVERBOSE_CONFIGURE=ON -DWEBUI=ON -DSTACKTRACE=OFF -DLibtorrentRasterbar_DIR=/build_root/qbittorrent-build/lib64/cmake/LibtorrentRasterbar -DBoost_DIR="/build_root/qbittorrent-build/lib/cmake/Boost-${boost_version}" -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" -DOPENSSL_INCLUDE_DIR=/usr/include/openssl -DOPENSSL_CRYPTO_LIBRARY=/usr/lib/libcrypto.a -DOPENSSL_SSL_LIBRARY=/usr/lib/libssl.a -DZLIB_INCLUDE_DIR=/usr/include -DZLIB_LIBRARY=/lib/libz.a \
    # && cmake -G "Ninja" -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/build_root/qbittorrent-build -DGUI=OFF -DVERBOSE_CONFIGURE=ON -DWEBUI=ON -DSTACKTRACE=OFF -DLibtorrentRasterbar_DIR=/build_root/qbittorrent-build/lib64/cmake/LibtorrentRasterbar -DBoost_DIR="/build_root/qbittorrent-build/lib/cmake/Boost-${boost_version}" -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    && for i in {1..4}; do sed -i -E 's![\ \"\'"'"'][^\ \"\'"'"']+?\.so[\ \"\'"'"']! !g' 'build/build.ninja'; done \
    # && if ! grep LINK_FLAGS 'build/build.ninja' | grep -Fqw 'static-pie'; then sed -i -E 's!([\t ]+LINK_FLAGS.+)!\1 -static-pie!' 'build/build.ninja'; fi \
    # && sed -i -E -e 's!([\t ]+LINK_FLAGS).+!\1_MARK_REPLACE_ME!' -e 's!([\t ]+LINK_FLAGS)_MARK_REPLACE_ME!\1 = -static -Xlinker "-static-pie"!' 'build/build.ninja' \
    # && grep LINK_FLAGS 'build/build.ninja' \
    && cmake --build build \
    && cmake --install build \
    && strip /build_root/qbittorrent-build/bin/qbittorrent-nox \
    && /build_root/qbittorrent-build/bin/qbittorrent-nox -v \
    # && timeout 5s /build_root/qbittorrent-build/bin/qbittorrent-nox \
    # && cp build/install_manifest.txt /build_root/qbittorrent-build \
    && popd || exit 1 \
    && rm -rf -- "/build_root/qbee" \
    && dirs -c

FROM quay.io/icecodenew/alpine:latest AS collection
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
# date +%s
ARG cachebust=1607047147
COPY --from=qbee /build_root/qbittorrent-build/bin/qbittorrent-nox /build_root/qbittorrent-build/bin/qbittorrent-nox
RUN apk update; apk --no-progress --no-cache add \
    bash coreutils curl file; \
    apk --no-progress --no-cache upgrade; \
    rm -rf /var/cache/apk/*
