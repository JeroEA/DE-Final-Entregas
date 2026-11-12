terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Proyecto = "DE-Final-Entregas"
      Gestion  = "Terraform"
    }
  }
}

locals {
  prefijo_entregas   = "entregas/"
  prefijo_resultados = "resultados-athena/"

  ubicacion_entregas   = "s3://${aws_s3_bucket.datos.bucket}/${local.prefijo_entregas}"
  ubicacion_resultados = "s3://${aws_s3_bucket.datos.bucket}/${local.prefijo_resultados}"
}

# ---------------------------------------------------------------------------
# 1. Bucket S3 privado (datos en entregas/ y resultados en resultados-athena/)
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "datos" {
  bucket = var.nombre_bucket

  # Permite que `terraform destroy` elimine el bucket aunque contenga los CSV
  # y los resultados de Athena.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "datos" {
  bucket = aws_s3_bucket.datos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "datos" {
  bucket = aws_s3_bucket.datos.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datos" {
  bucket = aws_s3_bucket.datos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# 2. Base de datos de Glue Data Catalog
# ---------------------------------------------------------------------------
resource "aws_glue_catalog_database" "entregas" {
  name        = var.nombre_base_datos
  description = "Catalogo de los intentos de entrega de paquetes (examen final)"
}

# ---------------------------------------------------------------------------
# 3. Tabla externa con partition projection sobre la clave `fecha`
# ---------------------------------------------------------------------------
resource "aws_glue_catalog_table" "entregas" {
  name          = var.nombre_tabla
  database_name = aws_glue_catalog_database.entregas.name
  description   = "Intentos de entrega. Particion fecha=yyyy-MM-dd resuelta por partition projection"
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"               = "TRUE"
    "classification"         = "csv"
    "skip.header.line.count" = "1" # omite el encabezado de cada archivo

    # Partition projection: Athena calcula las particiones durante la consulta.
    "projection.enabled"             = "true"
    "projection.fecha.type"          = "date"
    "projection.fecha.format"        = "yyyy-MM-dd"
    "projection.fecha.range"         = "${var.fecha_inicio_proyeccion},${var.fecha_fin_proyeccion}"
    "projection.fecha.interval"      = "1"
    "projection.fecha.interval.unit" = "DAYS"

    # Prefijo de cada particion (termina en /). $${fecha} es literal para Athena.
    "storage.location.template" = "${local.ubicacion_entregas}fecha=$${fecha}/"
  }

  # `fecha` NO es columna de los CSV: sale de la carpeta fecha=yyyy-MM-dd.
  partition_keys {
    name    = "fecha"
    type    = "string"
    comment = "Fecha del archivo diario (yyyy-MM-dd), tomada de la ruta"
  }

  storage_descriptor {
    location      = local.ubicacion_entregas
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "csv-coma"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"

      parameters = {
        "field.delim"          = ","
        "serialization.format" = ","
      }
    }

    # Las cinco columnas del diccionario, en el orden del archivo.
    columns {
      name    = "id_envio"
      type    = "string"
      comment = "Identificador unico del envio"
    }
    columns {
      name    = "ciudad"
      type    = "string"
      comment = "Ciudad del intento de entrega"
    }
    columns {
      name    = "transportadora"
      type    = "string"
      comment = "Transportadora responsable"
    }
    columns {
      name    = "estado"
      type    = "string"
      comment = "entregado | destinatario_ausente | direccion_incorrecta"
    }
    columns {
      name    = "duracion_minutos"
      type    = "int"
      comment = "Minutos; 0 en intentos fallidos"
    }
  }
}

# ---------------------------------------------------------------------------
# 4. Workgroup de Athena con resultados en resultados-athena/
# ---------------------------------------------------------------------------
resource "aws_athena_workgroup" "entregas" {
  name          = var.nombre_workgroup
  description   = "Workgroup del examen final de entregas"
  state         = "ENABLED"
  force_destroy = true # borra el historial de consultas al destruir

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = local.ubicacion_resultados

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
