#!/bin/bash

set -euxo pipefail

if test ! -d /opt/tea.xyz/var/infuser -o ! -d /opt/tea.xyz/var/cli -o ! -d /opt/tea.xyz/var/pantry; then
  echo "Missing one of the three required repositories"
  exit 1
fi

cd /opt/tea.xyz/var/infuser

git status -uno | grep "Your branch is up to date with 'origin/main'." && exit

git reset --hard
git fetch origin
git pull --rebase

eval "$(grep ^GITHUB_TOKEN= ~/docker.env.tea)"

echo "$GITHUB_TOKEN" | docker login ghcr.io -u jhheider --password-stdin

docker buildx build \
  --pull --push \
  --tag ghcr.io/teaxyz/infuser:latest \
  --tag ghcr.io/teaxyz/infuser::"$(git -C infuser branch --show-current)" \
  --tag ghcr.io/teaxyz/infuser:sha-"$(git -C infuser rev-parse --short HEAD)" \
  --platform linux/amd64,linux/arm64 \
  --file infuser/Dockerfile \
  --build-arg GITHUB_TOKEN="$GITHUB_TOKEN" \
  --progress=plain \
  .