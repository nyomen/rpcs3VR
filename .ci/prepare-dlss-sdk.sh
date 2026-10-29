#!/usr/bin/env bash
set -Eeuo pipefail

readonly SDK_VERSION="310.9.16"
readonly SDK_SHA256="f0de83ec7045778bc9ed456229379caaae8bc81ae3b0d5fd8ec9645c71df489d"
readonly SDK_URL="https://github.com/NVIDIA/DLSS/archive/refs/tags/v${SDK_VERSION}.tar.gz"

CACHE_ROOT="${DLSS_SDK_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/rpcs3vr}"
ARCHIVE="${CACHE_ROOT}/DLSS-${SDK_VERSION}.tar.gz"
SDK_DIR="${CACHE_ROOT}/dlss-sdk-${SDK_VERSION}"

TMP_ARCHIVE=""
TMP_EXTRACT=""

cleanup()
{
    [[ -z "$TMP_ARCHIVE" ]] || rm -f -- "$TMP_ARCHIVE"
    [[ -z "$TMP_EXTRACT" ]] || rm -rf -- "$TMP_EXTRACT"
}
trap cleanup EXIT

mkdir -p "$CACHE_ROOT"

if [[ ! -f "$ARCHIVE" ]]; then
    TMP_ARCHIVE="$(mktemp "${CACHE_ROOT}/.dlss-${SDK_VERSION}.XXXXXX")"

    echo "Lade NVIDIA DLSS SDK ${SDK_VERSION} herunter ..." >&2
    curl -fL --retry 3 --retry-delay 2 \
        -o "$TMP_ARCHIVE" "$SDK_URL"

    actual="$(sha256sum "$TMP_ARCHIVE" | awk '{print $1}')"
    if [[ "$actual" != "$SDK_SHA256" ]]; then
        echo "FEHLER: SDK-Archiv hat einen unerwarteten SHA-256." >&2
        echo "Erwartet: $SDK_SHA256" >&2
        echo "Erhalten: $actual" >&2
        exit 1
    fi

    mv -- "$TMP_ARCHIVE" "$ARCHIVE"
    TMP_ARCHIVE=""
else
    echo "Prüfe vorhandenes SDK-Archiv ..." >&2
fi

actual="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
if [[ "$actual" != "$SDK_SHA256" ]]; then
    echo "FEHLER: SHA-256 des zwischengespeicherten Archivs stimmt nicht." >&2
    echo "Erwartet: $SDK_SHA256" >&2
    echo "Erhalten: $actual" >&2
    echo "Entferne bei Bedarf die Datei: $ARCHIVE" >&2
    exit 1
fi

if [[ -f "$SDK_DIR/.rpcs3-dlss-sdk.sha256" ]] &&
   [[ "$(cat "$SDK_DIR/.rpcs3-dlss-sdk.sha256")" == "$SDK_SHA256" ]] &&
   [[ -f "$SDK_DIR/include/nvsdk_ngx_vk.h" ]] &&
   [[ -f "$SDK_DIR/lib/Linux_x86_64/libnvsdk_ngx.a" ]]; then
    echo "SDK ${SDK_VERSION} bereits vorbereitet." >&2
else
    echo "Entpacke und validiere NVIDIA DLSS SDK ${SDK_VERSION} ..." >&2

    TMP_EXTRACT="$(mktemp -d "${CACHE_ROOT}/.dlss-sdk-${SDK_VERSION}.XXXXXX")"
    tar -xzf "$ARCHIVE" --strip-components=1 -C "$TMP_EXTRACT"

    if [[ ! -f "$TMP_EXTRACT/include/nvsdk_ngx_vk.h" ]] ||
       [[ ! -f "$TMP_EXTRACT/lib/Linux_x86_64/libnvsdk_ngx.a" ]]; then
        echo "FEHLER: Erforderliche DLSS-SDK-Dateien fehlen." >&2
        exit 1
    fi

    printf '%s\n' "$SDK_SHA256" > "$TMP_EXTRACT/.rpcs3-dlss-sdk.sha256"

    rm -rf -- "$SDK_DIR"
    mv -- "$TMP_EXTRACT" "$SDK_DIR"
    TMP_EXTRACT=""
fi

printf '%s\n' "$SDK_DIR"
