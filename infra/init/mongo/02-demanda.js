// Se puede ejecutar de nuevo en volúmenes existentes para crear estos índices.
const baseDemanda = db.getSiblingDB('cootep');

baseDemanda.eventos_turno.createIndex(
  { agenciaId: 1, estadoNuevo: 1, ocurridoEn: 1 },
  { name: 'ix_agencia_estado_tiempo' },
);
baseDemanda.eventos_turno.createIndex(
  { agenciaId: 1, estadoNuevo: 1, servicioId: 1, ocurridoEn: 1 },
  { name: 'ix_agencia_estado_servicio_tiempo' },
);

for (const nombre of ['eventos_agencia', 'eventos_agencia_demo']) {
  const eventos = baseDemanda.getCollection(nombre);
  eventos.createIndex({ agenciaId: 1, fecha: 1, tipo: 1 }, { unique: true, name: 'ux_agencia_fecha_tipo' });
  eventos.createIndex({ agenciaId: 1, id: 1 }, { unique: true, name: 'ux_agencia_evento' });
}

baseDemanda.demanda_diaria_demo.createIndex({ agenciaId: 1, fecha: 1 }, { unique: true, name: 'ux_agencia_fecha' });
