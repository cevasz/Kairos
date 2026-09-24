#!/usr/bin/env bash
# Entrega una versión de «Kairós Dev» (§52): la compila en este equipo (va
# firmada con su clave de depuración, la de la Dev instalada) y reemplaza el
# pre-release fijo `dev` de GitHub. La Dev del teléfono lo ve al abrirse y
# ofrece actualizar, igual que la estable con sus Releases.
#
#   tool/publicar-dev.sh ["qué trae"]
#
# El versionCode es 1000 + número de commits: crece solo con cada commit y
# nunca choca con los de la estable (otra app, otro id). Sin commits nuevos no
# hay versión nueva que ofrecer.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/flutter/bin:$HOME/.local/bin:$PATH"

REPO="cevasz/Kairos"
APK_NAME="kairos-dev.apk"
COMMITS=$(git rev-list --count HEAD)
CODE=$(( 1000 + COMMITS ))
BASE=$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')
NAME="$BASE-dev.$COMMITS"
NOTES="${1:-$(git log -5 --format='- %s')}"

[ -z "$(git status --porcelain -- lib android pubspec.yaml design)" ] || {
  echo "Hay cambios sin commit en la app: haz commit primero (el versionCode sale de los commits)."; exit 1; }

gh auth status >/dev/null 2>&1 || { echo "Falta: gh auth login"; exit 1; }

flutter build apk --release --flavor dev --target-platform android-arm64 \
  --build-name="$NAME" --build-number="$CODE"
OUT=$(mktemp -d)
cp build/app/outputs/flutter-apk/app-dev-release.apk "$OUT/$APK_NAME"
jq -n --argjson code "$CODE" --arg name "$NAME" \
  --arg apk "https://github.com/$REPO/releases/download/dev/$APK_NAME" \
  --arg notes "$NOTES" \
  '{versionCode: $code, versionName: $name, apk: $apk, notes: $notes}' > "$OUT/version.json"

if ! gh release view dev -R "$REPO" >/dev/null 2>&1; then
  gh release create dev -R "$REPO" --prerelease --target "$(git rev-parse HEAD)" \
    --title "Kairós Dev (versión de desarrollo)" \
    --notes "Versión de trabajo. Si buscas la app, baja la última versión estable, no esta."
fi
gh release upload dev -R "$REPO" "$OUT/$APK_NAME" "$OUT/version.json" --clobber
echo "Kairós Dev $NAME (versionCode $CODE) publicada. La Dev la ofrece al abrirse."
