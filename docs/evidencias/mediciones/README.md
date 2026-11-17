# Mediciones de la sección 10 del informe

## Backend principal: consulta de mi turno, secuencial contra en paralelo

En paralelo la consulta tarda 11,0 ms de mediana contra 14,4 ms en secuencia (percentil 95: 18,4
contra 21,0 ms): 1,3 veces más rápida. Lo que se ahorra (3 a 4 ms) es la llamada al motor de filas,
que queda oculta detrás de la de la analítica. Salida completa: [backend-mi-turno.txt](backend-mi-turno.txt).

| Corrida (17 nov 2026) | Secuencial: mediana / p95 | En paralelo: mediana / p95 | Mejora de la mediana |
|---|---|---|---|
| 1 · red de Docker | 16,57 / 21,94 ms | 12,23 / 15,49 ms | 1,35 veces |
| 2 · red de Docker (la del medio, la que se reporta) | 14,40 / 21,02 ms | 10,98 / 18,42 ms | 1,31 veces |
| 3 · red de Docker | 13,92 / 19,31 ms | 10,79 / 18,95 ms | 1,29 veces |
| Con 20 ms simulados en cada llamada remota | 56,28 / 58,77 ms | 31,52 / 34,45 ms | 1,79 veces |

Cómo se mide (`src/cli/medir-paralelismo.ts` de backend-principal):

- Se ejecuta el caso de uso real `ConsultarMiTurnoService` dentro del contenedor del backend, sobre
  PostgreSQL, la caché del catálogo en Redis, el motor de filas y la analítica por HTTP. Lo único
  que cambia entre los dos modos es cómo se esperan las dos llamadas remotas: `enSecuencia` o
  `enParalelo` (`Promise.allSettled`, lo que usa el servicio desplegado).
- 10 repeticiones de calentamiento por modo y luego 100 medidas por modo, alternando el orden en
  cada repetición para que ninguno se beneficie de ir primero. Mediana y percentil 95 por rango más
  cercano.
- La analítica se consulta para la franja de las 10:00, que tiene historial, aunque se mida de
  noche. Se anota también cuánto tarda cada llamada sola: motor de filas 3,6 a 4,8 ms, analítica 8,6
  a 10 ms de mediana.
- Equipo de desarrollo: Windows 11, 12 CPU, Docker 29.4.2, Node 22.12.0 en el contenedor.
- Los máximos de 100 a 190 ms de las corridas 2 y 3 son picos de la analítica; no mueven ni la
  mediana ni el percentil 95.

Para repetirla, con el stack arriba y un asociado con turno activo (la agencia debe estar en horario
al pedirlo):

```bash
docker compose -f infra/compose.apps.yml exec -T backend-principal \
  node dist/cli/medir-paralelismo.js <asociadoId> 100 10 0 10:00
```

El cuarto argumento suma un retardo simulado (ms) a cada llamada remota: muestra la mejora cuando
los servicios están en otra red, donde la diferencia crece con la latencia.
