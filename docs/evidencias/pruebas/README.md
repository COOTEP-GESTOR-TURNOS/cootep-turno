# Evidencia de las pruebas (sección 9 del informe)

Salida completa de las pruebas automatizadas de cada repositorio, corridas el 24 de noviembre de
2026 sobre la rama `main` de cada uno: **276 pruebas, todas pasan**. Las 17 pruebas del plan
(PR-01 a PR-17) están entre ellas.

| Repositorio | Commit | Comando | Resultado | Archivo |
|---|---|---|---|---|
| backend-principal | `f030d57` | `npm test` (unitarias + integración con Docker) | 172 + 11 pasan | [backend-principal-npm-test.txt](backend-principal-npm-test.txt) |
| motor-filas | `cd2ff30` | `mvn test` (Redis con Testcontainers) | 11 pasan, 0 omitidas | [motor-filas-mvn-test.txt](motor-filas-mvn-test.txt) |
| analitica | `5557597` | `pytest -v` | 50 pasan | [analitica-pytest.txt](analitica-pytest.txt) |
| web | `837d35d` | `vitest run` | 32 pasan | [web-vitest.txt](web-vitest.txt) |

Entorno: Windows 11, Docker 29.4.2, Node 24.14.1, Python 3.12.0, Maven 3.9.9 con Temurin 21 (imagen
oficial de Docker). La app móvil no tiene pruebas automatizadas en el plan.

## Dónde está cada prueba del plan

| ID | Qué verifica | Repositorio | Prueba | Resultado |
|---|---|---|---|---|
| PR-01 | Transiciones válidas del turno | backend-principal | `test/turno.spec.ts` › PR-01: recorre el ciclo completo y registra un evento por transición | Pasa |
| PR-02 | Una transición inválida lanza conflicto | backend-principal | `test/turno.spec.ts` › PR-02: rechaza una transición inválida | Pasa |
| PR-03 | Solicitar turno con adaptadores en memoria | backend-principal | `test/solicitar-turno.spec.ts` › PR-03: crea el turno, lo encola, publica sus eventos y avisa a la fila | Pasa |
| PR-04 | Un segundo turno activo devuelve conflicto | backend-principal | `test/solicitar-turno.spec.ts` › PR-04: un segundo turno activo del mismo asociado devuelve conflicto (RN-01) | Pasa |
| PR-05 | Política preferencial por edad | backend-principal | `test/politica-preferencial.spec.ts` › PR-05 (5 casos: 60 años, cumple mañana, autodeclaración, sin datos, edad cumplida) | Pasa |
| PR-06 | 200 encolamientos simultáneos sin números repetidos | motor-filas | `FilaConcurrenciaTest.doscientosEncolamientosSimultaneos` | Pasa |
| PR-07 | Dos llamados simultáneos reciben turnos distintos | motor-filas | `FilaConcurrenciaTest.dosFuncionariosNoRepiten` | Pasa |
| PR-08 | Orden de llamado con la regla K | motor-filas | `FilaConcurrenciaTest.respetaLaReglaK` | Pasa |
| PR-09 | Cálculo de personas delante | motor-filas | `CalculoPosicionTest` (5 casos) | Pasa |
| PR-10 | Fórmula de espera estimada | analitica | `tests/test_estimacion.py` (4 casos) | Pasa |
| PR-11 | Recomendación ordena las franjas por espera | analitica | `tests/test_recomendacion.py::test_ordena_por_menor_espera_y_descarta_pocos_datos` y 3 casos más | Pasa |
| PR-12 | El endpoint de salud responde | analitica | `tests/test_api.py::test_salud_responde_sin_token` y 2 casos del token de servicio | Pasa |
| PR-13 | La ruta protegida exige el rol | web | `src/auth/permisos.test.ts` › PR-13: rutas por rol (4 casos) | Pasa |
| PR-14 | Un asociado no puede cancelar un turno ajeno (403 o 404) | backend-principal | `test/integracion/turnos-http.int-spec.ts` › PR-14 (2 casos: 404 para el turno ajeno; 401 sin sesión y 403 con otro rol) | Pasa |
| PR-15 | Dos solicitudes simultáneas: una entra y la otra recibe 409 | backend-principal | `test/integracion/turnos-http.int-spec.ts` › PR-15 (2 casos: 5 rondas 201/409; misma Idempotency-Key) | Pasa |
| PR-16 | Un administrador no modifica otra agencia | backend-principal | `test/administracion/gestionar-agencias.spec.ts`, `administrar-usuarios.spec.ts` y `test/analitica/consultar-indicadores.spec.ts` › PR-16 | Pasa |
| PR-17 | Cinco intentos fallidos devuelven 429 | backend-principal | `test/identidad/autenticacion.spec.ts` › PR-17 | Pasa |

## Cómo repetirlas

Docker debe estar en marcha: PR-06 a PR-08 y PR-14, PR-15 levantan Redis y PostgreSQL con
Testcontainers.

```bash
# backend-principal
npm ci && npm test

# web
npm ci && npx vitest run --reporter=verbose

# analitica
python -m venv .venv && source .venv/Scripts/activate && pip install -r requirements-dev.txt && pytest -v

# motor-filas, sin Maven instalado: la imagen oficial con acceso a Docker para Testcontainers
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)":/app -v cootep-m2:/root/.m2 \
  -v /var/run/docker.sock:/var/run/docker.sock -e TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal \
  -w /app maven:3.9.9-eclipse-temurin-21 mvn -B -ntp test
```

En motor-filas, sin el socket de Docker JUnit omite `FilaConcurrenciaTest` (PR-06 a PR-08) en vez
de fallar: el resumen debe decir `Skipped: 0`. Las advertencias de reconexión a Redis del final son
de Spring al apagarse después de que Testcontainers detiene el contenedor; no son fallas.
