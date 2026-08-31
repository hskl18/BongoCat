#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
cd "$project_root"

required_files=(
  AGENTS.md
  CONTRIBUTING.md
  LICENSE
  README.md
  THIRD_PARTY_NOTICES.md
  Package.swift
  Resources/Info.plist
  scripts/build-app.sh
  scripts/dev-local.sh
  scripts/prepare-cubism.sh
)

for path in $required_files; do
  if [[ ! -f "$path" ]]; then
    echo "Missing required public-repository file: $path" >&2
    exit 1
  fi
done

for script in scripts/*.sh; do
  /bin/zsh -n "$script"
done

/usr/bin/plutil -lint Resources/Info.plist >/dev/null

for locale in Resources/Locales/*.json; do
  /usr/bin/python3 -m json.tool "$locale" >/dev/null
done

if /usr/bin/grep -R -n -E '/Users/ice|/opt/homebrew' \
  --exclude-dir=.build \
  --exclude-dir=build \
  --exclude=check-repository.sh \
  .; then
  echo "Remove machine-specific paths before publishing." >&2
  exit 1
fi

for forbidden in \
  'Live2DCubismCore.h' \
  'libLive2DCubismCore.a' \
  'CubismFramework.cpp'; do
  if /usr/bin/find . \
    -path './.build' -prune -o \
    -path './build' -prune -o \
    -type f -name "$forbidden" -print -quit | /usr/bin/grep -q .; then
    echo "Live2D SDK file must not be committed: $forbidden" >&2
    exit 1
  fi
done

if ! /usr/bin/grep -Fq 'git clone https://github.com/hskl18/BongoCat.git' README.md; then
  echo "README must keep the clone command." >&2
  exit 1
fi

if ! /usr/bin/grep -Fq 'CUBISM_SDK_ROOT' README.md; then
  echo "README must explain how to locate the Cubism SDK." >&2
  exit 1
fi

echo "Repository checks passed."
