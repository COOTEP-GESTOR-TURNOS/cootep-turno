# COOTEP Turno

Prototipo académico de filas virtuales para 8 agencias simuladas de COOTEP
(Programación Avanzada – Bases de Datos No Relacionales, Uniputumayo, 2026-2).

Este es el repositorio **paraguas** de la entrega: contiene la infraestructura Docker,
la documentación y, como submódulos, los cinco repositorios de código. Su etiqueta
(`v1.0.0`, por ejemplo) fija el commit exacto de cada submódulo, así que es el único
enlace y el único identificador que se entrega en Moodle.

## Repositorios de la organización

Organización: <https://github.com/COOTEP-GESTOR-TURNOS>

| Repositorio | Tecnología | Arquitectura | Submódulo en |
| --- | --- | --- | --- |
| `backend-principal` | TypeScript · NestJS 11 · Node.js 22 | Hexagonal | `apps/backend-principal` |
| `backend-motor-filas` | Java 21 · Spring Boot 3.5 | MVC | `apps/motor-filas` |
| `cootep-fastAPI` | Python 3.12 · FastAPI | MVC | `apps/analitica` |
| `frontend` | React 19 · Vite 6 · nginx | Componentes por rol | `apps/web` |
| `mobile` | React Native · Expo SDK 58 (APK) | Pantallas por rol | `apps/movil` |
| `cootep-turno` (este) | Docker Compose, scripts, documentación | — | — |

## Arquitectura

```mermaid
flowchart LR
  subgraph Clientes
    NAV[Navegador web]
    APK[App móvil APK]
  end
  subgraph apps[compose.apps.yml]
    NGINX[web · nginx]
    BP[backend-principal · NestJS hexagonal]
    MF[motor-filas · Spring Boot MVC]
    AN[analitica · FastAPI MVC]
  end
  subgraph datos[compose.datos.yml]
    PG[(PostgreSQL)]
    RD[(Redis)]
    MG[(MongoDB)]
    CS[(Cassandra)]
    CH[(ClickHouse)]
  end
  NAV --> NGINX --> BP
  APK --> BP
  BP --> MF
  BP --> AN
  BP --- PG & RD & MG & CS
  MF --- RD
  AN --- MG & CH
```

Solo el backend principal recibe a los clientes. El motor de filas y la analítica no
publican puertos: se alcanzan únicamente dentro de la red externa `cootep-net`.

## Puesta en marcha

Requisitos: Docker Desktop con Compose v2, Git y unos 8 GB de RAM libres.

```bash
git clone --recurse-submodules https://github.com/COOTEP-GESTOR-TURNOS/cootep-turno.git
cd cootep-turno
cp infra/.env.example infra/.env        # y cambie TODAS las contraseñas
docker network create cootep-net
docker compose -f infra/compose.datos.yml up -d --wait
docker compose -f infra/compose.apps.yml up -d --build --wait
docker compose -f infra/compose.apps.yml exec backend-principal node dist/cli/crear-superadmin.js
```

Si Docker responde `ports are not available ... forbidden by its access permissions`, Windows
reservó ese puerto (pasa con 8080 y 8025 después de algunos reinicios). Hay dos salidas:

- Liberarlo: en una terminal de administrador, `net stop winnat` y luego `net start winnat`.
- Usar otro puerto: `PUERTO_WEB`, `PUERTO_CORREO` y `PUERTO_BACKEND` en `infra/.env`. Si cambia el de
  la web, ajuste `URL_PUBLICA` y agregue el nuevo URI de redireccionamiento en Google.

El orden importa: primero la red, luego los datos (el `--wait` espera sus healthchecks;
Cassandra tarda 1 a 2 minutos) y al final las aplicaciones.

| Servicio | URL en el equipo |
| --- | --- |
| Web | <http://localhost:8080> |
| API del backend principal | <http://localhost:3000/api/v1> |
| OpenAPI del backend principal | <http://localhost:3000/api/docs> |
| Buzón de correo de pruebas (Mailpit) | <http://localhost:8025> |

### Primer ingreso y cuentas

1. Ingrese en la web con `SUPERADMIN_EMAIL` y `SUPERADMIN_PASSWORD_TEMPORAL`. El sistema pide
   cambiar la clave y activar la verificación en dos pasos (escanee el QR con Google Authenticator).
2. En **Administración**, cree el directivo de cada agencia (rol administrador de agencia). Le llega
   un correo (en Mailpit) para definir su clave; en su primer ingreso también activa MFA.
3. El directivo da de alta a los funcionarios de su agencia y les asigna su servicio.
4. Los asociados se registran solos en **Crea tu cuenta** o entran con Google.

Los correos de activación, confirmación y recuperación llegan a Mailpit. Para enviarlos de verdad
(por ejemplo con Gmail y una contraseña de aplicación) cambie `SMTP_*` en `infra/.env`.

### Migraciones de PostgreSQL

Los scripts de `infra/init/postgres` corren solos cuando el volumen está vacío. Si su volumen ya
existía, aplique los nuevos a mano (son idempotentes). En Git Bash anteponga `MSYS_NO_PATHCONV=1`:

```bash
MSYS_NO_PATHCONV=1 docker compose -f infra/compose.datos.yml exec -T postgres psql -U cootep -d cootep -f /docker-entrypoint-initdb.d/03-identidad.sql
```

Si clonó los repositorios como carpetas hermanas (sin submódulos), ajuste las variables
`RUTA_*` de `infra/.env` (por ejemplo `RUTA_BACKEND_PRINCIPAL=../../backend-principal`).

### APK

La app móvil se compila fuera de Docker. En `movil/.env` ponga la IP del computador en la
red local (`EXPO_PUBLIC_API_URL=http://192.168.x.x:3000`), nunca `localhost`. Los pasos
están en el README del repositorio `movil`.

## Datos de prueba

- `infra/init/postgres/02-datos-prueba.sql`: 8 agencias, 4 servicios, ventanillas y parámetros.
- `analitica`: `python -m app.scripts.generar_historial --dias 90` carga historial simulado en MongoDB.
- Todos los datos son ficticios. No suba datos personales reales.

## Respaldo y recuperación de volúmenes

Los comandos se ejecutan con `docker compose -f infra/compose.datos.yml exec <servicio> ...`.

| Motor | Respaldo | Recuperación |
| --- | --- | --- |
| PostgreSQL | `pg_dump -Fc -U cootep cootep > /tmp/cootep.dump` | `pg_restore -U cootep -d cootep --clean /tmp/cootep.dump` |
| MongoDB | `mongodump -u root -p <clave> --authenticationDatabase admin --db cootep --archive=/tmp/cootep.archive` | `mongorestore ... --archive=/tmp/cootep.archive --drop` |
| Redis | Archivo AOF en el volumen `redis_datos` | El backend principal reconstruye las filas desde PostgreSQL |
| Cassandra | `nodetool snapshot cootep` | Copiar las SSTables de la instantánea y cargarlas con `nodetool import` |
| ClickHouse | No hace falta: es derivado | `POST /api/v1/etl/ejecutar?completa=true` en la analítica |

`docker compose down` conserva los volúmenes; `docker compose down -v` los borra.

## Trabajo en equipo con ramas

`main` siempre debe compilar y pasar las pruebas: nadie trabaja directo sobre ella. Cada
funcionalidad va en su rama, con el **mismo nombre en todos los repositorios que toca**, y entra a
`main` con un pull request que revisa otro integrante.

| Rama | Contenido | Repositorios |
| --- | --- | --- |
| `feature/identidad` | Inicio local y con Google, MFA, registro, recuperación por correo, administración de usuarios y roles | backend-principal, frontend, mobile, cootep-turno |
| `feature/administracion-agencias` | Servicios, ventanillas, horario y parámetros por agencia; auditoría para el superadministrador | backend-principal, frontend, mobile |
| `feature/turnos-catalogo` | Catálogo real (`GET /agencias`) en los paneles de turno; cierre de agencia y vencimientos | backend-principal, backend-motor-filas, frontend, mobile |
| `feature/analitica-tablero` | Indicadores y franjas recomendadas en la web y el móvil | cootep-fastAPI, frontend, mobile |

```bash
git switch main && git pull
git switch -c feature/<nombre>          # en cada repositorio que vaya a tocar
git push -u origin feature/<nombre>
```

Mensajes de commit en español y en presente («Agrega…», «Corrige…»). Cuando las ramas de una
funcionalidad se fusionan en `main`, se actualizan los submódulos de este repositorio.

## Trabajo con submódulos

```bash
git submodule update --remote --merge   # trae lo último de cada repositorio
git add apps && git commit -m "Actualiza submódulos"
git tag v1.0.0 && git push --follow-tags
```

Scripts de ayuda (desde Git Bash):

- `./scripts/publicar-en-github.sh`: sube cada carpeta a su repositorio de la organización.
- `./scripts/agregar-submodulos.sh`: agrega los cinco repositorios en `apps/`.
- `python scripts/empaquetar_entrega.py <url-de-este-repo> v1.0.0`: arma el ZIP para Moodle con el
  contenido de los submódulos (la descarga ZIP de GitHub no los incluye).

## Documentación

El informe (PDF y editable), los diagramas fuente y los contratos OpenAPI van en `docs/`.
