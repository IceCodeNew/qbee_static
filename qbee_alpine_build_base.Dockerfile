FROM quay.io/icecodenew/builder_image_x86_64-linux:alpine AS base
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
ARG image_build_date='2022-03-06'

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV PKG_CONFIG_PATH=/build_root/qbittorrent-build/lib/pkgconfig
    # LDFLAGS='-fuse-ld=mold' \
    # CFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all' \
    # CXXFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all'

RUN apk update; apk --no-progress --no-cache add \
    icu-dev icu-static \
    boost-dev boost1.80-static; \
    apk --no-progress --no-cache upgrade; \
    rm -rf /var/cache/apk/*; \
    mkdir -p '/build_root/qbittorrent-build'

FROM base AS libtorrent-rasterbar
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/arvidn/libtorrent/commits?sha=RC_2_0&per_page=1
ARG libtorrent_latest_commit_hash='2e74b28750e8d41d114a96753b9c501cf64436c7'
ARG dockerfile_workdir=/build_root/rb_libtorrent
WORKDIR $dockerfile_workdir
RUN git clone -j "$(nproc)" --no-tags --shallow-submodules --recurse-submodules --depth 1 --single-branch --branch "RC_2_0" "https://github.com/arvidn/libtorrent.git" . \
    && CFLAGS="$CFLAGS -fPIC" \
    && CXXFLAGS="$CXXFLAGS -fPIC" \
    && export CFLAGS CXXFLAGS \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=/build_root/qbittorrent-build -G Ninja -B build \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" -DCMAKE_SKIP_RPATH=ON -DCMAKE_SKIP_INSTALL_RPATH=ON -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    -DBUILD_SHARED_LIBS=OFF -Dstatic_runtime=ON -Dencryption=ON -Ddeprecated-functions=OFF \
    && mold -run cmake --build build --parallel \
    && cmake --install build --strip \
    && rm -rf -- "$dockerfile_workdir"

FROM libtorrent-rasterbar AS qtbase
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/qt/qtbase/tags?per_page=100
ARG qt_full_tag_name='v6.2.3'
# grep -Po '(?<=v)[0-9]+\.[0-9]+(?=\.)' < <(echo $qtbase_latest_tag_name)
ARG qt_minor_tag_name='v6.2'
ARG dockerfile_workdir=/build_root/qtbase
WORKDIR $dockerfile_workdir
RUN curl --retry 5 --retry-delay 10 --retry-max-time 60 -fsSL "https://download.qt.io/official_releases/qt/6.2/6.2.3/submodules/qtbase-everywhere-src-6.2.3.tar.xz" | bsdtar -xf- --strip-components 1 \
    && CFLAGS="$CFLAGS -static -I/build_root/qbittorrent-build/include -fPIC" \
    && CPPFLAGS="$CPPFLAGS -static -I/build_root/qbittorrent-build/include -fPIC" \
    && CXXFLAGS="$CXXFLAGS -static -I/build_root/qbittorrent-build/include -fPIC" \
    && LDFLAGS="$LDFLAGS -static -L/build_root/qbittorrent-build/lib" \
    && export CFLAGS CPPFLAGS CXXFLAGS LDFLAGS \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=/build_root/qbittorrent-build -G Ninja -B build \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" -DCMAKE_SKIP_RPATH=ON -DCMAKE_SKIP_INSTALL_RPATH=ON -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    -DOPENSSL_INCLUDE_DIR=/usr/include/openssl -DOPENSSL_CRYPTO_LIBRARY=/usr/lib/libcrypto.a -DOPENSSL_SSL_LIBRARY=/usr/lib/libssl.a \
    -DZLIB_INCLUDE_DIR=/usr/include -DZLIB_LIBRARY=/usr/lib/libz.a \
    -DBUILD_SHARED_LIBS=OFF -DFEATURE_static_runtime=ON \
    -DQT_FEATURE_optimize_full=ON -DQT_FEATURE_static=ON -DQT_FEATURE_shared=OFF \
    -DFEATURE_gui=OFF -DQT_FEATURE_openssl_linked=ON -DQT_FEATURE_dbus=OFF -DQT_FEATURE_system_pcre2=OFF -DQT_FEATURE_widgets=OFF -DQT_FEATURE_testlib=OFF \
    -DQT_BUILD_TESTS=OFF -DQT_BUILD_EXAMPLES=OFF \
    && sed -i -E -e 's|\.so|\.a|g' build/build.ninja \
    && mold -run cmake --build build --parallel \
    && cmake --install build --strip \
    && rm -rf -- "$dockerfile_workdir"

FROM qtbase AS qttools
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/qt/qtbase/tags?per_page=100
ARG qt_full_tag_name='v6.2.3'
# grep -Po '(?<=v)[0-9]+\.[0-9]+(?=\.)' < <(echo $qtbase_latest_tag_name)
ARG qt_minor_tag_name='v6.2'
ARG dockerfile_workdir=/build_root/qttools
WORKDIR $dockerfile_workdir
RUN curl --retry 5 --retry-delay 10 --retry-max-time 60 -fsSL "https://download.qt.io/official_releases/qt/6.2/6.2.3/submodules/qttools-everywhere-src-6.2.3.tar.xz" | bsdtar -xf- --strip-components 1 \
    && CFLAGS="$CFLAGS -static -I/build_root/qbittorrent-build/include -fPIC" \
    && CPPFLAGS="$CPPFLAGS -static -I/build_root/qbittorrent-build/include -fPIC" \
    && CXXFLAGS="$CXXFLAGS -static -I/build_root/qbittorrent-build/include -fPIC" \
    && LDFLAGS="$LDFLAGS -static -L/build_root/qbittorrent-build/lib" \
    && export CFLAGS CPPFLAGS CXXFLAGS LDFLAGS \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=/build_root/qbittorrent-build -G Ninja -B build \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" -DCMAKE_SKIP_RPATH=ON -DCMAKE_SKIP_INSTALL_RPATH=ON -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    -DOPENSSL_INCLUDE_DIR=/usr/include/openssl -DOPENSSL_CRYPTO_LIBRARY=/usr/lib/libcrypto.a -DOPENSSL_SSL_LIBRARY=/usr/lib/libssl.a \
    -DZLIB_INCLUDE_DIR=/usr/include -DZLIB_LIBRARY=/usr/lib/libz.a \
    -DBUILD_SHARED_LIBS=OFF -DFEATURE_static_runtime=ON \
    && sed -i -E -e 's|\.so|\.a|g' build/build.ninja \
    && mold -run cmake --build build --parallel \
    && cmake --install build --strip \
    && rm -rf -- "$dockerfile_workdir"
