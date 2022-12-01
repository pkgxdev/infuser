#!/bin/bash

find /opt -mindepth 1 -maxdepth 1 -print0 | xargs -0 rm -rf
rm -rf "$GITHUB_WORKSPACE" && mkdir "$GITHUB_WORKSPACE"

# some tools like $HOME a little too much
test -d "$HOME"/.cabal && rm -rf "$HOME"/.cabal