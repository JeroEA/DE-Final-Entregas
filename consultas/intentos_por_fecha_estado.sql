-- Cantidad de intentos por fecha y estado.
-- Sin filtro de fechas: recorre todo el rango proyectado y solo devuelve
-- fechas que tengan archivos en S3 (inicial: dias 1-2, final: dias 1-3).
SELECT
    fecha,
    estado,
    COUNT(*) AS total_intentos
FROM entregas
GROUP BY fecha, estado
ORDER BY fecha ASC, estado ASC
