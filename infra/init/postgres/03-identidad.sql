-- Módulo de identidad: verificación de correo, cuentas federadas sin documento y ámbito de roles.
-- Es idempotente: en un volumen nuevo corre después de 01 y 02; en uno ya creado se aplica con
--   docker compose -f infra/compose.datos.yml exec -T postgres \
--     psql -U cootep -d cootep -f /docker-entrypoint-initdb.d/03-identidad.sql
-- (en Git Bash anteponga MSYS_NO_PATHCONV=1 para que no convierta la ruta del contenedor).

-- Las cuentas que ya existían (superadministrador y demostración) quedan con el correo verificado;
-- las nuevas empiezan sin verificar hasta que abran el enlace del correo.
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS email_verificado boolean NOT NULL DEFAULT true;
ALTER TABLE usuario ALTER COLUMN email_verificado SET DEFAULT false;

ALTER TABLE usuario ADD COLUMN IF NOT EXISTS ultimo_ingreso_en timestamptz;
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS actualizado_en   timestamptz NOT NULL DEFAULT now();

-- Quien entra con Google no trae documento: lo completa después. Tipo y número van juntos.
ALTER TABLE usuario ALTER COLUMN tipo_documento   DROP NOT NULL;
ALTER TABLE usuario ALTER COLUMN numero_documento DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_usuario_documento_completo') THEN
        ALTER TABLE usuario ADD CONSTRAINT ck_usuario_documento_completo
            CHECK ((tipo_documento IS NULL) = (numero_documento IS NULL));
    END IF;

    -- Un funcionario solo puede quedar asignado a un servicio que su agencia ofrece.
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_asignacion_agencia_servicio') THEN
        ALTER TABLE asignacion_rol ADD CONSTRAINT fk_asignacion_agencia_servicio
            FOREIGN KEY (agencia_id, servicio_id) REFERENCES agencia_servicio (agencia_id, servicio_id);
    END IF;
END
$$;

-- Listados de administración: usuarios por agencia y rol.
CREATE INDEX IF NOT EXISTS ix_asignacion_agencia_rol ON asignacion_rol (agencia_id, rol);
CREATE INDEX IF NOT EXISTS ix_identidad_usuario      ON identidad_federada (usuario_id);
