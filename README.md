# rocketwelder-apps-compose

The AutoUpdater deploy package for the RocketWelder apps image. A station runs it, and the AutoUpdater's Apps page
shows the downloads. The image holds the RocketWelder Player (Windows .msi, Linux kiosk .deb, Android .apk) and the
Claude bundles (RocketWelder and RocketWelder Simulator, one `.mcpb` each for Windows, Mac and Linux). The image is
built by `autoupdater/packaging/apps/publish-apps.sh`. `publish.sh` names the apps and calls that script. Nothing is
built in this repository.

Built from the AutoUpdater's generic template (`autoupdater/packaging/apps/compose`). The image contract (manifest.json,
guides, icons) is described in `autoupdater/packaging/apps/README.md`.

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | The service: pinned `docker.modelingevolution.com/rocketwelder/rocketwelder-apps` image, read-only root, port `${APPS_PORT:-8095}` on the Docker bridge address only, `/health` healthcheck. |
| `docker-compose.x64.yml`, `docker-compose.arm64.yml` | Per-arch overrides, layered by AutoUpdater on `uname -m`. |
| `apps.version` | Bare semver of the pinned release. |
| `update-version.sh` | `set X.Y.Z` pins the image tag; `list` queries Harbor for release tags. |
| `publish.sh` | Names the Player and the Claude bundles, then calls `publish-apps.sh`. |
| `release.sh` | Pins, generates `up-X.Y.Z.sh`, commits, pushes master and the git tag AutoUpdater detects. Refuses a tag that already exists. |
| `prune-old-images.sh` | Keeps the two newest apps images on a station. Always exits 0. |

## Release

From the laptop (no CI):

1. Build the inputs, in the sibling repos. The Windows Player is built on this laptop:
   `native-player/tools/win32/installer.cmd` writes `build-win-msi/installer/RocketWelderPlayer-<player>.msi`.
   There is no CI for that installer. `native-player/release.sh` downloads `dist/native-player_<player>_arm64.deb`;
   the Android package is `dist/RocketWelderPlayer-<player>-arm64-v8a.apk`. The Claude bundles:
   `mcp/packaging/pack-mcpb.sh` writes `dist/RocketWelder.mcpb` and `dist/Simulator.mcpb`.
2. Publish the image from here. This keeps every app. Publishing the Player on its own would drop the Claude bundles,
   and the other way around.

   ```bash
   ./publish.sh 1.0.1 1.2.0 1.0.0
   ```

   `1.0.1` is the image release, `1.2.0` the Player version, `1.0.0` the bundle version.
3. Pin it here: `./release.sh 1.0.1`. Stations then see the new version on their Packages page.

## Register on a station

```bash
./add-package.sh rocketwelder-apps https://github.com/modelingevolution/rocketwelder-apps-compose.git
```

Then turn the Apps page on in the AutoUpdater's settings:

```json
"Apps": { "Enabled": true, "SourceUrl": "http://172.17.0.1:8095/", "Title": "Apps", "PackageName": "rocketwelder-apps" }
```

The container is not on the LAN: its port is bound to the Docker bridge address (`APPS_BIND_ADDRESS`, default
`172.17.0.1`), where the AutoUpdater container reaches the host, and browsers download through the AutoUpdater at
`/apps/files/<name>`. If a station's docker0 has another address, set `APPS_BIND_ADDRESS` in the package's `.env` and
use it in `Apps:SourceUrl`. A different port needs `APPS_PORT` there and the same port in `Apps:SourceUrl`.
