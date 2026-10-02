#!/usr/bin/env bash
# Sync VERSION + Homebrew formula version/url from a release tag (vX.Y.Z).
# Does NOT modify sha256 (leave :no_check or an existing digest for a later main-only bump).
#
# Usage:
#   RELEASE_TAG=v0.3.1 ./packaging/homebrew/sync-release-version.sh
#   ./packaging/homebrew/sync-release-version.sh v0.3.1
#
# Intended for Manual Release CI (same commit as tag force-move, before Create Release).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

RELEASE_TAG="${1:-${RELEASE_TAG:-}}"
[[ -n "${RELEASE_TAG}" ]] || {
  echo "usage: $0 vX.Y.Z   (or set RELEASE_TAG)" >&2
  exit 1
}
[[ "${RELEASE_TAG}" == v* ]] || {
  echo "RELEASE_TAG must start with v (got: ${RELEASE_TAG})" >&2
  exit 1
}

VERSION="${RELEASE_TAG#v}"
[[ -n "${VERSION}" ]] || {
  echo "empty version from tag ${RELEASE_TAG}" >&2
  exit 1
}

REPO_SLUG="${PLUME_GITHUB_SLUG:-galaxous/plume}"
ARCHIVE_URL="https://github.com/${REPO_SLUG}/archive/refs/tags/${RELEASE_TAG}.tar.gz"

FORMULA_FILES=(
  "${ROOT_DIR}/Formula/plumectl.rb"
  "${ROOT_DIR}/packaging/homebrew/plumectl.rb"
)

patch_formula() {
  local file="$1"
  [[ -f "${file}" ]] || {
    echo "missing formula: ${file}" >&2
    exit 1
  }
  # Portable in-place edit (Linux CI + macOS): rewrite version / url lines only.
  local tmp
  tmp="$(mktemp)"
  awk -v ver="${VERSION}" -v url="${ARCHIVE_URL}" '
    /^[[:space:]]*url[[:space:]]+"/ {
      match($0, /^[[:space:]]*/)
      printf "%surl \"%s\"\n", substr($0, 1, RLENGTH), url
      next
    }
    /^[[:space:]]*version[[:space:]]+"/ {
      match($0, /^[[:space:]]*/)
      printf "%sversion \"%s\"\n", substr($0, 1, RLENGTH), ver
      next
    }
    { print }
  ' "${file}" > "${tmp}"
  mv "${tmp}" "${file}"
}

printf '%s\n' "${VERSION}" > "${ROOT_DIR}/VERSION"
echo "Wrote VERSION → ${VERSION}"

for f in "${FORMULA_FILES[@]}"; do
  patch_formula "${f}"
  echo "Synced formula version/url → ${f}"
done

# Idempotent sanity
current="$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION")"
[[ "${current}" == "${VERSION}" ]] || {
  echo "VERSION write failed" >&2
  exit 1
}
for f in "${FORMULA_FILES[@]}"; do
  grep -q "version \"${VERSION}\"" "${f}" || {
    echo "formula version mismatch in ${f}" >&2
    exit 1
  }
  grep -q "url \"${ARCHIVE_URL}\"" "${f}" || {
    echo "formula url mismatch in ${f}" >&2
    exit 1
  }
done

echo "sync-release-version:ok ${RELEASE_TAG}"
