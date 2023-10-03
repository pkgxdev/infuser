FROM debian:buster-slim as stage0

RUN apt-get update
RUN apt-get install --yes curl sudo

RUN curl -fsS https://pkgx.sh | sh
RUN echo 'export PS1="\\[\\033[38;5;86m\\]pkgx\\[\\033[0m\\] $ "' >> /root/.bashrc
RUN pkgx integrate

FROM debian:buster-slim as stage1
COPY --from=stage0 /root/.bashrc /root/.bashrc
COPY --from=stage0 /usr/local/bin/pkgx /usr/local/bin/pkgx

RUN apt-get update && apt-get install libatomic1

CMD ["bash"]
