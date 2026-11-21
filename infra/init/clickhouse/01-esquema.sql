-- Modelo analítico de COOTEP Turno.
-- Origen: eventos_turno de MongoDB, cargados por el servicio de analítica.
-- Granularidad: un registro por turno finalizado (atendido, cancelado o ausente).
-- ReplacingMergeTree: volver a cargar un turno lo reemplaza (carga idempotente).

CREATE DATABASE IF NOT EXISTS cootep;

CREATE TABLE IF NOT EXISTS cootep.hechos_turno
(
    turno_id       UUID,
    agencia_id     UUID,
    servicio_id    UUID,
    fecha          Date,
    franja         LowCardinality(String),   -- inicio de la franja de 30 min, por ejemplo '09:30'
    dia_semana     UInt8,                    -- 1 = lunes ... 7 = domingo
    tipo_dia       LowCardinality(String),   -- NORMAL, QUINCENA o FESTIVO
    tipo_atencion  LowCardinality(String),   -- GENERAL o PREFERENCIAL
    canal          LowCardinality(String),   -- WEB o MOVIL
    estado_final   LowCardinality(String),   -- ATENDIDO, CANCELADO o AUSENTE
    espera_seg     UInt32,                   -- de la solicitud al llamado
    atencion_seg   UInt32,                   -- del inicio al fin de la atención
    solicitado_en  DateTime('America/Bogota'),
    colaborador_id Nullable(UUID),
    cargado_en     DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(cargado_en)
PARTITION BY toYYYYMM(fecha)
ORDER BY (agencia_id, servicio_id, fecha, turno_id);
