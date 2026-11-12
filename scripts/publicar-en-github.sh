#!/usr/bin/env bash
# Sube cada carpeta local a su repositorio (ya creado) en la organización de GitHub.
#
# Uso, desde Git Bash en D:\ECOTEP:
#   ./cootep-turno/scripts/publicar-en-github.sh
# Requiere git con sesión de GitHub (la primera vez Git abre el navegador para autorizar).
set -euo pipefail

ORG="${ORG:-COOTEP-GESTOR-TURNOS}"
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"

# carpeta local : repositorio en GitHub
REPOS=(
  "backend-principal:backend-principal"
  "motor-filas:backend-motor-filas"
  "analitica:cootep-fastAPI"
  "web:frontend"
  "movil:mobile"
  "cootep-turno:cootep-turno"
)

for par in "${REPOS[@]}"; do
  carpeta="${par%%:*}"
  repo="${par##*:}"
  dir="$RAIZ/$carpeta"
  [ -d "$dir" ] || { echo "No existe la carpeta $dir" >&2; exit 1; }
  echo "== $carpeta -> $ORG/$repo"
  cd "$dir"
  [ -d .git ] || git init -b main
  git add -A
  git diff --cached --quiet || git commit -m "Esqueleto inicial de $repo"
  git remote get-url origin > /dev/null 2>&1 || git remote add origin "https://github.com/$ORG/$repo.git"
  # Si el repositorio se creó con README o licencia, primero se une esa historia.
  if git ls-remote --exit-code --heads origin main > /dev/null 2>&1; then
    git pull --no-rebase --allow-unrelated-histories --no-edit origin main
  fi
  git push -u origin main
done

echo "Listo. Ahora agregue los submódulos: ./cootep-turno/scripts/agregar-submodulos.sh"
