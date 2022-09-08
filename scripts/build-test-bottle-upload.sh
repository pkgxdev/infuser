#!/bin/bash

set -euxo pipefail

cd /opt/tea.xyz/var/pantry

## Ensure clean environments
find /opt -maxdepth 1 -mindepth 1 -type d ! -name tea.xyz -exec rm -rf {} \;
if test -d /opt/tea.xyz/var/www; then
  find /opt/tea.xyz/var/www/ -type f -exec rm {} \;
fi

if test $# -eq 1; then
  PACKAGE_SPEC=$1
else
  PACKAGE_SPEC=$1@$2
fi

REQS=$(GITHUB_ACTIONS=1 ./scripts/sort.ts "$PACKAGE_SPEC" | sed -ne 's/::set-output name=pre-install:://p')

if test ! -z "$REQS"; then
  # shellcheck disable=SC2086
  # We want to split on spaces here
  ./scripts/install.ts $REQS
fi

BUILT=$(./scripts/build.ts "$PACKAGE_SPEC" | sed -ne 's/::set-output name=pkgs:://p')

# As designed, there will only be one package built per invocation,
# but that's no reason to assume it will always be that way.
for PKG in $BUILT; do
  ./scripts/test.ts "$PKG"

  FILES=$(./scripts/bottle.ts "$PKG" | sed -ne 's/::set-output name=bottles:://p')

  # shellcheck disable=SC2086
  ./scripts/upload.ts $FILES
done