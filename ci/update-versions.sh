#!/usr/bin/env bash
# Refresh nix/versions.json from the latest GitHub releases, then print the
# diff. Every entry is pinned by tag + SRI hash; a changed tag without its
# hash would break the build, so both are fetched here, never by hand.
#
# Usage: ci/update-versions.sh [--check]
#   --check exits 1 when versions.json would change (for CI gating).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS="$ROOT/nix/versions.json"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }
need jq
need nix

# Latest non-prerelease tag of owner/repo.
latest_tag() {
  local repo="$1" tag
  tag="$(gh api "repos/$repo/releases/latest" --jq .tag_name 2>/dev/null)" \
    || tag="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)"
  printf '%s' "$tag"
}

# SRI hash of a release asset URL (what fetchurl wants).
asset_hash() {
  nix store prefetch-file --json "$1" | jq -r .hash
}

# SRI hash of a GitHub repo at a rev (what fetchFromGitHub wants).
rev_hash() {
  nix store prefetch-file --unpack --json "https://github.com/$1/archive/$2.tar.gz" | jq -r .hash
}

# Rewrite one versions.json entry, keeping field order stable.
set_entry() {
  local key="$1" json="$2" tmp
  tmp="$(mktemp)"
  jq --argjson e "$json" --arg k "$key" '.[$k] = $e' "$VERSIONS" > "$tmp"
  mv "$tmp" "$VERSIONS"
}

pin_release() {
  local key="$1" repo="$2" asset="$3"
  local tag url hash version entry
  tag="$(latest_tag "$repo")"
  url="https://github.com/$repo/releases/download/$tag/$asset"
  hash="$(asset_hash "$url")"
  version="${tag#v}"
  entry="$(jq -n \
    --arg owner "${repo%%/*}" --arg repo "${repo##*/}" \
    --arg tag "$tag" --arg version "$version" \
    --arg asset "$asset" --arg hash "$hash" \
    '{owner:$owner,repo:$repo,tag:$tag,version:$version,asset:$asset,hash:$hash}')"
  set_entry "$key" "$entry"
  echo "$key: $tag $hash"
}

echo "== upstream =="
OLD="$(cat "$VERSIONS")"

# slssteam is a source build: pin the tag's commit rev + its NAR hash
# (fetchFromGitHub), not a release asset.
SLS_TAG="$(latest_tag AceSLS/SLSsteam)"
SLS_REV="$(gh api "repos/AceSLS/SLSsteam/commits/$SLS_TAG" --jq .sha 2>/dev/null \
  || curl -fsSL "https://api.github.com/repos/AceSLS/SLSsteam/commits/$SLS_TAG" | jq -r .sha)"
SLS_HASH="$(rev_hash AceSLS/SLSsteam "$SLS_REV")"
set_entry "slssteam" "$(jq -n \
  --arg tag "$SLS_TAG" --arg rev "$SLS_REV" --arg version "$SLS_TAG" --arg hash "$SLS_HASH" \
  '{owner:"AceSLS",repo:"SLSsteam",tag:$tag,rev:$rev,version:$version,hash:$hash}')"
echo "slssteam: $SLS_TAG $SLS_REV $SLS_HASH"

pin_release "lumen" "swwayps/lumen" "lumen-linux.zip"
pin_release "luatools" "swwayps/luatools-moon" "luatools-linux.zip"
pin_release "assella" "niwia/ASSella" "ASSella.AppImage"

# slsteam-moon is a source build too: pin the tag's commit rev + its NAR
# hash (fetchFromGitHub), not the release zip.
MOON_TAG="$(latest_tag swwayps/slsteam-moon)"
MOON_VER="${MOON_TAG#v}"
MOON_REV="$(gh api "repos/swwayps/slsteam-moon/commits/$MOON_TAG" --jq .sha 2>/dev/null \
  || curl -fsSL "https://api.github.com/repos/swwayps/slsteam-moon/commits/$MOON_TAG" | jq -r .sha)"
MOON_HASH="$(rev_hash swwayps/slsteam-moon "$MOON_REV")"
set_entry "slsteam-moon" "$(jq -n \
  --arg tag "$MOON_TAG" --arg rev "$MOON_REV" --arg version "$MOON_VER" --arg hash "$MOON_HASH" \
  '{owner:"swwayps",repo:"slsteam-moon",tag:$tag,rev:$rev,version:$version,hash:$hash}')"
echo "slsteam-moon: $MOON_TAG $MOON_REV $MOON_HASH"

if [ "${1:-}" = "--check" ]; then
  old_tmp="$(mktemp)"
  new_tmp="$(mktemp)"
  printf '%s\n' "$OLD" > "$old_tmp"
  cat "$VERSIONS" > "$new_tmp"
  if ! diff "$old_tmp" "$new_tmp" >/dev/null; then
    echo "versions.json is stale — run ci/update-versions.sh" >&2
    rm -f "$old_tmp" "$new_tmp"
    exit 1
  fi
  rm -f "$old_tmp" "$new_tmp"
  echo "versions.json is current"
else
  old_tmp="$(mktemp)"
  new_tmp="$(mktemp)"
  printf '%s\n' "$OLD" > "$old_tmp"
  cat "$VERSIONS" > "$new_tmp"
  diff "$old_tmp" "$new_tmp" || true
  rm -f "$old_tmp" "$new_tmp"
fi
