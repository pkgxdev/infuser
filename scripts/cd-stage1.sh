#!/bin/bash

set -euxo pipefail

export TEA_PREFIX=${TEA_PREFIX:=/opt}

cd $TEA_PREFIX/tea.xyz/var/pantry

## Ensure clean environments
find $TEA_PREFIX -maxdepth 1 -mindepth 1 -type d ! -name tea.xyz ! -name aws -exec rm -rf {} \;
if test -d $TEA_PREFIX/tea.xyz/var/www; then
  find $TEA_PREFIX/tea.xyz/var/www/ -type f -exec rm {} \;
fi

if test $# -eq 1; then
  PACKAGE_SPEC=$1
else
  PACKAGE_SPEC=$1@$2
fi

# Make sure `tea` is in our PATH
PATH=$PATH:~/.tea/tea.xyz/v'*'/bin

REQS=$(GITHUB_ACTIONS=1 ./scripts/sort.ts "$PACKAGE_SPEC" | sed -ne 's/::set-output name=pre-install:://p')

if test ! -z "$REQS"; then
  # shellcheck disable=SC2086
  # We want to split on spaces here
  echo $REQS | xargs ../cli/scripts/install.ts
fi

BUILT=$(./scripts/build.ts "$PACKAGE_SPEC" | sed -ne 's/::set-output name=pkgs:://p')

# As designed, there will only be one package built per invocation,
# but that's no reason to assume it will always be that way.
for PKG in $BUILT; do
  ./scripts/test.ts "$PKG"

  for COMPRESSION in gz xz; do
    export COMPRESSION
    FILES=$(./scripts/bottle.ts "$PKG" | sed -ne 's/::set-output name=bottles::/--bottles /p' -e 's/::set-output name=checksums::/--checksums /p')

    # shellcheck disable=SC2086
    echo --pkgs $BUILT $FILES | xargs ./scripts/upload.ts
  done
done