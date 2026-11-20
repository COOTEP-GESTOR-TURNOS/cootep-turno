# Guía rápida de Swagger para COOTEP Turno

Swagger UI permite explorar la API, revisar los campos de cada operación y hacer solicitudes desde el navegador. La interfaz del backend principal se genera a partir de su contrato OpenAPI.

## Abrir Swagger

Con el proyecto levantado, abre `/api/docs` en la misma dirección donde abres la web. Con los puertos por defecto, es [http://localhost:8080/api/docs](http://localhost:8080/api/docs). Si tu `infra/.env` usa `PUERTO_WEB=8580`, abre [http://localhost:8580/api/docs](http://localhost:8580/api/docs).

En esa misma dirección, `/api/docs-json` entrega el contrato OpenAPI en JSON. Puedes usarlo para revisar la especificación o exportarla junto con los [contratos internos](README.md#exportar-los-contratos-openapi).

## Primera prueba sin iniciar sesión

1. Abre la sección **operación** y selecciona `GET /api/v1/salud`.
2. Pulsa **Try it out** y luego **Execute**.
3. En **Server response**, comprueba que el código sea `200`, `estado` sea `ok` y `servicio` sea `backend-principal`. El campo `hora` indica cuándo respondió el servidor.

## Probar una consulta con tu cuenta

1. En **identidad**, abre `POST /api/v1/auth/login` y pulsa **Try it out**. Completa `correo` y `clave` con los datos de una cuenta de prueba que ya esté activada.

   ```json
   {
     "correo": "asociado@example.com",
     "clave": "CONTRASENA_DE_PRUEBA"
   }
   ```

2. Pulsa **Execute**. Si la respuesta trae `PASO_PENDIENTE`, usa la web para completar el cambio de clave o la configuración inicial de MFA. Si el paso es `VERIFICAR_MFA` y ya tienes un autenticador configurado, ejecuta `POST /api/v1/auth/mfa/verificar` en Swagger con el `reto` recibido y el `codigo` actual de tu autenticador.
3. Cuando obtengas `SESION_INICIADA`, copia el valor de `tokenAcceso`. Pulsa **Authorize**, pega solo el valor del token y confirma. Swagger añade el prefijo `Bearer` al enviarlo.
4. Ejecuta `GET /api/v1/auth/yo` para ver el perfil y sus roles. Luego ejecuta `GET /api/v1/agencias` para consultar agencias, servicios y ventanillas. Con una cuenta de asociado también puedes usar `GET /api/v1/turnos/mio` para consultar su turno activo.

## Operaciones para explorar

| Operación | Quién la puede usar | Qué hace |
| --- | --- | --- |
| `GET /api/v1/agencias` | Cuenta autenticada | Muestra el catálogo. De aquí salen los identificadores de agencia y servicio. |
| `GET /api/v1/turnos/mio` | Asociado | Devuelve su turno activo. Responde `404` si no tiene uno. |
| `POST /api/v1/turnos` | Asociado | Solicita un turno. Pide `agenciaId`, `servicioId`, `canal` y un UUID en la cabecera `Idempotency-Key`. |
| `POST /api/v1/filas/{agenciaId}/{servicioId}/siguiente` | Funcionario o administrador de esa agencia, según su ámbito | Llama al siguiente turno. Responde `204` si la fila está vacía. |
| `GET /api/v1/indicadores` | Superadministrador o administrador de agencia | Consulta indicadores de atención. El administrador de agencia ve su ámbito. |
| `GET /api/v1/admin/auditoria` | Superadministrador | Consulta eventos de auditoría por ámbito y día. |

Los dos `POST` de la tabla cambian datos. Para practicar el recorrido sin generar turnos, usa las consultas `GET`.

## Si una solicitud falla

| Respuesta | Qué revisar |
| --- | --- |
| `400` | Los campos obligatorios, el formato de los UUID y las cabeceras que pide Swagger. |
| `401` | Que hayas autorizado con un `tokenAcceso` vigente. |
| `403` | Que el rol y la agencia de la cuenta permitan esa operación. |
| `404` | Que el registro exista. En `turnos/mio` puede significar que la cuenta está sin turno activo. |

El cuerpo del error puede incluir `detail` y `codigo` para identificar el motivo.
