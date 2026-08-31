# Contributing

Create a branch from `main` and send a pull request.
The repository blocks direct updates to `main`, including administrator pushes.

Before opening a pull request, run:

```sh
export CUBISM_SDK_ROOT="/path/to/CubismSdkForNative-5-r.5"
./scripts/dev-local.sh test
./scripts/dev-local.sh up
./scripts/check-repository.sh
```

Confirm that keyboard, pointer, and mouse reactions work in the running app.
Describe the tested macOS, Xcode, Mac architecture, and Cubism SDK version in the pull request.

Do not commit Live2D SDK files, build products, credentials, signing certificates, local logs, or imported user models.
