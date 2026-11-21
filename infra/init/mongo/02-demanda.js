// Se puede ejecutar de nuevo en volúmenes existentes. La analítica también crea estos índices al arrancar.
const baseDemanda = db.getSiblingDB('cootep');

baseDemanda.eventos_turno.createIndex(
  { agenciaId: 1, estadoNuevo: 1, ocurridoEn: 1 },
  { name: 'ix_agencia_estado_tiempo' },
);
baseDemanda.eventos_turno.createIndex(
  { agenciaId: 1, estadoNuevo: 1, servicioId: 1, ocurridoEn: 1 },
  { name: 'ix_agencia_estado_servicio_tiempo' },
);

// Los datos de demostración viven en estas mismas colecciones con origen = SIMULADO.
baseDemanda.eventos_turno.createIndex(
  { origen: 1, agenciaId: 1 },
  { name: 'ix_origen_agencia', partialFilterExpression: { origen: { $exists: true } } },
);

baseDemanda.eventos_agencia.createIndex({ agenciaId: 1, fecha: 1, tipo: 1 }, { unique: true, name: 'ux_agencia_fecha_tipo' });
baseDemanda.eventos_agencia.createIndex({ agenciaId: 1, id: 1 }, { unique: true, name: 'ux_agencia_evento' });
