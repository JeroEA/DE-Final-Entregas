variable "region" {
  description = "Region de AWS donde se despliegan todos los recursos"
  type        = string
  default     = "us-east-1"
}

variable "nombre_bucket" {
  description = "Nombre globalmente unico del bucket S3 privado del ejercicio"
  type        = string
  default     = "de-final-entregas-jeroespinal-2026"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.nombre_bucket))
    error_message = "El nombre del bucket debe tener 3-63 caracteres en minusculas, numeros, puntos o guiones."
  }
}

variable "nombre_base_datos" {
  description = "Nombre de la base de datos de Glue Data Catalog"
  type        = string
  default     = "entregas_db"
}

variable "nombre_tabla" {
  description = "Nombre de la tabla externa de entregas"
  type        = string
  default     = "entregas"
}

variable "nombre_workgroup" {
  description = "Nombre del workgroup de Athena"
  type        = string
  default     = "entregas_wg"
}

variable "fecha_inicio_proyeccion" {
  description = "Primera fecha (incluida) del rango de partition projection, formato yyyy-MM-dd"
  type        = string
  default     = "2026-10-01"
}

variable "fecha_fin_proyeccion" {
  description = "Ultima fecha (incluida) del rango de partition projection, formato yyyy-MM-dd"
  type        = string
  default     = "2026-10-03"
}
