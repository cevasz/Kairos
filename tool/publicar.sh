#!/usr/bin/env bash
# Publica una versión de Kairós por GitHub Releases (§43).
#
#   tool/publicar.sh 0.2.0 "Notas de la versión"
#
# La primera vez sube los secretos de firma con la clave que firma la app ya
# instalada en el teléfono (~/.android/debug.keystore): así la versión nueva
# se instala encima sin perder datos. Necesita `gh auth login` hecho.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Uso: tool/publicar.sh X.Y.Z \"notas\"}"
NOTES="${2:-Kairós $VERSION}"
REPO="cevasz/Kairos"
KEYSTORE="${KAIROS_KEYSTORE:-$HOME/.android/debug.keystore}"

gh auth status >/dev/null 2>&1 || { echo "Falta: gh auth login"; exit 1; }

if ! gh secret list -R "$REPO" | grep -q ANDROID_KEYSTORE_BASE64; then
  echo "Subiendo los secretos de firma ($KEYSTORE)…"
  base64 -w0 "$KEYSTORE" | gh secret set ANDROID_KEYSTORE_BASE64 -R "$REPO"
  gh secret set ANDROID_KEYSTORE_PASSWORD -R "$REPO" -b "${KAIROS_STORE_PASSWORD:-android}"
  gh secret set ANDROID_KEY_ALIAS -R "$REPO" -b "${KAIROS_KEY_ALIAS:-androiddebugkey}"
  gh secret set ANDROID_KEY_PASSWORD -R "$REPO" -b "${KAIROS_KEY_PASSWORD:-android}"
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push -u origin "$BRANCH"
git tag -a "v$VERSION" -m "$NOTES"
git push origin "v$VERSION"
echo "Tag v$VERSION subido. El workflow «release» compila y publica:"
echo "  gh run watch -R $REPO"
