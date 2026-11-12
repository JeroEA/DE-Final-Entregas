output "region" {
  description = "Region del despliegue"
  value       = var.region
}

output "bucket" {
  description = "Nombre del bucket S3 del ejercicio"
  value       = aws_s3_bucket.datos.bucket
}

output "bucket_arn" {
  description = "ARN del bucket S3"
  value       = aws_s3_bucket.datos.arn
}

output "ubicacion_entregas" {
  description = "Prefijo S3 de los datos (raiz de la tabla)"
  value       = local.ubicacion_entregas
}

output "ubicacion_resultados_athena" {
  description = "Prefijo S3 donde Athena escribe los resultados"
  value       = local.ubicacion_resultados
}

output "base_datos" {
  description = "Base de datos de Glue Data Catalog"
  value       = aws_glue_catalog_database.entregas.name
}

output "tabla" {
  description = "Tabla externa con partition projection"
  value       = aws_glue_catalog_table.entregas.name
}

output "tabla_arn" {
  description = "ARN de la tabla en Glue"
  value       = aws_glue_catalog_table.entregas.arn
}

output "workgroup" {
  description = "Workgroup de Athena para ejecutar las consultas"
  value       = aws_athena_workgroup.entregas.name
}

output "rango_proyeccion" {
  description = "Rango de fechas proyectado (ambos extremos incluidos)"
  value       = aws_glue_catalog_table.entregas.parameters["projection.fecha.range"]
}
