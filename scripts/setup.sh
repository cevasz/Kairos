#!/usr/bin/env bash
# Deja el proyecto listo para correr. Idempotente.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Falta Flutter en el PATH."; exit 1; }

echo "==> Dependencias"
flutter pub get

echo "==> Tokens (tema + microcopy) desde design/tokens.json"
dart run tool/gen_tokens.dart

echo "==> Drift"
dart run build_runner build --delete-conflicting-outputs

echo "==> Tests de dominio"
flutter test

echo "Listo."
