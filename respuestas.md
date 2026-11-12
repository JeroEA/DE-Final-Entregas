# Respuestas conceptuales

## 1. ¿Por qué se pudo consultar el tercer día sin registrar una partición nueva?

Porque la tabla `entregas` no depende de una lista de particiones guardada en Glue,
sino de **reglas de proyección** declaradas en sus propiedades
(`infraestructura/principal.tf`):

```text
projection.enabled              = true
projection.fecha.type           = date
projection.fecha.format         = yyyy-MM-dd
projection.fecha.range          = 2026-10-01,2026-10-03
projection.fecha.interval       = 1
projection.fecha.interval.unit  = DAYS
storage.location.template       = s3://<bucket>/entregas/fecha=${fecha}/
```

Cuando Athena planea una consulta, **calcula en memoria** los valores posibles de
`fecha` (01, 02 y 03 de octubre) y, con la plantilla, la ubicación de cada uno
(`.../entregas/fecha=2026-10-03/`). Luego lee los objetos que encuentra en esos
prefijos. No consulta particiones registradas en el catálogo, así que no hace
falta crawler, `MSCK REPAIR TABLE` ni `ALTER TABLE ADD PARTITION`.

El día 3 ya estaba dentro del rango desde el primer `terraform apply`. En la
etapa inicial ese prefijo estaba vacío, por eso Athena devolvía 12 registros y
ninguna fila para 2026-10-03 (la proyección no exige que existan datos). En
cuanto subí `entregas/fecha=2026-10-03/entregas.csv`, la misma tabla, sin
cambios, devolvió los 6 registros nuevos y 18 en total
(`resultados/final/verificacion_tercer_dia.csv`,
`resultados/final/total_registros_tabla.csv`), y las consultas agregadas
incluyeron el tercer día (`resultados/final/intentos_por_fecha_estado.csv`).
Los identificadores de esas ejecuciones están en
`evidencias/ejecuciones_athena.csv` con etapa `final`.

## 2. Si se subiera un archivo para el 4 de octubre manteniendo la configuración actual, ¿qué resultado se esperaría y qué se debería modificar para incluirlo?

**Resultado esperado:** el archivo quedaría en S3, pero Athena **lo ignoraría**.
El rango proyectado termina en `2026-10-03` (incluido), así que Athena nunca
genera el valor `2026-10-04` ni lee el prefijo `entregas/fecha=2026-10-04/`.
Las consultas seguirían devolviendo 18 registros y tres fechas; un filtro
`WHERE fecha = '2026-10-04'` devolvería cero filas, sin error. Registrar la
partición a mano tampoco serviría: con la proyección habilitada, Athena ignora
las particiones del catálogo para esa tabla.

**Qué modificar:** solo la regla de proyección, no particiones individuales.
Se amplía el final del rango en Terraform y se vuelve a aplicar:

```bash
terraform -chdir=infraestructura apply -var="fecha_fin_proyeccion=2026-10-04"
```

(o cambiando el valor por defecto de `fecha_fin_proyeccion` en
`variables.tf`). Esto actualiza `projection.fecha.range` a
`2026-10-01,2026-10-04`. Para no tener que tocarlo cada día, el rango podría
usar una fecha relativa, por ejemplo `2026-10-01,NOW`, que Athena evalúa en el
momento de la consulta. En ambos casos el archivo nuevo debe respetar la ruta
`entregas/fecha=yyyy-MM-dd/entregas.csv` y el mismo esquema de cinco columnas.
