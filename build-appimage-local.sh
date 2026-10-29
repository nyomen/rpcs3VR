#!/usr/bin/env bash
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="docker.io/rpcs3/rpcs3-ci-jammy:2.1"

command -v podman >/dev/null || {
    echo "FEHLER: podman fehlt."
    exit 1
}

podman image exists "$IMAGE" || {
    echo "FEHLER: Container-Image nicht lokal vorhanden: $IMAGE"
    exit 1
}

DLSS_SDK_DIR="$("$REPO/.ci/prepare-dlss-sdk.sh")"
echo "Verifiziertes DLSS SDK: $DLSS_SDK_DIR"

mkdir -p "$REPO/artifacts"

echo "=== RPCS3-VR AppImage-Build ==="
echo "Repository: $REPO"

podman run --rm \
    -v "$REPO:/rpcs3:Z" \
    -v "$DLSS_SDK_DIR:/dlss-sdk:ro,Z" \
    -w / \
    -e DEPLOY_APPIMAGE=true \
    -e BUILD_ARTIFACTSTAGINGDIRECTORY=/rpcs3/artifacts \
    -e ARTDIR=/rpcs3/artifacts \
    -e RELEASE_MESSAGE=/rpcs3/GitHubReleaseMessage.txt \
    "$IMAGE" bash -lc '
        set -Eeuo pipefail
        cd /

        # Veraltete Packaging-Dateien entfernen, den Build aber behalten.
        rm -rf /rpcs3/build/AppDir
        rm -f /rpcs3/build/*.AppImage

        if [ ! -f /rpcs3/build/CMakeCache.txt ]; then
            echo "Kein konfigurierter Build gefunden: CI-Build vollständig starten."
            /rpcs3/.ci/build-linux.sh
        else
            echo "Vorhandenen Build weiterverwenden."
            cd /rpcs3

            git config --global --add safe.directory /rpcs3
            git submodule -q update --init $(
                awk "/path/ && !/llvm/ && !/opencv/ && !/libsdl-org/ && !/curl/ && !/zlib/ { print \$3 }" .gitmodules
            )

            cd /rpcs3/build
            cmake .. -DDLSS_SDK_ROOT=/dlss-sdk
            ninja

            cd /rpcs3
            .ci/deploy-linux.sh x86_64
        fi

        # Falls das Deploy-Skript nicht selbst nach artifacts kopiert hat:
        shopt -s nullglob
        outputs=(/rpcs3/artifacts/*.AppImage)
        if [ "${#outputs[@]}" -eq 0 ]; then
            built=(/rpcs3/build/*.AppImage)
            if [ "${#built[@]}" -gt 0 ]; then
                cp -f "${built[@]}" /rpcs3/artifacts/
            fi
        fi

        outputs=(/rpcs3/artifacts/*.AppImage)
        if [ "${#outputs[@]}" -eq 0 ]; then
            echo "FEHLER: Keine AppImage in artifacts gefunden."
            exit 1
        fi

        chmod +x "${outputs[@]}"
        rm -f /rpcs3/build/*.AppImage

        echo "=== Erfolgreich erstellte AppImage(s) ==="
        ls -lh "${outputs[@]}"
    '

echo
echo "Fertig. Ausgabeordner: $REPO/artifacts"
