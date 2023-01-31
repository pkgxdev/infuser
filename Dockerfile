FROM debian:buster-slim as stage0

RUN apt-get update
RUN apt-get install --yes curl sudo

RUN curl https://tea.xyz | TEA_YES=1 sh
RUN curl -Lo /root/.tea/install-pre-reqs.sh https://raw.githubusercontent.com/teaxyz/setup/main/install-pre-reqs.sh

FROM debian:buster-slim as stage1
COPY --from=stage0 /root/.tea /root/.tea
COPY --from=stage0 /usr/local/bin/tea /usr/local/bin/tea

RUN sh /root/.tea/install-pre-reqs.sh && rm /root/.tea/install-pre-reqs.sh
