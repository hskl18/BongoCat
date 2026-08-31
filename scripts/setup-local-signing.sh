#!/bin/zsh

set -euo pipefail

identity_name="${BONGOCAT_SIGNING_IDENTITY:-BongoCat Local Development}"
user_name="$(/usr/bin/id -un)"
user_home="$(
  /usr/bin/dscl . -read "/Users/$user_name" NFSHomeDirectory |
    /usr/bin/cut -d ' ' -f 2-
)"
signing_directory="$user_home/Library/Application Support/BongoCat/Local Signing"
keychain_path="$signing_directory/BongoCat.keychain-db"
password_path="$signing_directory/keychain-password"
brew_bin="$(command -v brew || true)"

if [[ -n "${OPENSSL_BIN:-}" ]]; then
  openssl_bin="$OPENSSL_BIN"
elif [[ -n "$brew_bin" ]]; then
  openssl_bin="$($brew_bin --prefix openssl@3 2>/dev/null || true)/bin/openssl"
else
  openssl_bin=""
fi

if [[ -z "$openssl_bin" || ! -x "$openssl_bin" ]]; then
  echo "OpenSSL 3 is required. Install it with: brew install openssl@3" >&2
  exit 1
fi

if [[ -f "$keychain_path" && -f "$password_path" ]]; then
  keychain_password="$(<"$password_path")"
  /usr/bin/security unlock-keychain -p "$keychain_password" "$keychain_path"
  if /usr/bin/security find-identity -v -p codesigning "$keychain_path" |
    /usr/bin/grep -Fq "\"$identity_name\""; then
    echo "$keychain_path"
    exit 0
  fi
fi

/bin/mkdir -p "$signing_directory"
/bin/chmod 700 "$signing_directory"
temporary_directory="$(/usr/bin/mktemp -d)"
archive_password="$(/usr/bin/uuidgen)"
keychain_password="$(/usr/bin/uuidgen)"

cleanup() {
  /usr/bin/find "$temporary_directory" -depth -delete
}
trap cleanup EXIT

/usr/bin/security create-keychain -p "$keychain_password" "$keychain_path"
/usr/bin/security set-keychain-settings -lut 21600 "$keychain_path"
/usr/bin/security unlock-keychain -p "$keychain_password" "$keychain_path"
/usr/bin/printf '%s' "$keychain_password" > "$password_path"
/bin/chmod 600 "$password_path"

"$openssl_bin" req \
  -new \
  -newkey rsa:2048 \
  -x509 \
  -sha256 \
  -days 3650 \
  -nodes \
  -subj "/CN=$identity_name/" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" \
  -keyout "$temporary_directory/signing.key" \
  -out "$temporary_directory/signing.crt"

"$openssl_bin" pkcs12 \
  -export \
  -legacy \
  -name "$identity_name" \
  -inkey "$temporary_directory/signing.key" \
  -in "$temporary_directory/signing.crt" \
  -passout "pass:$archive_password" \
  -out "$temporary_directory/signing.p12"

/usr/bin/security import "$temporary_directory/signing.p12" \
  -k "$keychain_path" \
  -P "$archive_password" \
  -T /usr/bin/codesign \
  -T /usr/bin/security

/usr/bin/security set-key-partition-list \
  -S apple-tool:,apple: \
  -s \
  -k "$keychain_password" \
  "$keychain_path"

/usr/bin/security add-trusted-cert \
  -d \
  -r trustRoot \
  -p codeSign \
  -k "$keychain_path" \
  "$temporary_directory/signing.crt"

/usr/bin/security find-identity -v -p codesigning "$keychain_path"
