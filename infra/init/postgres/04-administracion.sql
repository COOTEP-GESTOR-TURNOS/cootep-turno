-- Gestión de agencias (RF-17): una agencia puede dejar de ofrecer un servicio sin borrar la fila,
-- porque los turnos históricos la referencian. Idempotente, como 03-identidad.sql:
--   MSYS_NO_PATHCONV=1 docker compose -f infra/compose.datos.yml exec -T postgres \
--     psql -U cootep -d cootep -f /docker-entrypoint-initdb.d/04-administracion.sql

ALTER TABLE agencia_servicio ADD COLUMN IF NOT EXISTS activo boolean NOT NULL DEFAULT true;
ALTER TABLE agencia_servicio ADD COLUMN IF NOT EXISTS actualizado_en timestamptz NOT NULL DEFAULT now();
ALTER TABLE agencia_servicio ADD COLUMN IF NOT EXISTS actualizado_por uuid REFERENCES usuario (id);

-- Un parámetro se guarda como texto; estos CHECK evitan valores que romperían las reglas aunque
-- alguien edite la tabla a mano. La validación detallada (rangos) la hace el backend.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_parametro_horario') THEN
        ALTER TABLE parametro ADD CONSTRAINT ck_parametro_horario
            CHECK (clave NOT LIKE 'HORARIO_%' OR valor ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$');
    END IF;
    -- EDAD_ADULTO_MAYOR es global: la ley no cambia de una agencia a otra.
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_parametro_edad_global') THEN
        ALTER TABLE parametro ADD CONSTRAINT ck_parametro_edad_global
            CHECK (clave <> 'EDAD_ADULTO_MAYOR' OR agencia_id IS NULL);
    END IF;
END
$$;
