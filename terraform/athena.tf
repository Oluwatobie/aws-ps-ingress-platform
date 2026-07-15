# 1. Create a Glue Catalog Database to hold our analytics tables
resource "aws_glue_catalog_database" "ingress_db" {
  name = "ps_ingress_analytics"
}

# 2. Create the Athena/Glue Table Mapping the JSON schema
resource "aws_glue_catalog_table" "ingress_table" {
  name          = "records"
  database_name = aws_glue_catalog_database.ingress_db.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification"            = "json"
    "projection.enabled"        = "true"
    "projection.year.type"      = "integer"
    "projection.year.range"     = "2025,2030"
    "projection.month.type"     = "integer"
    "projection.month.range"    = "1,12"
    "projection.month.digits"   = "2"
    "projection.day.type"       = "integer"
    "projection.day.range"      = "1,31"
    "projection.day.digits"     = "2"
    "storage.location.template" = "s3://${aws_s3_bucket.data_lake.bucket}/records/year=$${year}/month=$${month}/day=$${day}"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.bucket}/records/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "record_id"
      type = "string"
    }
    columns {
      name = "clearance"
      type = "string"
    }
    columns {
      name = "payload"
      type = "string"
    }
  }

  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
}

# 3. Provision a dedicated Athena Workgroup for QuickSight Queries
resource "aws_athena_workgroup" "quicksight_workgroup" {
  name = "ps-quicksight-analytics-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.id}/athena-query-results/"
    }
  }
}