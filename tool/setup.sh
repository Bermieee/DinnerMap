#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null; then
  echo 'Install the free Flutter SDK first: https://docs.flutter.dev/get-started/install'
  exit 1
fi
if [[ ! -d android || ! -d web ]]; then
  target_dir=$(mktemp -d)
  flutter create --platforms=android,web --org=com.dinnermap --project-name=dinnermap "$target_dir/dinnermap"
  [[ -d android ]] || cp -r "$target_dir/dinnermap/android" .
  [[ -d web ]] || cp -r "$target_dir/dinnermap/web" .
  cp "$target_dir/dinnermap/.metadata" .
  rm -rf "$target_dir"
fi
python3 tool/configure_android.py
flutter pub get
