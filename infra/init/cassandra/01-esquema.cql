-- Auditoría de COOTEP Turno: solo inserción, particionada por ámbito y día.
-- La aplicación no tiene ninguna operación para borrar o editar estos registros.

CREATE KEYSPACE IF NOT EXISTS cootep
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

-- Consulta principal: auditoría de una agencia (o GLOBAL) en un día, de lo más reciente a lo más antiguo.
CREATE TABLE IF NOT EXISTS cootep.auditoria_por_ambito_dia (
  ambito         text,       -- 'GLOBAL' o el agencia_id
  dia            date,
  ocurrido_en    timeuuid,
  actor_id       uuid,
  actor_rol      text,
  accion         text,       -- ROL_ASIGNADO, LOGIN_ADMIN, LOGIN_FALLIDO, PARAMETRO_CAMBIADO, ...
  objetivo_tipo  text,
  objetivo_id    text,
  detalle        text,       -- JSON con los datos del cambio
  ip             text,
  PRIMARY KEY ((ambito, dia), ocurrido_en)
) WITH CLUSTERING ORDER BY (ocurrido_en DESC);

-- Consulta secundaria: qué hizo un usuario en un mes.
CREATE TABLE IF NOT EXISTS cootep.auditoria_por_actor (
  actor_id     uuid,
  mes          text,         -- 'AAAA-MM'
  ocurrido_en  timeuuid,
  accion       text,
  ambito       text,
  objetivo_id  text,
  PRIMARY KEY ((actor_id, mes), ocurrido_en)
) WITH CLUSTERING ORDER BY (ocurrido_en DESC);
