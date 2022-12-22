FROM debian:stretch-slim as stage0

RUN apt-get update
RUN apt-get install --yes curl sudo

RUN curl https://tea.xyz | YES=1 sh

FROM debian:stretch-slim as stage1
COPY --from=stage0 /root/.tea /root/.tea
COPY --from=stage0 /usr/local/bin/tea /usr/local/bin/tea

RUN apt-get update \
 && apt-get --yes install libc-dev libstdc++-8-dev libgcc-8-dev sudo \
 && ln -sf /usr/local/bin/tea /usr/bin/env
