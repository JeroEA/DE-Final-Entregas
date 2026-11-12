-- Verificacion de la incorporacion del 2026-10-03 sin registrar particiones.
-- Athena ejecuta una sentencia por consulta: el script las separa por ';'
-- y guarda cada resultado en su propio CSV dentro de resultados/final/.

-- 1) Los seis registros del tercer dia -> resultados/final/verificacion_tercer_dia.csv
SELECT
    fecha,
    id_envio,
    ciudad,
    transportadora,
    estado,
    duracion_minutos
FROM entregas
WHERE fecha = '2026-10-03'
ORDER BY id_envio ASC;

-- 2) Conteo de registros y conteos por estado del tercer dia
--    -> resultados/final/conteo_estados_tercer_dia.csv
SELECT
    fecha,
    estado,
    COUNT(*) AS total_intentos
FROM entregas
WHERE fecha = '2026-10-03'
GROUP BY fecha, estado
ORDER BY estado ASC;

-- 3) Registros por fecha -> resultados/final/registros_por_fecha.csv
SELECT
    fecha,
    COUNT(*) AS total_registros
FROM entregas
GROUP BY fecha
ORDER BY fecha ASC;

-- 4) Total de la tabla (debe ser 18) -> resultados/final/total_registros_tabla.csv
SELECT
    COUNT(*) AS total_registros
FROM entregas;
