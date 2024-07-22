FROM ubuntu:22.04 AS proest-base-22
LABEL Name=proest-base-22

# Install basic packages
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \ 
    git \
    software-properties-common \
    libc6-dev \
    libffi-dev \
    libgdbm-dev \
    libgmp-dev \
    libjpeg-dev \
    libleptonica-dev \
    libncurses5-dev \
    libopencv-dev \
    libpng-dev \
    libpq-dev \
    libreadline-dev \
    libspdlog-dev \
    libsqlite3-dev \
    libssl-dev \
    libyaml-dev \
    librsvg2-bin \
    tesseract-ocr \
    zlib1g-dev \
    autoconf \
    automake \
    bison \
    curl \
    imagemagick \
    libtool \
    make \
    mediainfo \
    ninja-build \
    pkg-config \
    postgresql-client \
    poppler-utils \
    sqlite3 \
    tar \
    unzip \
    wget \
    zip \
    openssl \
    && echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula boolean true" | debconf-set-selections \
    && apt-get install -y --no-install-recommends \
    ttf-mscorefonts-installer \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# install Node v16 binary from nodesource
# TODO: target v20 and webpacker updates
ENV NODE_MAJOR=16
RUN set -uex && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg \
    --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" \
 > /etc/apt/sources.list.d/nodesource.list && \
    apt-get -y update  && \
    apt-get -y install --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# TODO: Propably we should remove it eventually. There is a first-stage openssl 3.0.2 installation 
# and this version is required by the proest_native libs 

# Build OpenSSL 3.0.8 from source
# WORKDIR /usr/local/src/
# RUN wget https://www.openssl.org/source/old/3.0/openssl-3.0.8.tar.gz
# RUN tar -zxf openssl-3.0.8.tar.gz
# WORKDIR /usr/local/src/openssl-3.0.8
# RUN ./config
# RUN make
# RUN make install_sw install_ssldirs

# Install Ruby - copied from offical Docker image
# https://github.com/docker-library/ruby/blob/cdac1ffbc959768a5b82014dbb8c8006fe6f7880/2.7/bullseye/Dockerfile

# skip installing gem documentation
RUN set -eux; \
    mkdir -p /usr/local/etc; \
    { \
        echo 'install: --no-document'; \
        echo 'update: --no-document'; \
    } >> /usr/local/etc/gemrc

ENV LANG=C.UTF-8
ENV RUBY_MAJOR=3.3
ENV RUBY_VERSION=3.3.0
ENV RUBY_DOWNLOAD_SHA256=676b65a36e637e90f982b57b059189b3276b9045034dcd186a7e9078847b975b

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -eux; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        dpkg-dev \
        ruby \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    \
    wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz"; \
    echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum --check --strict; \
    \
    mkdir -p /usr/src/ruby; \
    tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1; \
    rm ruby.tar.xz; \
    \
    cd /usr/src/ruby; \
    \
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
    { \
        echo '#define ENABLE_PATH_CHECK 0'; \
        echo; \
        cat file.c; \
    } > file.c.new; \
    mv file.c.new file.c; \
    \
    autoconf; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    ./configure \
        --build="$gnuArch" \
        --disable-install-doc \
        --enable-shared \
    ; \
    make -j "$(nproc)"; \
    make install; \
    \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark > /dev/null; \
    find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
        | awk '/=>/ { print $(NF-1) }' \
        | sort -u \
        | grep -vE '^/usr/local/lib/' \
        | xargs -r dpkg-query --search \
        | cut -d: -f1 \
        | sort -u \
        | xargs -r apt-mark manual \
    ; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    \
    cd /; \
    rm -r /usr/src/ruby; \
# verify we have no "ruby" packages installed
    if dpkg -l | grep -i ruby; then exit 1; fi; \
    [ "$(command -v ruby)" = '/usr/local/bin/ruby' ]; \
# rough smoke test
    ruby --version; \
    gem --version; \
    bundle --version

# don't create ".bundle" in all our apps
ENV GEM_HOME=/usr/local/bundle
ENV BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH=$GEM_HOME/bin:$PATH
# adjust permissions of a few directories for running "gem install" as an arbitrary user
RUN mkdir -p "$GEM_HOME" && chmod 777 "$GEM_HOME"
# -- END PASTE FROM RUBY DOCKERFILE


# -------------------- Native Libs

FROM proest-base-22 AS proest-buildlibs-22
LABEL Name=proest-buildlibs-22

ARG VCPKG_BRANCH=2024.07.12

# Set VCPKG environment variables
ENV VCPKG_MANIFEST_DIR=/proest_libs/proest_vcpkg
ENV CMAKE_TOOLCHAIN_FILE=/proest_libs/proest_vcpkg/scripts/buildsystems/vcpkg.cmake
ENV CMAKE_BUILD_TYPE=Release
ENV VCPKG_FORCE_SYSTEM_BINARIES=1

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    g++ \
    gcc \
    cmake \
    git \
    nuget \
    && rm -rf /var/lib/apt/lists/*

# Copy the source code
COPY proest_native/ /proest_libs

# TODO: After removing proest_vcpkg submodule the line "rm -rf /proest_libs/proest_vcpkg;" will not be needed
# Clone and bootstrap vcpkg
RUN set -eux; \
    rm -rf /proest_libs/proest_vcpkg; \
    git clone --branch ${VCPKG_BRANCH} https://github.com/microsoft/vcpkg ${VCPKG_MANIFEST_DIR}; \
    git -C ${VCPKG_MANIFEST_DIR} fetch;\
    .${VCPKG_MANIFEST_DIR}/bootstrap-vcpkg.sh

# Install dependencies using vcpkg
WORKDIR /proest_libs/proest_vcpkg
COPY vcpkg.json .
RUN ./vcpkg install && \
    ./vcpkg integrate install
