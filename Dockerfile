FROM debian:buster-slim as stage0

RUN apt-get update
RUN apt-get install --yes curl sudo

RUN curl https://tea.xyz | sh
RUN echo 'export PS1="\\[\\033[38;5;86m\\]tea\\[\\033[0m\\] $ "' >> /root/.bashrc
RUN tea integrate

FROM debian:buster-slim as stage1
COPY --from=stage0 /root/.bashrc /root/.bashrc
COPY --from=stage0 /usr/local/bin/tea /usr/local/bin/tea

RUN apt-get update && apt-get install libatomic1

CMD ["bash"]
