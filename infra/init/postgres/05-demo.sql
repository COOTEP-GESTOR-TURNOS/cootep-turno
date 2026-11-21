-- Metadatos de la demostración. Se puede aplicar a un volumen ya inicializado.
CREATE TABLE IF NOT EXISTS demo_escenario (
    unico   boolean PRIMARY KEY DEFAULT true CHECK (unico),
    semilla integer NOT NULL
);

CREATE TABLE IF NOT EXISTS demo_participante (
    usuario_id uuid PRIMARY KEY REFERENCES usuario (id),
    agencia_id uuid NOT NULL REFERENCES agencia (id),
    rol        varchar(20) NOT NULL CHECK (rol IN ('ADMIN_AGENCIA', 'FUNCIONARIO', 'ASOCIADO')),
    ordinal    integer NOT NULL CHECK (ordinal > 0),
    UNIQUE (agencia_id, rol, ordinal)
);

CREATE TABLE IF NOT EXISTS demo_lote_pendiente (
    fecha       date NOT NULL,
    agencia_id  uuid NOT NULL REFERENCES agencia (id),
    lote        varchar(64) NOT NULL,
    ordinal     integer NOT NULL CHECK (ordinal BETWEEN 1 AND 3),
    servicio_id uuid NOT NULL,
    asociado_id uuid NOT NULL REFERENCES demo_participante (usuario_id),
    PRIMARY KEY (fecha, agencia_id, lote, ordinal),
    UNIQUE (fecha, asociado_id),
    FOREIGN KEY (agencia_id, servicio_id) REFERENCES agencia_servicio (agencia_id, servicio_id)
);
