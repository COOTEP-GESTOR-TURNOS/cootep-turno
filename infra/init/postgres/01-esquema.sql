-- Esquema relacional de COOTEP Turno: fuente de verdad de usuarios, catálogo y turnos.
-- PostgreSQL lo ejecuta una sola vez, cuando el volumen está vacío.

CREATE TABLE agencia (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo     varchar(10)  NOT NULL UNIQUE,
    nombre     varchar(120) NOT NULL,
    municipio  varchar(80)  NOT NULL,
    activa     boolean      NOT NULL DEFAULT true,
    creado_en  timestamptz  NOT NULL DEFAULT now()
);

CREATE TABLE servicio (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo         varchar(10)  NOT NULL UNIQUE,
    nombre         varchar(120) NOT NULL,
    prefijo_turno  char(1)      NOT NULL,
    activo         boolean      NOT NULL DEFAULT true
);

-- Qué servicios ofrece cada agencia y con cuántas ventanillas.
CREATE TABLE agencia_servicio (
    agencia_id   uuid     NOT NULL REFERENCES agencia (id),
    servicio_id  uuid     NOT NULL REFERENCES servicio (id),
    ventanillas  smallint NOT NULL DEFAULT 1 CHECK (ventanillas > 0),
    PRIMARY KEY (agencia_id, servicio_id)
);

CREATE TABLE usuario (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    -- El correo se guarda normalizado (minúsculas, sin espacios); el CHECK lo garantiza.
    email                  varchar(254) NOT NULL CHECK (email = lower(btrim(email))),
    nombre                 varchar(120) NOT NULL,
    tipo_documento         varchar(5)   NOT NULL CHECK (tipo_documento IN ('CC', 'CE', 'TI', 'PA')),
    numero_documento       varchar(20)  NOT NULL,
    fecha_nacimiento       date,
    password_hash          text,          -- Argon2id; NULL si solo entra con Google o Microsoft
    mfa_secreto_cifrado    text,          -- TOTP cifrado; obligatorio para administradores
    debe_cambiar_password  boolean      NOT NULL DEFAULT false,
    activo                 boolean      NOT NULL DEFAULT true,
    creado_en              timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_usuario_email     ON usuario (email);
CREATE UNIQUE INDEX ux_usuario_documento ON usuario (tipo_documento, numero_documento);

-- Cuenta externa (OIDC) vinculada a un usuario local: el par (proveedor, sub) es único.
CREATE TABLE identidad_federada (
    proveedor   varchar(20)  NOT NULL CHECK (proveedor IN ('google', 'microsoft')),
    sujeto      varchar(255) NOT NULL,
    usuario_id  uuid         NOT NULL REFERENCES usuario (id),
    vinculado_en timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (proveedor, sujeto)
);

-- Rol y ámbito. SUPERADMIN y ASOCIADO no llevan agencia; ADMIN_AGENCIA y FUNCIONARIO sí.
CREATE TABLE asignacion_rol (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id   uuid        NOT NULL REFERENCES usuario (id),
    rol          varchar(20) NOT NULL CHECK (rol IN ('SUPERADMIN', 'ADMIN_AGENCIA', 'FUNCIONARIO', 'ASOCIADO')),
    agencia_id   uuid REFERENCES agencia (id),
    servicio_id  uuid REFERENCES servicio (id),
    asignado_por uuid REFERENCES usuario (id),
    asignado_en  timestamptz NOT NULL DEFAULT now(),
    CHECK (
        (rol IN ('SUPERADMIN', 'ASOCIADO') AND agencia_id IS NULL AND servicio_id IS NULL)
        OR (rol = 'ADMIN_AGENCIA' AND agencia_id IS NOT NULL AND servicio_id IS NULL)
        OR (rol = 'FUNCIONARIO' AND agencia_id IS NOT NULL)
    )
);
CREATE UNIQUE INDEX ux_asignacion_rol
    ON asignacion_rol (usuario_id, rol, agencia_id, servicio_id) NULLS NOT DISTINCT;

-- Parámetros globales (agencia_id NULL) o por agencia.
CREATE TABLE parametro (
    clave            varchar(60) NOT NULL,
    agencia_id       uuid REFERENCES agencia (id),
    valor            text        NOT NULL,
    actualizado_en   timestamptz NOT NULL DEFAULT now(),
    actualizado_por  uuid REFERENCES usuario (id)
);
CREATE UNIQUE INDEX ux_parametro ON parametro (clave, agencia_id) NULLS NOT DISTINCT;

-- Turno: estado actual. El historial completo vive en MongoDB (eventos_turno).
CREATE TABLE turno (
    id                  uuid PRIMARY KEY,                -- lo genera el backend principal
    agencia_id          uuid        NOT NULL,
    servicio_id         uuid        NOT NULL,
    asociado_id         uuid        NOT NULL REFERENCES usuario (id),
    fecha               date        NOT NULL,
    numero              integer     CHECK (numero > 0),  -- lo asigna el motor de filas al encolar
    codigo              varchar(8),                      -- por ejemplo C-014
    tipo_atencion       varchar(12) NOT NULL CHECK (tipo_atencion IN ('GENERAL', 'PREFERENCIAL')),
    estado              varchar(12) NOT NULL CHECK (estado IN (
                            'SOLICITADO', 'EN_ESPERA', 'PROXIMO', 'LLAMADO',
                            'EN_ATENCION', 'ATENDIDO', 'CANCELADO', 'AUSENTE')),
    canal               varchar(6)  NOT NULL CHECK (canal IN ('WEB', 'MOVIL')),
    motivo              varchar(30),                     -- motivo de cancelación o ausencia
    solicitado_en       timestamptz NOT NULL DEFAULT now(),
    proximo_en          timestamptz,                     -- desde aquí corre T_CONFIRMACION (RN-10)
    confirmado_en       timestamptz,                     -- el asociado confirmó que viene
    llamado_en          timestamptz,
    inicio_atencion_en  timestamptz,
    fin_en              timestamptz,
    atendido_por        uuid REFERENCES usuario (id),
    verificado_por      uuid REFERENCES usuario (id),
    idempotency_key     varchar(64),
    version             integer     NOT NULL DEFAULT 0,   -- bloqueo optimista
    FOREIGN KEY (agencia_id, servicio_id) REFERENCES agencia_servicio (agencia_id, servicio_id),
    CHECK (numero IS NOT NULL OR estado IN ('SOLICITADO', 'CANCELADO'))
);

-- RN-01: un asociado tiene como máximo un turno activo.
CREATE UNIQUE INDEX ux_turno_activo_asociado ON turno (asociado_id)
    WHERE estado IN ('SOLICITADO', 'EN_ESPERA', 'PROXIMO', 'LLAMADO', 'EN_ATENCION');
-- RN-02: número único por fila y día.
CREATE UNIQUE INDEX ux_turno_numero ON turno (agencia_id, servicio_id, fecha, numero);
-- Idempotencia de la solicitud (doble toque o reintento del cliente).
CREATE UNIQUE INDEX ux_turno_idempotencia ON turno (asociado_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;
CREATE INDEX ix_turno_fila_estado ON turno (agencia_id, servicio_id, fecha, estado);
