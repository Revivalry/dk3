#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Interactive Linux installer bootstrap. Run with: sh -c "$(curl -fsSL URL)"
set -eu

repo=Revivalry/dk3
asset=dk3-installer-linux-x64.zip
release="https://github.com/$repo/releases/latest/download"

if [ "$(uname -s)" != Linux ] || [ "$(uname -m)" != x86_64 ]; then
    echo 'This installer supports Linux x86-64. Download the Windows bundle from GitHub Releases.' >&2
    exit 1
fi
for tool in curl unzip awk mktemp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required command missing: $tool" >&2
        exit 1
    fi
done
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    echo 'Required command missing: sha256sum or shasum' >&2
    exit 1
fi

temporary=$(mktemp -d "${TMPDIR:-/tmp}/dk3-install.XXXXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
curl -fL --retry 3 "$release/$asset" -o "$temporary/$asset"
curl -fL --retry 3 "$release/SHA256SUMS" -o "$temporary/SHA256SUMS"
expected=$(awk -v name="$asset" '$2 == name {print $1}' "$temporary/SHA256SUMS")
if [ "${#expected}" -ne 64 ]; then
    echo 'Release checksum is missing or invalid.' >&2
    exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$temporary/$asset" | awk '{print $1}')
else
    actual=$(shasum -a 256 "$temporary/$asset" | awk '{print $1}')
fi
if [ "$actual" != "$expected" ]; then
    echo 'Release checksum did not match.' >&2
    exit 1
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh attestation verify "$temporary/$asset" -R "$repo"
else
    echo 'SHA-256 verified. Sign in with gh to also verify the signed build provenance.' >&2
fi
unzip -q "$temporary/$asset" -d "$temporary"
"$temporary/dk3-installer-linux-x64/install.sh" "$@"
