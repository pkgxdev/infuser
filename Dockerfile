FROM debian:buster-slim as stage0
ARG vDENO=1.23.3
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
RUN unzip deno.zip -d /usr/local/bin

ADD cli /cli

RUN deno compile \
  --allow-read --allow-write=/opt --allow-net --allow-run --allow-env \
  --import-map=/cli/import-map.json \
  --output /usr/local/bin/tea \
  /cli/src/app.ts



#------------------------------------------------------------------------------
FROM debian:buster-slim as stage1
ARG vDENO=1.23.3
ARG GITHUB_TOKEN
ENV GITHUB_TOKEN=$GITHUB_TOKEN

COPY --from=stage0 /usr/local/bin/tea /usr/local/bin/tea
COPY --from=stage0 /usr/local/bin/deno /opt/deno.land/v$vDENO/bin/deno
ADD pantry /opt/tea.xyz/var/pantry

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

COPY --from=stage0 /cli /cli
WORKDIR /cli
# ^^ because tea currently requires scripts have working directory inside $SRCROOT

RUN scripts/build.ts gnu.org/m4
RUN scripts/build.ts gnu.org/make
RUN scripts/build.ts llvm.org
RUN scripts/repair.ts deno.land

RUN cd /opt && rm -rf \
  llvm.org/v14.0.0 \
  gnu.org/make/v4.0.0 \
  python.org \
  cmake.org \
  ninja-build.org \
  gnu.org/m4

RUN find /opt -name src | xargs rm -rf
RUN rm -rf /opt/tea.xyz


#------------------------------------------------------------------------------
FROM debian:buster-slim as stage2

COPY --from=stage1 /usr/local/bin/tea /usr/local/bin/tea
COPY --from=stage1 /opt /opt
ADD pantry /opt/tea.xyz/var/pantry

RUN \
  apt-get update && \
  apt-get install --yes libc-dev libstdc++-8-dev libgcc-8-dev && \
  #FIXME for opening tarballs
  apt-get install --yes bzip2 xz-utils && \
  #FIXME for manipulating rpaths
  apt-get install --yes patchelf && \
  #FIXME when we’re game, we should do this ourselves, but only for linux
  # so probs tea.xyz/gx/ca-certificates
  apt-get --yes install ca-certificates

COPY --from=stage0 /cli /cli
WORKDIR /cli
# ^^ because tea currently requires scripts have working directory inside $SRCROOT
