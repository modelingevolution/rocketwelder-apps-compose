# rocketwelder-apps-compose

The AutoUpdater deploy package for the RocketWelder apps image: the RocketWelder Player downloads (Windows .msi, Linux
kiosk .deb, Android .apk) with their install guides and icon. A station runs it, and the AutoUpdater's Apps page shows
the downloads. The image is pre-built and pulled, never built here.

Built from the AutoUpdater's generic template (`autoupdater/packaging/apps/compose`). The image contract (manifest.json,
guides, icons) is described in `autoupdater/packaging/apps/README.md`.

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | The service: pinned `docker.modelingevolution.com/rocketwelder/rocketwelder-apps` image, read-only root, port `${APPS_PORT:-8095}` on the Docker bridge address only, `/health` healthcheck. |
| `docker-compose.x64.yml`, `docker-compose.arm64.yml` | Per-arch overrides, layered by AutoUpdater on `uname -m`. |
| `apps.version` | Bare semver of the pinned release. |
| `update-version.sh` | `set X.Y.Z` pins the image tag; `list` queries Harbor for release tags. |
| `release.sh` | Pins, generates `up-X.Y.Z.sh`, commits, pushes master and the git tag AutoUpdater detects. Refuses a tag that already exists. |
| `prune-old-images.sh` | Keeps the two newest apps images on a station. Always exits 0. |

## Release

From the laptop (no CI):

1. Build the installers: the Windows MSI with native-player's `tools\win32\installer.cmd`; the .deb and .apk from the
   native-player release.
2. Publish the image with `autoupdater/packaging/apps/publish-apps.sh`, using the guides and icon from native-player:

   ```bash
   ./publish-apps.sh --release X.Y.Z --image docker.modelingevolution.com/rocketwelder/rocketwelder-apps \
     --app rocketwelder-player --name "RocketWelder Player" --icon rocketwelder-player.png \
     --download --platform windows --arch x64 --file RocketWelderPlayer-<v>.msi --version <v> --guide windows.md \
     --download --platform linux --arch arm64 --label "Kiosk devices" --file native-player_<v>_arm64.deb --version <v> --guide linux.md \
     --download --platform android --arch arm64 --preview --file RocketWelderPlayer-<v>-arm64-v8a.apk --version <v> --guide android.md
   ```
3. Pin it here: `./release.sh X.Y.Z`. Stations then see the new version on their Packages page.

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
