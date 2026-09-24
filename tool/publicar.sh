#!/usr/bin/env bash
# Publica una versión de Kairós por GitHub Releases (§43).
#
#   tool/publicar.sh 0.2.0 "Notas de la versión"
#
# Firma la estable (canal «prod», §51) con la clave de release de
# ~/.claves/kairos-release.properties. `--secretos` vuelve a subir los
# secretos de firma a GitHub (la primera vez o si la clave cambia).
# Necesita `gh auth login` hecho.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?Uso: tool/publicar.sh X.Y.Z \"notas\" [--secretos]}"
NOTES="${2:-Kairós $VERSION}"
REPO="cevasz/Kairos"
PROPS="${KAIROS_KEY_PROPS:-$HOME/.claves/kairos-release.properties}"
prop() { grep "^$1=" "$PROPS" | cut -d= -f2-; }

gh auth status >/dev/null 2>&1 || { echo "Falta: gh auth login"; exit 1; }

if [ "${3:-}" = "--secretos" ] || ! gh secret list -R "$REPO" | grep -q ANDROID_KEY_PASSWORD; then
  echo "Subiendo los secretos de firma ($(prop storeFile))…"
  base64 -w0 "$(prop storeFile)" | gh secret set ANDROID_KEYSTORE_BASE64 -R "$REPO"
  gh secret set ANDROID_KEYSTORE_PASSWORD -R "$REPO" -b "$(prop storePassword)"
  gh secret set ANDROID_KEY_ALIAS -R "$REPO" -b "$(prop keyAlias)"
  gh secret set ANDROID_KEY_PASSWORD -R "$REPO" -b "$(prop keyPassword)"
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push -u origin "$BRANCH"
git tag -a "v$VERSION" -m "$NOTES"
git push origin "v$VERSION"
echo "Tag v$VERSION subido. El workflow «release» compila y publica:"
echo "  gh run watch -R $REPO"
