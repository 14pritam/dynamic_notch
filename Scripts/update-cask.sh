#!/usr/bin/env bash
# Points the Homebrew cask at a release: ./Scripts/update-cask.sh 1.2.0 <sha256>
# Writes Casks/dynamic-notch.rb in the shandilyaswagat/homebrew-tap repository and pushes it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?version, e.g. 1.2.0}"
SHA="${2:?sha256 of DynamicNotch.dmg}"
TAP="${TAP_REPO:-shandilyaswagat/homebrew-tap}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
gh repo clone "$TAP" "$WORK/tap" -- --quiet
mkdir -p "$WORK/tap/Casks"
sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA/" \
    "$ROOT/packaging/homebrew/dynamic-notch.rb.template" > "$WORK/tap/Casks/dynamic-notch.rb"
cd "$WORK/tap"
if git diff --quiet -- Casks/dynamic-notch.rb && git ls-files --error-unmatch Casks/dynamic-notch.rb >/dev/null 2>&1; then
    echo "› Cask already at $VERSION"
    exit 0
fi
git add Casks/dynamic-notch.rb
git commit --quiet -m "Dynamic Notch $VERSION"
git push --quiet
echo "✓ Homebrew cask now at $VERSION"
