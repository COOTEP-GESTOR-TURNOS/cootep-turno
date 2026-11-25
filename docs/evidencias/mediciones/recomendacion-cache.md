# Recomendación de horario con y sin caché (S2-04)

Con caché la recomendación responde en **3,5 ms de mediana contra 18,1 ms** cuando cada consulta va hasta la analítica: 5,2 veces más rápida. De 500 consultas, 484 se respondieron desde Redis (96,8 %); los 16 fallos son la primera consulta de cada una de las 16 filas.

| Corrida (24 nov 2026) | Sin caché: mediana / p95 | Con caché: mediana / p95 | Aciertos / fallos | Mejora de la mediana |
|---|---|---|---|---|
| 1 | 18,7 / 30,8 ms | 3,4 / 4,6 ms | 484 / 16 (96,8 %) | 5,5 veces |
| 2 (la del medio, la que se reporta) | 18,1 / 27 ms | 3,5 / 6,3 ms | 484 / 16 (96,8 %) | 5,2 veces |
| 3 | 18,3 / 37,1 ms | 3,4 / 6,4 ms | 484 / 16 (96,8 %) | 5,5 veces |

Cómo se mide (`scripts/medir-cache.js`):

- `GET /api/v1/recomendaciones` del backend principal en el stack de Docker, con un token de asociado, sobre 16 filas (8 agencias, 2 servicios cada una) y la fecha de hoy.
- Sin caché: 100 consultas; antes de cada una se borra su clave `cache:recomendacion:*` en Redis, así todas llegan a la analítica (FastAPI + ClickHouse).
- Con caché: la caché empieza vacía y se hacen 500 consultas al azar (semilla 7) sobre las mismas 16 filas. Aciertos y fallos salen de `GET /api/v1/metricas` (contadores del adaptador `CacheRedisAdapter`), antes y después.
- La lectura en Redis tarda 0,23 ms de media; la clave vive 15 minutos (`TTL_RECOMENDACION_SEG`) y lleva el prefijo `cache:`, separado de las sesiones (`sess:`).
- 10 consultas de calentamiento fuera de la medición. Equipo de desarrollo: Windows 11, 12 CPU, Docker 29.
