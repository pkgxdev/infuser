FROM debian:buster-slim as stage0
ARG vDENO=1.27.0
ARG GITHUB_TOKEN
ENV GITHUB_TOKEN=$GITHUB_TOKEN

SHELL ["/bin/bash", "-c"]

RUN apt-get update
RUN apt-get install --yes curl unzip

RUN \
  case $(uname -m) in \
  x86_64) \
    URL=https://github.com/denoland/deno/releases/download/v$vDENO/deno-x86_64-unknown-linux-gnu.zip;; \
  aarch64) \
    URL=https://github.com/LukeChannings/deno-arm64/releases/download/v$vDENO/deno-linux-arm64.zip;; \
  *) \
    echo "Unsupported architecture: $(uname -m)"; exit 1;; \
  esac; \
  curl -Lo deno.zip "$URL"
RUN mkdir -p /opt/deno.land/v$vDENO/bin
RUN unzip deno.zip -d /opt/deno.land/v$vDENO/bin

ADD cli /cli
WORKDIR /cli

RUN /opt/deno.land/v$vDENO/bin/deno compile \
  --allow-read --allow-write=/opt --allow-net --allow-run --allow-env \
  --import-map=/cli/import-map.json \
  --unstable \
  --output tea \
  src/app.ts

#FIXME: $VERSION not currently being set.
RUN source <(./tea -Eds) \
  && /bin/mkdir -p /opt/tea.xyz/v$VERSION/bin \
  && /bin/mv tea /opt/tea.xyz/v$VERSION/bin \
  && cd /opt/tea.xyz && /bin/ln -s v$VERSION 'v*'

#------------------------------------------------------------------------------
FROM debian:buster-slim as stage1
ARG GITHUB_TOKEN
ENV GITHUB_TOKEN=$GITHUB_TOKEN

WORKDIR /opt/tea.xyz/var/pantry

COPY --from=stage0 /opt /opt
COPY --from=stage0 /cli/src src
COPY --from=stage0 /cli /cli

RUN ln -s /opt/tea.xyz/'v*'/bin/tea /usr/local/bin/tea

# make tea think these are already installed
RUN \
  for x in \
    llvm.org/v14.0.0 \
    gnu.org/make/v4.0.0 \
    python.org/v3.0.0 \
    cmake.org/v3.0.0 \
    ninja-build.org/v1.0.0 \
    curl.se/v6.0.0 \
    openssl.org/v1.1.0 \
    perl.org/v5.0.0 \
  ; \
  do \
    mkdir -p /opt/$x; \
    touch /opt/$x/trick-tea-is-installed; \
  done

RUN apt-get update
RUN apt-get install --yes make cmake ninja-build python3 clang perl patchelf curl

ADD pantry.core/projects/llvm.org                     projects/llvm.org
ADD pantry.core/projects/deno.land                    projects/deno.land
ADD pantry.core/scripts/build.ts                      scripts/build.ts
ADD pantry.core/scripts/fetch.ts                      scripts/fetch.ts
ADD pantry.core/scripts/brewkit                       scripts/brewkit
ADD pantry.core/scripts/build                         scripts/build
ADD pantry.core/scripts/utils                         scripts/utils
ADD pantry.core/import-map.json                       import-map.json
ADD cli/scripts/repair.ts                             scripts
ADD pantry.core/README.md                             README.md

RUN mkdir .git
# ^^ trick tea into finding SRCROOT

# gnu.org/m4
ADD pantry.core/projects/gnu.org/m4                   projects/gnu.org/m4
ADD pantry.core/projects/sourceware.org/bzip2         projects/sourceware.org/bzip2
ADD pantry.core/projects/darwinsys.com/file           projects/darwinsys.com/file
ADD pantry.extra/projects/nixos.org/patchelf          projects/nixos.org/patchelf
ADD pantry.core/projects/tukaani.org/xz               projects/tukaani.org/xz
ADD pantry.core/projects/tea.xyz/gx/cc                projects/tea.xyz/gx/cc
ADD pantry.core/projects/gnu.org/make                 projects/gnu.org/make
ADD pantry.core/projects/gnu.org/tar                  projects/gnu.org/tar
ADD pantry.core/projects/zlib.net                     projects/zlib.net
RUN scripts/build.ts gnu.org/m4

# gnu.org/make
ADD pantry.core/projects/freedesktop.org/pkg-config   projects/freedesktop.org/pkg-config
RUN scripts/build.ts gnu.org/make

# freedesktop.org/pkg-config
RUN scripts/build.ts freedesktop.org/pkg-config

# invisible-island.net/ncurses
ADD pantry.core/projects/invisible-island.net/ncurses projects/invisible-island.net/ncurses
RUN scripts/build.ts invisible-island.net/ncurses

# gnu.org/readline
ADD pantry.core/projects/gnu.org/readline             projects/gnu.org/readline
RUN scripts/build.ts gnu.org/readline

# zlib.net
RUN scripts/build.ts zlib.net

# sourceware.org/bzip2
RUN scripts/build.ts sourceware.org/bzip2

# sourceware.org/libffi
ADD pantry.core/projects/sourceware.org/libffi        projects/sourceware.org/libffi
RUN scripts/build.ts sourceware.org/libffi

# libexpat.github.io
ADD pantry.core/projects/libexpat.github.io           projects/libexpat.github.io
RUN scripts/build.ts libexpat.github.io

# bytereef.org/mpdecimal
ADD pantry.core/projects/bytereef.org/mpdecimal       projects/bytereef.org/mpdecimal
RUN scripts/build.ts bytereef.org/mpdecimal

# tukaani.org/xz
RUN scripts/build.ts tukaani.org/xz

# sqlite.org
ADD pantry.core/projects/sqlite.org                   projects/sqlite.org
RUN scripts/build.ts sqlite.org

# llvm.org
ADD pantry.core/projects/cmake.org                    projects/cmake.org
ADD pantry.core/projects/ninja-build.org              projects/ninja-build.org
ADD pantry.core/projects/openssl.org                  projects/openssl.org
ADD pantry.core/projects/python.org                   projects/python.org
ADD pantry.core/projects/curl.se                      projects/curl.se
RUN scripts/build.ts llvm.org

# gnome.org/libxml2
ADD pantry.extra/projects/gnome.org/libxml2            projects/gnome.org/libxml2
RUN scripts/build.ts gnome.org/libxml2

# gnu.org/gettext
ADD pantry.core/projects/gnu.org/gettext              projects/gnu.org/gettext
RUN scripts/build.ts gnu.org/gettext

# git-scm.org
ADD pantry.core/projects/git-scm.org                  projects/git-scm.org
ADD pantry.core/projects/perl.org                     projects/perl.org
RUN scripts/build.ts git-scm.org

# openssl.org
RUN scripts/build.ts openssl.org

# curl.se
RUN scripts/build.ts curl.se

# tea.xyz
ADD pantry.core/projects/tea.xyz                      projects/tea.xyz
RUN scripts/build.ts tea.xyz

# nixos.org/patchelf
RUN scripts/build.ts nixos.org/patchelf

# darwinsys.com/file
RUN scripts/build.ts darwinsys.com/file

RUN scripts/repair.ts deno.land tea.xyz

RUN cd /opt && rm -rf \
  llvm.org/v14.0.0 \
  gnu.org/make/v4.0.0 \
  python.org \
  cmake.org \
  ninja-build.org \
  gnu.org/m4 \
  curl.se/v6.0.0 \
  openssl.org/v1.1.0 \
  perl.org

RUN find /opt -name src | xargs rm -rf
RUN rm -rf /opt/tea.xyz/var/www


#------------------------------------------------------------------------------
FROM debian:buster-slim as stage2

COPY --from=stage1 /opt /opt
ADD pantry.core /opt/tea.xyz/var/pantry

RUN \
  ln -s /opt/tea.xyz/v'*'/bin/tea /usr/local/bin/tea && \
  apt-get update && \
  apt-get install --yes libc-dev libstdc++-8-dev libgcc-8-dev && \
  #FIXME for opening tarballs
  apt-get install --yes bzip2 xz-utils && \
  # required on aarch64 by `ghcup`
  apt-get --yes install libnuma1
