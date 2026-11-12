// MongoDB lo ejecuta una sola vez, cuando el volumen está vacío.
// Crea el usuario de la aplicación, las colecciones con validación y los índices.

const cootep = db.getSiblingDB('cootep');

cootep.createUser({
  user: 'cootep_app',
  pwd: process.env.MONGO_APP_PASSWORD,
  roles: [{ role: 'readWrite', db: 'cootep' }],
});

// Historial de eventos de cada turno: origen de la analítica.
cootep.createCollection('eventos_turno', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['eventoId', 'tipo', 'turnoId', 'agenciaId', 'servicioId', 'estadoNuevo', 'ocurridoEn'],
      properties: {
        eventoId: { bsonType: 'string' },
        tipo: { bsonType: 'string' },
        turnoId: { bsonType: 'string' },
        agenciaId: { bsonType: 'string' },
        servicioId: { bsonType: 'string' },
        asociadoId: { bsonType: 'string' },
        tipoAtencion: { enum: ['GENERAL', 'PREFERENCIAL'] },
        estadoAnterior: { bsonType: ['string', 'null'] },
        estadoNuevo: { bsonType: 'string' },
        actorId: { bsonType: ['string', 'null'] },
        canal: { enum: ['WEB', 'MOVIL'] },
        ocurridoEn: { bsonType: 'date' },
        datos: { bsonType: 'object' },
      },
    },
  },
});
// Escrituras idempotentes: un reintento con el mismo eventoId no duplica el evento.
cootep.eventos_turno.createIndex({ eventoId: 1 }, { unique: true, name: 'ux_evento' });
cootep.eventos_turno.createIndex({ turnoId: 1, ocurridoEn: 1 }, { name: 'ix_turno_tiempo' });
cootep.eventos_turno.createIndex({ agenciaId: 1, servicioId: 1, ocurridoEn: -1 }, { name: 'ix_fila_tiempo' });
cootep.eventos_turno.createIndex({ ocurridoEn: 1 }, { name: 'ix_tiempo' });

// Avisos enviados a cada usuario; se borran solos a los 90 días.
cootep.createCollection('notificaciones');
cootep.notificaciones.createIndex({ usuarioId: 1, creadaEn: -1 }, { name: 'ix_usuario_fecha' });
cootep.notificaciones.createIndex({ creadaEn: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 90, name: 'ttl_90_dias' });

// Marca de tiempo de la última carga a ClickHouse (carga incremental).
cootep.createCollection('etl_marcas');
