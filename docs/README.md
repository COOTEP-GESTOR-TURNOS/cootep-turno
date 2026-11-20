# Documentación

| Carpeta o archivo | Contenido |
| --- | --- |
| `informe/` | Informe del proyecto en PDF y en formato editable (exportado del documento del equipo) |
| `diagramas/` | Fuentes de los diagramas (Mermaid) |
| [Guía rápida de Swagger](swagger.md) | Cómo recorrer la API y probar consultas desde el navegador |
| `openapi/` | Contratos OpenAPI exportados de los tres backends |
| `pruebas/` | Salida de `npm test`, `mvn test` y `pytest` de la versión etiquetada |

## Exportar los contratos OpenAPI

Ejecuta estos comandos desde la raíz del repositorio en Git Bash, con el sistema levantado. Cambia el puerto `8080` por el `PUERTO_WEB` de tu `infra/.env` si usas otro.

```bash
mkdir -p docs/openapi
curl -fsS http://localhost:8080/api/docs-json -o docs/openapi/backend-principal.json
docker compose --env-file infra/.env -f infra/compose.apps.yml exec -T motor-filas wget -qO- http://127.0.0.1:8080/v3/api-docs > docs/openapi/motor-filas.json
docker compose --env-file infra/.env -f infra/compose.apps.yml exec -T analitica python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/openapi.json').read().decode())" > docs/openapi/analitica.json
```
