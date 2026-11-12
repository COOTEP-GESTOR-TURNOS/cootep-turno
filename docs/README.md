# Documentación

| Carpeta o archivo | Contenido |
| --- | --- |
| `informe/` | Informe del proyecto en PDF y en formato editable (exportado del documento del equipo) |
| `diagramas/` | Fuentes de los diagramas (Mermaid) |
| `openapi/` | Contratos OpenAPI exportados de los tres backends |
| `pruebas/` | Salida de `npm test`, `mvn test` y `pytest` de la versión etiquetada |

## Exportar los contratos OpenAPI

Con el sistema levantado (ver el README principal):

```bash
curl -s http://localhost:3000/api/docs-json -o docs/openapi/backend-principal.json
docker compose -f infra/compose.apps.yml exec motor-filas wget -qO- http://localhost:8080/v3/api-docs > docs/openapi/motor-filas.json
docker compose -f infra/compose.apps.yml exec analitica python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/openapi.json').read().decode())" > docs/openapi/analitica.json
```
