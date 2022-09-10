FROM debian:buster-slim as stage0
ARG vDENO=1.25.0
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
WORKDIR cli

RUN /opt/deno.land/v$vDENO/bin/deno compile \
  --allow-read --allow-write=/opt --allow-net --allow-run --allow-env \
  --import-map=/cli/import-map.json \
  --output tea \
  src/app.ts

RUN source <(./tea -Eds) \
 && /bin/mkdir -p /opt/tea.xyz/v$VERSION/bin \
 && /bin/mv tea /opt/tea.xyz/v$VERSION/bin


#------------------------------------------------------------------------------
FROM debian:buster-slim as stage1
ARG GITHUB_TOKEN
ENV GITHUB_TOKEN=$GITHUB_TOKEN

WORKDIR /opt/tea.xyz/var/pantry

COPY --from=stage0 /opt /opt
COPY --from=stage0 /cli/src src

RUN ln -s /opt/tea.xyz/v*/bin/tea /usr/local/bin/tea

# make tea think these are already installed
RUN \
  for x in \
    llvm.org/v14.0.0 \
    gnu.org/make/v4.0.0 \
    python.org/v3.0.0 \
    cmake.org/v3.0.0 \
    ninja-build.org/v1.0.0 \
    ; \
  do \
    mkdir -p /opt/$x; \
    touch /opt/$x/trick-tea-is-installed; \
  done

RUN apt-get update
RUN apt-get install --yes make cmake ninja-build python3 clang perl patchelf

ADD pantry/projects/freedesktop.org/pkg-config   projects/freedesktop.org/pkg-config
ADD pantry/projects/perl.org                     projects/perl.org
ADD pantry/projects/openssl.org                  projects/openssl.org
ADD pantry/projects/invisible-island.net/ncurses projects/invisible-island.net/ncurses
ADD pantry/projects/zlib.net                     projects/zlib.net
ADD pantry/projects/sourceware.org/bzip2         projects/sourceware.org/bzip2
ADD pantry/projects/gnu.org/readline             projects/gnu.org/readline
ADD pantry/projects/curl.se                      projects/curl.se
ADD pantry/projects/cmake.org                    projects/cmake.org
ADD pantry/projects/sourceware.org/libffi        projects/sourceware.org/libffi
ADD pantry/projects/libexpat.github.io           projects/libexpat.github.io
ADD pantry/projects/bytereef.org/mpdecimal       projects/bytereef.org/mpdecimal
ADD pantry/projects/tukaani.org/xz               projects/tukaani.org/xz
ADD pantry/projects/sqlite.org                   projects/sqlite.org
ADD pantry/projects/python.org                   projects/python.org
ADD pantry/projects/ninja-build.org              projects/ninja-build.org
ADD pantry/projects/gnu.org/m4                   projects/gnu.org/m4
ADD pantry/projects/rust-lang.org                projects/rust-lang.org
ADD pantry/projects/llvm.org                     projects/llvm.org
ADD pantry/projects/gnu.org/make                 projects/gnu.org/make
ADD pantry/projects/deno.land                    projects/deno.land
ADD pantry/scripts/build.ts                      scripts/build.ts
ADD pantry/import-map.json                       import-map.json
ADD pantry/scripts/repair.ts                     scripts
ADD pantry/README.md                             README.md

RUN mkdir .git
# ^^ trick tea into finding SRCROOT

RUN scripts/build.ts gnu.org/m4
RUN scripts/build.ts gnu.org/make
RUN scripts/build.ts llvm.org
RUN scripts/repair.ts deno.land tea.xyz

RUN cd /opt && rm -rf \
  llvm.org/v14.0.0 \
  gnu.org/make/v4.0.0 \
  python.org \
  cmake.org \
  ninja-build.org \
  gnu.org/m4

RUN find /opt -name src | xargs rm -rf
RUN rm -rf /opt/tea.xyz/var/www


#------------------------------------------------------------------------------
FROM debian:buster-slim as stage2

COPY --from=stage1 /opt /opt

RUN \
  ln -s /opt/tea.xyz/v0/bin/tea /usr/local/bin/tea && \
  apt-get update && \
  apt-get install --yes libc-dev libstdc++-8-dev libgcc-8-dev && \
  #FIXME for opening tarballs
  apt-get install --yes bzip2 xz-utils && \
  # required by build infra
  apt-get --yes install patchelf file && \
  # required on aarch64 by `ghcup`
  apt-get --yes install libnuma1
