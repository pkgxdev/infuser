#!/bin/bash

find /opt -mindepth 1 -maxdepth 1 -print0 | xargs -0 rm -rf
rm -rf "$GITHUB_WORKSPACE" && mkdir "$GITHUB_WORKSPACE"