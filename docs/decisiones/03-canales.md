# 03 · Dos canales, clave de release y copia de seguridad

Heredado de Cátedra §51 (24 sep 2026).

- **Sabores:** `prod` («Kairós», `com.kairos.app`) y `dev` («Kairós Dev»,
  `com.kairos.app.dev`, ícono sobre terracota). Se instalan juntas y cada una
  tiene sus datos. `flutter build apk --flavor dev|prod`.
- **Firmas:** la estable firma con `~/.claves/kairos-release.jks` (contraseña
  en `kairos-release.properties` al lado; `android/key.properties` es una
  copia local, fuera de git). La Dev firma con la clave de este equipo y no
  busca actualizaciones en GitHub.
- **Widgets** con nombre completo (`com.kairos.app.<Proveedor>`): en la Dev el
  id de la app es otro.
- **Copia de seguridad** en Ajustes: `.kairos` (SQLite). Restaurar valida el
  archivo, guarda la base vieja como `.antes-de-restaurar` y reabre.
- Todavía no hay repositorio en GitHub: `tool/publicar.sh` apunta a
  `cevasz/Kairos`, que hay que crear antes de la primera versión.

## La Dev también se actualiza sola (Cátedra §52)

La Dev lee `releases/download/dev/version.json`, un pre-release fijo `dev`
que `tool/publicar-dev.sh` reemplaza en cada entrega. Se compila en el
equipo (firma de depuración); versionCode = 1000 + número de commits.
