#!/usr/bin/env bash
# Arranca Cassandra, espera a que acepte conexiones y aplica el esquema de auditoría.
# El esquema usa IF NOT EXISTS, así que se puede aplicar en cada arranque.
set -euo pipefail

docker-entrypoint.sh cassandra -f &
PID=$!
trap 'kill -TERM "$PID"; wait "$PID"' TERM INT

until cqlsh -e 'DESCRIBE KEYSPACES' > /dev/null 2>&1; do
  sleep 5
done

cqlsh -f /init/01-esquema.cql
echo "Esquema de auditoria aplicado"

wait "$PID"
