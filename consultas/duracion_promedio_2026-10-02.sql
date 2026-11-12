-- Duracion promedio de las entregas EXITOSAS del 2026-10-02
-- (todas las ciudades y transportadoras; los fallidos con 0 minutos se excluyen).
SELECT
    fecha,
    CAST(AVG(duracion_minutos) AS DECIMAL(10, 2)) AS duracion_promedio_minutos
FROM entregas
WHERE fecha = '2026-10-02'
  AND estado = 'entregado'
GROUP BY fecha
