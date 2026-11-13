# CI and releases

Both are GitHub Actions workflows in `.github/workflows/`. The Godot version they use is set in one place:
`.github/actions/setup-godot/action.yml` (`version`). Change it there when the project moves to a new Godot.

## CI (`ci.yml`)

Runs on every push to `main`, on every pull request, and by hand (*Run workflow*). Takes a few minutes and
uploads no artifacts.

- **Card catalog and tools**: `tools/validate_catalog.py` and the unit tests in `tools/`. The OCR tests are not run
  (they need tesseract and photos that are not in the repo).
- **Godot checks and tests**: builds the QR extension for Linux from `native/` (the committed `.so` needs a newer
  glibc than the runner has, and this checks that the C++ compiles), imports the project and runs `tests/run.sh`.
  Its first suite, `tests/check_project.tscn`, loads every script and scene, so code no test runs is still compiled.

The windowed tests (`test_game`, `test_onboarding`) are not run: they need a GPU to get camera frames.

## Releases (`release.yml`)

    git tag v1.2.0
    git push origin v1.2.0

The tag is the only place the version is written. For a tag `vMAJOR.MINOR.PATCH` the workflow

1. runs the CI checks above, and stops if they fail,
2. builds the QR extension for Android arm64 from the tagged source,
3. writes the version into the export preset (`version/name` = `1.2.0`, `version/code` = `1002000`) and into
   `project.godot` (`application/config/version`, readable with
   `ProjectSettings.get_setting("application/config/version")`). These changes are not committed; the files in the
   repo keep their placeholder values.
4. exports `FossFightersQR_Debug_1.2.0.apk`,
5. creates the GitHub release *FossFightersQR 1.2.0* with the APK and the commit messages since the previous `v*` tag.

To redo a release, delete the release and the tag on GitHub, then tag and push again.

### Signing key

Debug APKs are signed with a debug key. Android only installs an update over an installed app signed with the
same key. To keep that key across releases, store a debug keystore (alias `androiddebugkey`, passwords
`android`) as the repository secret `ANDROID_DEBUG_KEYSTORE`:

    base64 -w0 ~/.local/share/godot/keystores/debug.keystore | gh secret set ANDROID_DEBUG_KEYSTORE

Without the secret, each release gets a new key and the old app has to be uninstalled first.

### Desktop builds (not yet)

A Linux/Windows/macOS zip would be another job in `release.yml` next to `android`, uploading its files as an
artifact; the `release` job attaches all artifacts. It needs export presets for those platforms, their templates
(`templates:` input of `setup-godot`, e.g. `linux_release.x86_64`), and the QR extension built for each platform:
`qr_scanner.gdextension` only lists Linux and Android libraries so far.
