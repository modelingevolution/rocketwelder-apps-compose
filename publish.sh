#!/bin/bash
# Names every app in the RocketWelder apps image and publishes that image.
# The image itself is built and pushed by autoupdater/packaging/apps/publish-apps.sh.
# This script does not build the Player or the Claude bundles. Those files must already exist.
#
#   ./publish.sh <image-release> <player-version> <bundle-version>
#   ./publish.sh 1.0.1 1.2.0 1.0.0
#
# Repos are siblings of this one (override the parent with ROCKETWELDER_ROOT):
#   native-player/build-win-msi/installer/RocketWelderPlayer-<player-version>.msi
#     built on this laptop by native-player/tools/win32/installer.cmd. There is no CI for it.
#   native-player/dist/native-player_<player-version>_arm64.deb
#     downloaded by native-player/release.sh
#   native-player/dist/RocketWelderPlayer-<player-version>-arm64-v8a.apk
#   mcp/dist/RocketWelder.mcpb and mcp/dist/Simulator.mcpb
#     built by mcp/packaging/pack-mcpb.sh
#
# A download's file name is unique in the image, and one .mcpb holds Windows, Mac and Linux.
# Each platform row therefore gets its own file name. The bytes are the one bundle.
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: ./publish.sh <image-release> <player-version> <bundle-version>" >&2
    exit 1
fi

IMAGE_RELEASE="$1"
PLAYER_VERSION="$2"
BUNDLE_VERSION="$3"

[[ "$IMAGE_RELEASE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "image release must be X.Y.Z" >&2; exit 1; }
[[ "$PLAYER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "player version must be X.Y.Z" >&2; exit 1; }
[[ "$BUNDLE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "bundle version must be X.Y.Z" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${ROCKETWELDER_ROOT:-$(cd "$HERE/.." && pwd)}"
PUBLISH="$ROOT/autoupdater/packaging/apps/publish-apps.sh"
PLAYER="$ROOT/native-player"
MCP="$ROOT/mcp"
ICON="$PLAYER/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"

need() {
    [ -f "$1" ] || { echo "missing $1" >&2; echo "$2" >&2; exit 1; }
}

need "$PUBLISH" "autoupdater repo, packaging/apps/publish-apps.sh"
need "$ICON" "native-player icon"
need "$PLAYER/packaging/apps/windows.md" "native-player Player guides"
need "$PLAYER/packaging/apps/linux.md" "native-player Player guides"
need "$PLAYER/packaging/apps/android.md" "native-player Player guides"
need "$MCP/packaging/guides/rocketwelder-windows.md" "mcp Claude guides"
need "$MCP/packaging/guides/rocketwelder-macos.md" "mcp Claude guides"
need "$MCP/packaging/guides/rocketwelder-linux.md" "mcp Claude guides"
need "$MCP/packaging/guides/simulator-windows.md" "mcp Claude guides"
need "$MCP/packaging/guides/simulator-macos.md" "mcp Claude guides"
need "$MCP/packaging/guides/simulator-linux.md" "mcp Claude guides"

MSI="$PLAYER/build-win-msi/installer/RocketWelderPlayer-${PLAYER_VERSION}.msi"
DEB="$PLAYER/dist/native-player_${PLAYER_VERSION}_arm64.deb"
APK="$PLAYER/dist/RocketWelderPlayer-${PLAYER_VERSION}-arm64-v8a.apk"
RW="$MCP/dist/RocketWelder.mcpb"
SIM="$MCP/dist/Simulator.mcpb"
need "$MSI" "build it on this laptop with native-player/tools/win32/installer.cmd. It writes build-win-msi/installer/. There is no CI for the MSI."
need "$DEB" "native-player/release.sh downloads this into dist/"
need "$APK" "the Player Android package, named RocketWelderPlayer-${PLAYER_VERSION}-arm64-v8a.apk"
need "$RW" "mcp/packaging/pack-mcpb.sh"
need "$SIM" "mcp/packaging/pack-mcpb.sh"

# One bundle, three download rows. publish-apps.sh keeps a single copy of a guide or icon,
# and refuses the same download file name twice, so each row has its own name.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp "$RW" "$STAGE/RocketWelder-${BUNDLE_VERSION}-windows-x64.mcpb"
cp "$RW" "$STAGE/RocketWelder-${BUNDLE_VERSION}-macos-arm64.mcpb"
cp "$RW" "$STAGE/RocketWelder-${BUNDLE_VERSION}-linux-x64.mcpb"
cp "$SIM" "$STAGE/RocketWelderSimulator-${BUNDLE_VERSION}-windows-x64.mcpb"
cp "$SIM" "$STAGE/RocketWelderSimulator-${BUNDLE_VERSION}-macos-arm64.mcpb"
cp "$SIM" "$STAGE/RocketWelderSimulator-${BUNDLE_VERSION}-linux-x64.mcpb"

exec "$PUBLISH" \
  --release "$IMAGE_RELEASE" \
  --image docker.modelingevolution.com/rocketwelder/rocketwelder-apps \
  --app rocketwelder-player --name "RocketWelder Player" --icon "$ICON" \
    --download --platform windows --arch x64 \
      --file "$MSI" --version "$PLAYER_VERSION" --guide "$PLAYER/packaging/apps/windows.md" \
    --download --platform linux --arch arm64 --label "Kiosk devices" \
      --file "$DEB" --version "$PLAYER_VERSION" --guide "$PLAYER/packaging/apps/linux.md" \
    --download --platform android --arch arm64 --preview \
      --file "$APK" --version "$PLAYER_VERSION" --guide "$PLAYER/packaging/apps/android.md" \
  --app rocketwelder --name "RocketWelder for Claude" --icon "$ICON" \
    --download --platform windows --arch x64 \
      --file "$STAGE/RocketWelder-${BUNDLE_VERSION}-windows-x64.mcpb" --version "$BUNDLE_VERSION" \
      --guide "$MCP/packaging/guides/rocketwelder-windows.md" \
    --download --platform macos --arch arm64 \
      --file "$STAGE/RocketWelder-${BUNDLE_VERSION}-macos-arm64.mcpb" --version "$BUNDLE_VERSION" \
      --guide "$MCP/packaging/guides/rocketwelder-macos.md" \
    --download --platform linux --arch x64 \
      --file "$STAGE/RocketWelder-${BUNDLE_VERSION}-linux-x64.mcpb" --version "$BUNDLE_VERSION" \
      --guide "$MCP/packaging/guides/rocketwelder-linux.md" \
  --app rocketwelder-simulator --name "RocketWelder Simulator for Claude" --icon "$ICON" \
    --download --platform windows --arch x64 \
      --file "$STAGE/RocketWelderSimulator-${BUNDLE_VERSION}-windows-x64.mcpb" --version "$BUNDLE_VERSION" \
      --guide "$MCP/packaging/guides/simulator-windows.md" \
    --download --platform macos --arch arm64 \
      --file "$STAGE/RocketWelderSimulator-${BUNDLE_VERSION}-macos-arm64.mcpb" --version "$BUNDLE_VERSION" \
      --guide "$MCP/packaging/guides/simulator-macos.md" \
    --download --platform linux --arch x64 \
      --file "$STAGE/RocketWelderSimulator-${BUNDLE_VERSION}-linux-x64.mcpb" --version "$BUNDLE_VERSION" \
      --guide "$MCP/packaging/guides/simulator-linux.md"
