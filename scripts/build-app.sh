#!/bin/zsh

set -euo pipefail

native_root="${0:A:h:h}"
app_path="$native_root/build/BongoCat.app"
contents_path="$app_path/Contents"
binary_path="$native_root/.build/release/BongoCat"
signing_identity="${BONGOCAT_SIGNING_IDENTITY:-BongoCat Local Development}"
user_name="$(/usr/bin/id -un)"
user_home="$(
  /usr/bin/dscl . -read "/Users/$user_name" NFSHomeDirectory |
    /usr/bin/cut -d ' ' -f 2-
)"
signing_directory="$user_home/Library/Application Support/BongoCat/Local Signing"
signing_keychain="$signing_directory/BongoCat.keychain-db"
signing_password="$signing_directory/keychain-password"

cd "$native_root"
"$native_root/scripts/prepare-cubism.sh"
swift build -c release

if [[ -e "$app_path" ]]; then
  /usr/bin/find "$app_path" -depth -delete
fi

/bin/mkdir -p "$contents_path/MacOS" "$contents_path/Resources"
/bin/cp "$binary_path" "$contents_path/MacOS/BongoCat"
/bin/cp "$native_root/Resources/Info.plist" "$contents_path/Info.plist"
/bin/cp "$native_root/Resources/BongoCat.png" "$contents_path/Resources/BongoCat.png"
/bin/cp "$native_root/Resources/BongoCatTray.png" "$contents_path/Resources/BongoCatTray.png"
/bin/mkdir -p "$contents_path/Resources/Locales"
/bin/cp "$native_root"/Resources/Locales/*.json "$contents_path/Resources/Locales/"
/bin/mkdir -p "$contents_path/Resources/Models"
for mode in standard keyboard gamepad; do
  /bin/cp -R \
    "$native_root/Resources/Models/$mode" \
    "$contents_path/Resources/Models/$mode"
done
/bin/cp -R \
  "$native_root/.build/cubism/FrameworkMetallibs" \
  "$contents_path/Resources/FrameworkMetallibs"
if [[ -f "$signing_keychain" && -f "$signing_password" ]]; then
  /usr/bin/security unlock-keychain -p "$(<"$signing_password")" "$signing_keychain"
fi

if [[ -f "$signing_keychain" ]] &&
  /usr/bin/security find-identity -v -p codesigning "$signing_keychain" |
    /usr/bin/grep -Fq "\"$signing_identity\""; then
  /usr/bin/codesign \
    --force \
    --deep \
    --keychain "$signing_keychain" \
    --sign "$signing_identity" \
    "$app_path"
else
  echo "Warning: $signing_identity was not found; using an ad-hoc signature." >&2
  echo "Run scripts/setup-local-signing.sh once to keep Input Monitoring permission stable." >&2
  /usr/bin/codesign --force --deep --sign - "$app_path"
fi

echo "$app_path"
