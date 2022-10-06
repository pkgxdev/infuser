#!/bin/bash

set -euxo pipefail

export TEA_PREFIX=${TEA_PREFIX:=/opt}

cd $TEA_PREFIX/tea.xyz/var/pantry

## Ensure clean environments
find $TEA_PREFIX -maxdepth 1 -mindepth 1 -type d ! -name tea.xyz ! -name aws ! -name deno.land -exec rm -rf {} \;
if test -d $TEA_PREFIX/tea.xyz/var/www; then
  find $TEA_PREFIX/tea.xyz/var/www/ -type f -exec rm {} \;
fi

if test -f /usr/bin/aws; then
  AWS=/usr/bin/aws
elif test -f /usr/local/bin/aws; then
  AWS=/usr/local/bin/aws
else
  echo "aws cli not found. exiting."
  exit 1
fi

# Make sure `tea` is in our PATH
PATH=$PATH:$TEA_PREFIX/tea.xyz/v'*'/bin

PACKAGE_SPEC=$1

REQS=$(GITHUB_ACTIONS=1 ./scripts/sort.ts "$PACKAGE_SPEC" | sed -ne 's/::set-output name=pre-install:://p')

if test ! -z "$REQS"; then
  # shellcheck disable=SC2086
  # We want to split on spaces here
  echo $REQS | xargs ../cli/scripts/install.ts
fi

OUT=$(./scripts/build.ts "$PACKAGE_SPEC")

BUILT=$(echo "$OUT" | sed -ne 's/::set-output name=pkgs:://p')
SRCS=$(echo "$OUT" | sed -ne 's/::set-output name=srcs:://p')

# As designed, there will only be one package built per invocation,
# but that's no reason to assume it will always be that way.
for PKG in $BUILT; do
  ./scripts/test.ts "$PKG"

  for COMPRESSION in gz xz; do
    export COMPRESSION

    OUT=$(./scripts/bottle.ts "$PKG")
    BOTTLES=$(echo "$OUT" | sed -ne 's/::set-output name=bottles:://p')
    CHECKSUMS=$(echo "$OUT" | sed -ne 's/::set-output name=checksums:://p')

    # shellcheck disable=SC2086
    CF=$(echo --pkgs $BUILT --srcs $SRCS --bottles $BOTTLES --checksums $CHECKSUMS | xargs ./scripts/upload.ts | sed -ne 's/::set-output name=cf-invalidation-paths:://p')

    echo "$CF" | xargs $AWS cloudfront create-invalidation \
      --distribution-id "$AWS_CF_DISTRIBUTION_ID" \
      --paths
  done
done