FROM quay.io/icecodenew/builder_image_x86_64-linux:alpine AS base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV build_base_date='2020-12-06' \
    PKG_CONFIG=/usr/bin/pkgconf \
    PKG_CONFIG_PATH=/build_root/qbittorrent-build/lib/pkgconfig
RUN source '/root/.bashrc' \
    && apk del --no-cache \
    clang-libs clang-extra-tools clang-dev clang-static clang llvm10-libs lld \
    && apk update && apk --no-progress --no-cache add \
    zlib-dev zlib-static \
    openssl openssl-dev openssl-libs-static \
    && apk --no-progress --no-cache upgrade \
    && rm -rf /var/cache/apk/* \
    && rm -f /etc/alternatives/ld \
    && update-alternatives --remove-all ld \
    # && type -P ld \
    # && ld --version \
    && mkdir /build_root/qbittorrent-build

FROM base AS boost
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV boost_version='1.74.0' \
    BOOST_ROOT="/build_root/boost" \
    BOOST_INCLUDEDIR="/build_root/boost" \
    BOOST_BUILD_PATH="/build_root/boost"
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && export PATH=/build_root/qbittorrent-build/bin:$PATH \
    && export CXXFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include -std=c++17" \
    && export CFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include" \
    && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -static-libgcc -static-libstdc++ -L/build_root/qbittorrent-build/lib" \
    # && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -Wl,--no-as-needed -L/build_root/qbittorrent-build/lib -lpthread -pthread" \
    && mkdir boost \
    && curl -sS "https://dl.bintray.com/boostorg/release/${boost_version}/source/boost_${boost_version//./_}.tar.bz2" | bsdtar -xf- -C boost --strip-components 1 \
    && pushd boost || exit 1 \
    && /build_root/boost/bootstrap.sh \
    && /build_root/boost/b2 -j"$(nproc)" address-model=64 variant=release threading=multi link=static runtime-link=static cxxflags="${CXXFLAGS}" cflags="${CFLAGS}" linkflags="${LDFLAGS}" toolset=gcc install --prefix="/build_root/qbittorrent-build" \
    && popd || exit 1 \
    && dirs -c

FROM boost AS libtorrent-rasterbar
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && export PATH=/build_root/qbittorrent-build/bin:$PATH \
    && export CXXFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include -std=c++17" \
    && export CFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include" \
    && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -static-libgcc -static-libstdc++ -L/build_root/qbittorrent-build/lib" \
    # && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -Wl,--no-as-needed -L/build_root/qbittorrent-build/lib -lpthread -pthread" \
    && mkdir libtorrent \
    && curl -sS "https://github.com/arvidn/libtorrent/archive/RC_1_2.tar.gz" | bsdtar -xf- -C libtorrent --strip-components 1 \
    && pushd libtorrent || exit 1 \
    # && /build_root/boost/b2 -j"$(nproc)" address-model=64 variant=release threading=multi link=static runtime-link=static cxxflags="${CXXFLAGS}" cflags="${CFLAGS}" linkflags="${LDFLAGS}" toolset=gcc dht=on i2p=on extensions=on encryption=on crypto=openssl openssl-lib="/usr/lib" openssl-include="/usr/include/openssl" deprecated-functions=off fpic=on boost-link=static install --prefix="/build_root/qbittorrent-build" \
    && cmake -G "Ninja" -B build -DBUILD_SHARED_LIBS=OFF -Dstatic_runtime=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=/build_root/qbittorrent-build -Dencryption=ON -Ddeprecated-functions=OFF \
    && cmake --build build \
    && cmake --install build \
    && popd || exit 1 \
    && rm -rf -- "/build_root/boost" "/build_root/libtorrent" \
    && dirs -c

FROM libtorrent-rasterbar AS qtbase
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
### curl -sS -H "Accept: application/vnd.github.v3+json" \
###     'https://api.github.com/repos/qt/qtbase/tags?per_page=32' |
###     grep 'name' | cut -d\" -f4 | grep -vE 'alpha|beta|rc|test|week' |
###     grep -E '^v5' | sort -Vr | head -n 1
ENV qt_latest_tag_name='v5.15.1'
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && export PATH=/build_root/qbittorrent-build/bin:$PATH \
    && export CXXFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include -std=c++17" \
    && export CFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include" \
    && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -static-libgcc -static-libstdc++ -L/build_root/qbittorrent-build/lib" \
    # && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -Wl,--no-as-needed -L/build_root/qbittorrent-build/lib -lpthread -pthread" \
    && git_clone --branch "$qt_latest_tag_name" "https://github.com/qt/qtbase.git" qtbase \
    && pushd qtbase || exit 1 \
    # && OPENSSL_LIBDIR='/build_root/qbittorrent-build/lib' OPENSSL_INCDIR='/build_root/qbittorrent-build/include' OPENSSL_LIBS='-lssl -lcrypto' ./configure -I "/build_root/qbittorrent-build/include" -L "/build_root/qbittorrent-build/lib" QMAKE_LFLAGS="$LDFLAGS" -release -c++std c++17 -prefix "/build_root/qbittorrent-build" -opensource -confirm-license -openssl-linked -qt-pcre -no-icu -no-iconv -no-feature-glib -no-feature-opengl -no-feature-dbus -no-feature-gui -no-feature-widgets -no-feature-testlib -no-compile-examples -static
    && ./configure -I "/build_root/qbittorrent-build/include" -L "/build_root/qbittorrent-build/lib" QMAKE_LFLAGS="$LDFLAGS" -release -c++std c++17 -prefix "/build_root/qbittorrent-build" -opensource -confirm-license -openssl-linked -qt-pcre -qt-sqlite -qt-zlib -feature-big_codecs -feature-codecs -no-icu -no-iconv -no-glib -no-opengl -no-dbus -no-gui -no-widgets -no-feature-testlib -no-compile-examples -ltcg -make libs -no-pch -nomake tests -nomake examples -no-xcb -static \
    && make -j"$(nproc)" \
    && make install \
    && popd || exit 1 \
    && rm -rf -- "/build_root/qtbase" \
    && dirs -c

FROM qtbase AS qttools
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && export PATH=/build_root/qbittorrent-build/bin:$PATH \
    && export CXXFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include -std=c++17" \
    && export CFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include" \
    && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -static-libgcc -static-libstdc++ -L/build_root/qbittorrent-build/lib" \
    # && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -Wl,--no-as-needed -L/build_root/qbittorrent-build/lib -lpthread -pthread" \
    && git_clone --branch "$qt_latest_tag_name" "https://github.com/qt/qttools.git" qttools \
    && pushd qttools || exit 1 \
    && "/build_root/qbittorrent-build/bin/qmake" -set prefix "/build_root/qbittorrent-build" \
    && "/build_root/qbittorrent-build/bin/qmake" QMAKE_CXXFLAGS="-static" QMAKE_LFLAGS="-static" \
    && make -j"$(nproc)" \
    && make install \
    && popd || exit 1 \
    && rm -rf -- "/build_root/qttools" \
    && dirs -c

FROM qttools AS qbee
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && export PATH=/build_root/qbittorrent-build/bin:$PATH \
    && export CXXFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include -std=c++17" \
    && export CFLAGS=" -O2 -pipe -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -fPIE --static -static -I/build_root/qbittorrent-build/include" \
    && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -static-pie -static-libgcc -static-libstdc++ -L/build_root/qbittorrent-build/lib" \
    # && export LDFLAGS=" -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs --static -static -static-pie -Wl,--no-as-needed -L/build_root/qbittorrent-build/lib -lpthread -pthread" \
    && mkdir qbee \
    && curl -sS "https://github.com/IceCodeNew/qBittorrent-Enhanced-Edition/archive/v4_3_x.tar.gz" | bsdtar -xf- -C qbee --strip-components 1 \
    && pushd qbee || exit 1 \
    && cmake -G "Ninja" -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/build_root/qbittorrent-build -DGUI=OFF -DVERBOSE_CONFIGURE=ON -DWEBUI=ON -DSTACKTRACE=OFF -DLibtorrentRasterbar_DIR=/build_root/qbittorrent-build/lib64/cmake/LibtorrentRasterbar -DBoost_DIR=/build_root/qbittorrent-build/lib/cmake/Boost-1.74.0 -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" -DOPENSSL_INCLUDE_DIR=/usr/include/openssl -DOPENSSL_CRYPTO_LIBRARY=/usr/lib/libcrypto.a -DOPENSSL_SSL_LIBRARY=/usr/lib/libssl.a -DZLIB_INCLUDE_DIR=/usr/include -DZLIB_LIBRARY=/lib/libz.a \
    # && cmake -G "Ninja" -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/build_root/qbittorrent-build -DGUI=OFF -DVERBOSE_CONFIGURE=ON -DWEBUI=ON -DSTACKTRACE=OFF -DLibtorrentRasterbar_DIR=/build_root/qbittorrent-build/lib64/cmake/LibtorrentRasterbar -DBoost_DIR=/build_root/qbittorrent-build/lib/cmake/Boost-1.74.0 -DCMAKE_EXE_LINKER_FLAGS="-static" -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
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
