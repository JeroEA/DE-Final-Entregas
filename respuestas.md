## Respuestas conceptuales

### 1. ¿Por qué se pudo consultar el tercer día sin registrar una partición nueva?

Porque la tabla "entregas" ya tenía una configuración que le permitía reconocer automáticamente las fechas, sin necesidad de agregarlas manualmente.

Esta configuración está definida en el archivo "infraestructura/principal.tf" y establece un rango de fechas desde el 1 hasta el 3 de octubre de 2026.

Cuando Athena realiza una consulta, revisa ese rango de fechas y busca los archivos en las carpetas correspondientes de Amazon S3. Es decir, sabe dónde buscar la información sin que tengamos que registrar cada fecha manualmente.

Al principio, la carpeta del 3 de octubre estaba vacía, por eso Athena solo mostraba 12 registros. Después, cuando subimos el archivo "entregas.csv" correspondiente a ese día, Athena pudo encontrarlo automáticamente.

Así, la tabla pasó de tener 12 a 18 registros, sin necesidad de modificar su configuración ni crear nuevas particiones.

### 2. Si se subiera un archivo para el 4 de octubre manteniendo la configuración actual, ¿qué resultado se esperaría y qué se debería modificar para incluirlo?

Resultado esperado:

Si subimos un archivo correspondiente al 4 de octubre, Athena no lo tendría en cuenta, aunque el archivo esté guardado correctamente en Amazon S3.

Esto sucede porque la configuración actual solo permite buscar información entre el 1 y el 3 de octubre. Por lo tanto, Athena no buscaría la carpeta del día 4.

Como resultado, las consultas seguirían mostrando los mismos 18 registros y las mismas tres fechas. Si buscamos específicamente información del 4 de octubre, no aparecerían resultados.

¿Qué se debe modificar?

Se debe ampliar el rango de fechas permitido en la configuración de Terraform, para que también incluya el 4 de octubre.

Esto se puede hacer ejecutando el siguiente comando:

```
terraform -chdir=infraestructura apply -var="fecha_fin_proyeccion=2026-10-04"
```

Con este cambio, Athena podrá reconocer las carpetas desde el 1 hasta el 4 de octubre.

Otra opción sería configurar un rango que se actualice automáticamente con la fecha actual, evitando tener que modificarlo cada vez que se agregue un nuevo día.

En ambos casos, es importante que los archivos mantengan la misma organización de carpetas y el mismo formato de información que los anteriores.