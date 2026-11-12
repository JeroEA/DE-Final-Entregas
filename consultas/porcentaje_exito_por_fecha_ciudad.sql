-- Porcentaje de entregas exitosas por fecha y ciudad:
-- 100 x entregas exitosas / total de intentos (todos los estados).
-- 100e0 fuerza aritmetica en DOUBLE (evita la division entera) y el CAST a
-- DECIMAL(5,2) redondea y conserva siempre dos decimales.
SELECT
    fecha,
    ciudad,
    CAST(100e0 * COUNT_IF(estado = 'entregado') / COUNT(*) AS DECIMAL(5, 2)) AS porcentaje_exito
FROM entregas
GROUP BY fecha, ciudad
ORDER BY fecha ASC, ciudad ASC
