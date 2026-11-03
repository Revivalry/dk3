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
for tool in curl unzip awk mktemp timeout; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required command missing: $tool" >&2
        exit 1
    fi
done
if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    echo 'Required command missing: sha256sum or shasum' >&2
    exit 1
fi

# Keep external verification services from leaving the terminal silent forever.
bounded() {
    limit=$1
    stage=$2
    shift 2
    if timeout --foreground --kill-after=5s "$limit" "$@"; then
        return 0
    else
        status=$?
    fi
    case "$status" in
        124|137) echo "$stage timed out. Check your connection and retry." >&2 ;;
    esac
    return "$status"
}

temporary=$(mktemp -d "${TMPDIR:-/tmp}/dk3-install.XXXXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
echo 'dk3 installer · Downloading the latest release'
if ! curl -fL --progress-bar --connect-timeout 15 --max-time 1800 \
    --speed-limit 1024 --speed-time 30 --retry 3 --retry-max-time 1800 \
    "$release/$asset" -o "$temporary/$asset"; then
    echo 'Release download failed. Check your connection and retry.' >&2
    exit 1
fi
echo 'Downloading release checksums …'
if ! curl -fL --progress-bar --connect-timeout 15 --max-time 30 \
    --speed-limit 1024 --speed-time 15 --retry 3 --retry-max-time 60 \
    "$release/SHA256SUMS" -o "$temporary/SHA256SUMS"; then
    echo 'Checksum download failed. Check your connection and retry.' >&2
    exit 1
fi
echo 'Checking the archive SHA-256 …'
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

echo 'Archive SHA-256 verified.'
authenticated=false
if [ "${DK3_SKIP_ATTESTATION:-0}" != 1 ] && command -v gh >/dev/null 2>&1; then
    echo 'Checking GitHub CLI authentication …'
    # Disable prompts and paging during bootstrap network checks. The wizard
    # keeps its normal terminal input for the asset and destination questions.
    GH_PROMPT_DISABLED=1 GH_PAGER=cat
    export GH_PROMPT_DISABLED GH_PAGER
    if bounded 20s 'GitHub CLI authentication' gh auth status --hostname github.com \
        >"$temporary/gh-auth.log" 2>&1; then
        authenticated=true
    else
        status=$?
        case "$status" in
            124|137)
                echo 'GitHub CLI authentication timed out. Run gh auth status and retry.' >&2
                exit 1
                ;;
        esac
    fi
fi
if [ "$authenticated" = true ]; then
    echo 'Verifying signed build provenance with GitHub and Sigstore (up to 2 minutes) …'
    if ! bounded 120s 'Signed build provenance verification' \
        gh attestation verify "$temporary/$asset" -R "$repo"; then
        echo 'Signed build provenance could not be verified. Check your GitHub/Sigstore connection and retry.' >&2
        exit 1
    fi
elif [ "${DK3_SKIP_ATTESTATION:-0}" = 1 ]; then
    echo 'Signed provenance check explicitly skipped (DK3_SKIP_ATTESTATION=1); archive SHA-256 verified.' >&2
else
    echo 'SHA-256 verified. Sign in with gh to also verify the signed build provenance.' >&2
fi
echo 'Preparing the installation wizard …'
unzip -q "$temporary/$asset" -d "$temporary"
"$temporary/dk3-installer-linux-x64/install.sh" "$@"
