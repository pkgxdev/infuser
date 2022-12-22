FROM debian:stretch-slim as stage0
ARG vDENO=1.29.1
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
FROM debian:stretch-slim as stage1
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
    ninja-build.org/v1.0.0 \
    curl.se/v6.0.0 \
    openssl.org/v1.1.0 \
    perl.org/v5.0.0 \
    zlib.net/v1.0.0 \
    tea.xyz/gx/cc/v0.1.0 \
    gnu.org/tar/v1.0.0 \
  ; \
  do \
    mkdir -p /opt/$x; \
    touch /opt/$x/trick-tea-is-installed; \
  done

RUN apt-get update
RUN apt-get install --yes make cmake ninja-build python3 clang-11 perl patchelf curl g++

RUN mkdir .git
# ^^ trick tea into finding SRCROOT

RUN tea --sync

ADD cli/scripts/repair.ts                             scripts

# Work around old versions of `env` not supporting --split
RUN mv /usr/bin/env /usr/bin/env.bak
ADD infuser/bootstrap/env /usr/bin/env
RUN chmod +x /usr/bin/env

# chmod will complain about dangling symlinks, but that's ok
RUN scripts/build.plumbing.ts tea.xyz/gx/cc || true

RUN scripts/build.plumbing.ts gnu.org/m4
RUN scripts/build.plumbing.ts gnu.org/make
RUN scripts/build.plumbing.ts gnu.org/tar
RUN scripts/build.plumbing.ts freedesktop.org/pkg-config
RUN scripts/build.plumbing.ts invisible-island.net/ncurses
RUN scripts/build.plumbing.ts gnu.org/readline
RUN scripts/build.plumbing.ts zlib.net
RUN scripts/build.plumbing.ts sourceware.org/bzip2
RUN scripts/build.plumbing.ts sourceware.org/libffi
RUN scripts/build.plumbing.ts libexpat.github.io
RUN scripts/build.plumbing.ts bytereef.org/mpdecimal
RUN scripts/build.plumbing.ts tukaani.org/xz
RUN scripts/build.plumbing.ts sqlite.org
RUN scripts/build.plumbing.ts gnome.org/libxml2
RUN scripts/build.plumbing.ts gnu.org/gettext
RUN scripts/build.plumbing.ts git-scm.org
RUN scripts/build.plumbing.ts openssl.org
RUN scripts/build.plumbing.ts curl.se
RUN scripts/build.plumbing.ts cmake.org

# llvm^15 doesn't agree with 10% of our corpus
RUN scripts/build.plumbing.ts llvm.org^14

RUN scripts/build.plumbing.ts tea.xyz
RUN scripts/build.plumbing.ts darwinsys.com/file
RUN scripts/build.plumbing.ts gnu.org/autoconf
RUN scripts/build.plumbing.ts gnu.org/automake
RUN scripts/build.plumbing.ts nixos.org/patchelf=0.13.1

RUN scripts/repair.ts deno.land tea.xyz

RUN cd /opt && rm -rf \
  llvm.org/v14.0.0 \
  gnu.org/make/v4.0.0 \
  python.org \
  ninja-build.org \
  gnu.org/m4 \
  curl.se/v6.0.0 \
  openssl.org/v1.1.0 \
  perl.org

RUN find /opt -name src | xargs rm -rf
RUN rm -rf /opt/tea.xyz/var/www


#------------------------------------------------------------------------------
FROM debian:stretch-slim as stage2

COPY --from=stage1 /opt /opt

RUN \
  ln -s /opt/tea.xyz/v'*'/bin/tea /usr/local/bin/tea && \
  apt-get update && \
  apt-get install --yes libc-dev libstdc++-6-dev libgcc-6-dev && \
  #FIXME for opening tarballs
  # apt-get install --yes bzip2 xz-utils && \
  mv /usr/bin/env /usr/bin/env.bak
ADD infuser/bootstrap/env /usr/bin/env
RUN chmod +x /usr/bin/env
