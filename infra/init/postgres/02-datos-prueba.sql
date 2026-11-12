-- Datos ficticios de prueba: 8 agencias, 4 servicios, ventanillas y parámetros.
-- Los identificadores son fijos para que coincidan en todos los motores y en las pruebas.
-- Los usuarios NO se crean aquí: el superadministrador se crea con el comando
-- crear-superadmin del backend principal (inicialización controlada).

INSERT INTO agencia (id, codigo, nombre, municipio) VALUES
    ('a0000000-0000-4000-8000-000000000001', 'AG01', 'Agencia Mocoa',            'Mocoa'),
    ('a0000000-0000-4000-8000-000000000002', 'AG02', 'Agencia Puerto Asís',      'Puerto Asís'),
    ('a0000000-0000-4000-8000-000000000003', 'AG03', 'Agencia Orito',            'Orito'),
    ('a0000000-0000-4000-8000-000000000004', 'AG04', 'Agencia La Hormiga',       'Valle del Guamuez'),
    ('a0000000-0000-4000-8000-000000000005', 'AG05', 'Agencia Sibundoy',         'Sibundoy'),
    ('a0000000-0000-4000-8000-000000000006', 'AG06', 'Agencia Villagarzón',      'Villagarzón'),
    ('a0000000-0000-4000-8000-000000000007', 'AG07', 'Agencia Puerto Leguízamo', 'Puerto Leguízamo'),
    ('a0000000-0000-4000-8000-000000000008', 'AG08', 'Agencia Puerto Caicedo',   'Puerto Caicedo');

INSERT INTO servicio (id, codigo, nombre, prefijo_turno) VALUES
    ('b0000000-0000-4000-8000-000000000001', 'CAJA', 'Caja',                 'C'),
    ('b0000000-0000-4000-8000-000000000002', 'CRED', 'Créditos',             'R'),
    ('b0000000-0000-4000-8000-000000000003', 'AHOR', 'Ahorros y aportes',    'H'),
    ('b0000000-0000-4000-8000-000000000004', 'ATEN', 'Atención al asociado', 'A');

-- Todas las agencias ofrecen los 4 servicios; caja tiene más ventanillas.
INSERT INTO agencia_servicio (agencia_id, servicio_id, ventanillas)
SELECT a.id, s.id,
       CASE s.codigo WHEN 'CAJA' THEN 3 WHEN 'ATEN' THEN 2 ELSE 1 END
FROM agencia a CROSS JOIN servicio s;

-- Parámetros globales (las agencias pueden sobrescribirlos con su agencia_id).
INSERT INTO parametro (clave, agencia_id, valor) VALUES
    ('EDAD_ADULTO_MAYOR',           NULL, '60'),
    ('MAX_PREFERENCIALES_SEGUIDOS', NULL, '2'),
    ('N_PROXIMO',                   NULL, '3'),
    ('T_CONFIRMACION_MIN',          NULL, '5'),
    ('T_LLAMADO_MIN',               NULL, '3'),
    ('HORARIO_APERTURA',            NULL, '08:00'),
    ('HORARIO_CIERRE',              NULL, '16:00');
