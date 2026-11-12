#!/usr/bin/env bash
# Agrega los cinco repositorios de código como submódulos en apps/ del repositorio paraguas.
#
# Uso, desde Git Bash, después de subir los repositorios:
#   ./cootep-turno/scripts/agregar-submodulos.sh
set -euo pipefail

ORG="${ORG:-COOTEP-GESTOR-TURNOS}"
cd "$(dirname "$0")/.."

# ruta en apps/ : repositorio en GitHub
REPOS=(
  "backend-principal:backend-principal"
  "motor-filas:backend-motor-filas"
  "analitica:cootep-fastAPI"
  "web:frontend"
  "movil:mobile"
)

for par in "${REPOS[@]}"; do
  ruta="apps/${par%%:*}"
  repo="${par##*:}"
  [ -e "$ruta" ] || git submodule add "https://github.com/$ORG/$repo.git" "$ruta"
done
git submodule update --init --recursive

git add .gitmodules apps
git commit -m "Agrega los repositorios como submódulos"
git push
echo "Listo. Para la entrega: git tag v1.0.0 && git push --tags"
