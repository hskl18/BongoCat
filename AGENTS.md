# BongoCat agent guide

BongoCat is a source-only native macOS 26 app built with SwiftUI, AppKit, Metal, and a local Live2D Cubism SDK.

## Repository map

| Path | Purpose |
| --- | --- |
| `Sources/BongoCat` | App state, UI, input, window, models, shortcuts |
| `Sources/CubismAPI` | Swift-facing Objective-C API |
| `CubismRuntime` | Objective-C++ bridge and Metal runtime build |
| `Resources` | App metadata, locales, and bundled models |
| `Tests/BongoCatTests` | Swift Testing suites |
| `scripts` | Local build, run, signing, and repository checks |
| `docs/PARITY.md` | Upstream behavior ledger |

## Commands

```sh
export CUBISM_SDK_ROOT="/path/to/CubismSdkForNative-5-r.5"
./scripts/dev-local.sh test
./scripts/dev-local.sh up
./scripts/check-repository.sh
```

## Rules

- Keep Live2D Core, Framework, SDK archives, generated libraries, app bundles, and signing material out of git.
- Build the host architecture for local development.
- Keep the app source-only until the project adopts a signed distribution policy.
- Show only implemented controls in the UI.
- Preserve the lower-right first-launch placement and saved-position behavior.
- Rebuild, restart, and verify the running app after native changes.
- Work on a branch and merge through a pull request.
- Never commit or push directly to `main`.
