#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
url=https://wow.aethus.pl/download/AzerothSurvivorsWindowsNew.rar
etag=$(curl --head --fail --silent --show-error --location "$url" | tr -d '\r' | awk -F ': ' 'tolower($1)=="etag" {print $2}' | tail -n1)
[[ -n "$etag" ]] || { echo 'Official download returned no ETag; refusing an unverifiable update check.' >&2; exit 1; }
if [[ "$etag" != "$(cat packages/archive-etag)" ]]; then
  prefetch_json=$(./scripts/prefetch-archive.py --update)
  hash=$(jq -r .hash <<< "$prefetch_json")
  sed -i -E "s|hash = \"sha256-[^\"]+\";|hash = \"$hash\";|" packages/azeroth-survivors.nix
  sed -i -E "s|version = \"[^\"]+\";|version = \"unstable-$(date -u +%F)\";|" packages/azeroth-survivors.nix
  printf '%s\n' "$etag" > packages/archive-etag
fi
./scripts/prefetch-archive.py
nix flake check --print-build-logs
