FROM quay.io/icecodenew/alpine:latest AS base
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
# https://api.github.com/repos/IceCodeNew/myrc/commits?per_page=1&path=.bashrc
ARG bashrc_latest_commit_hash=5099c0e08cb1712bde0c90e847b7ebedcb9088ce
## curl -sSL "https://ftpmirror.gnu.org/parallel/" | tr -d '\r\n\t' | grep -Po '(?<=parallel-)[0-9]+(?=\.tar\.bz2)' | sort -Vr | tail -n 1
ARG parallel_version=20210422
## curl -sSL 'https://raw.githubusercontent.com/openssl/openssl/OpenSSL_1_1_1-stable/README' | grep -Eo '1.1.1.*'
ARG openssl_latest_tag_name=1.1.1l-dev
# https://api.github.com/repos/Kitware/CMake/releases/latest
ARG cmake_latest_tag_name=v3.20.2
# https://api.github.com/repos/ninja-build/ninja/releases/latest
ARG ninja_latest_tag_name=v1.10.2
# https://api.github.com/repos/sabotage-linux/netbsd-curses/releases/latest
ARG netbsd_curses_tag_name=0.3.1
# https://api.github.com/repos/sabotage-linux/gettext-tiny/releases/latest
ARG gettext_tiny_tag_name=0.3.2

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PKG_CONFIG=/usr/bin/pkgconf \
    PKG_CONFIG_PATH=/build_root/qbittorrent-build/lib/pkgconfig

RUN apk update; apk --no-progress --no-cache add \
    apk-tools autoconf automake bash binutils build-base ca-certificates cmake coreutils curl dos2unix file gettext-tiny-dev git grep libarchive-tools libedit-dev libedit-static libtool linux-headers musl musl-dev musl-libintl musl-utils ncurses ncurses-dev ncurses-static openssl openssl-dev openssl-libs-static parallel perl pkgconf samurai sed util-linux zlib-dev zlib-static; \
    apk --no-progress --no-cache upgrade; \
    rm -rf /var/cache/apk/*; \
    curl -sSLR4q --retry 5 --retry-delay 10 --retry-max-time 60 -o '/root/.bashrc' "https://raw.githubusercontent.com/IceCodeNew/myrc/${bashrc_latest_commit_hash}/.bashrc"; \
    mkdir -p '/build_root/qbittorrent-build'; \
    mkdir -p "$HOME/.parallel"; \
    touch "$HOME/.parallel/will-cite"

FROM base AS boost
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV boost_version='1.76.0' \
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
    && curl -sS "https://boostorg.jfrog.io/artifactory/main/release/${boost_version}/source/boost_${boost_version//./_}.tar.bz2" | bsdtar -xf- -C boost --strip-components 1 \
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
ENV qt_latest_tag_name='v5.15.2'
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
