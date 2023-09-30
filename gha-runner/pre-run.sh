#!/bin/bash

find /opt -type d -mindepth 1 -maxdepth 1 -print0 | xargs -0 sudo rm -rf
rm -rf "$GITHUB_WORKSPACE" && mkdir "$GITHUB_WORKSPACE"

# some tools like $HOME a little too much
TO_CLEAN=(.cabal opt .tea .pkgx)
for DIR in "${TO_CLEAN[@]}"; do
  if test -d "$HOME"/"$DIR"; then
    rm -rf "${HOME:?}"/"${DIR:?}" || true
  fi
done

find /tmp/ -mindepth 1 -maxdepth 1 -type d -name '????????' -exec sudo rm -rf {} \;
find /tmp/ -mindepth 1 -maxdepth 1 -type d -name 'xyz.tea.*' -exec sudo rm -rf {} \;
find /tmp/ -mindepth 1 -maxdepth 1 -type d -name 'dev.pkgx.*' -exec sudo rm -rf {} \;
find /tmp/ -mindepth 1 -maxdepth 1 -type d -name '??????' -exec sudo rm -rf {} \;
