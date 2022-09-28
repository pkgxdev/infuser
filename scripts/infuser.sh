#!/bin/bash

set -euxo pipefail

function update_from_git() {
  git -C "$1" reset --hard
  git -C "$1" fetch origin
  git -C "$1" checkout main
  git -C "$1" pull --all
}

if test ! -d /opt/tea.xyz/var/infuser -o ! -d /opt/tea.xyz/var/cli -o ! -d /opt/tea.xyz/var/pantry; then
  echo "Missing one of the three required repositories"
  exit 1
fi

cd /opt/tea.xyz/var

update_from_git infuser
update_from_git cli
update_from_git pantry

# shellcheck source=/dev/null
. ~/docker.env.tea

#HACKY: Docker Desktop _really_ wants to use the macOS keychain
HASH=$(echo -n "$GITHUB_USER:$GITHUB_TOKEN" | base64)

echo '{"auths":{"ghcr.io":{"auth":"'"$HASH"'"}}}' >~/.docker/config.json

/usr/local/bin/docker login ghcr.io

/usr/local/bin/docker buildx build \
  --pull --push \
  --tag ghcr.io/teaxyz/infuser:latest \
  --tag ghcr.io/teaxyz/infuser:"$(git -C infuser branch --show-current)" \
  --tag ghcr.io/teaxyz/infuser:sha-"$(git -C infuser rev-parse --short HEAD)" \
  --tag ghcr.io/teaxyz/infuser:nightly-"$(date +%F)" \
  --platform linux/amd64,linux/arm64 \
  --file infuser/Dockerfile \
  --build-arg GITHUB_TOKEN="$GITHUB_TOKEN" \
  --progress=plain \
  .