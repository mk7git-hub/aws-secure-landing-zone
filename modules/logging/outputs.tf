output "kms_key_arn" { value = aws_kms_key.logs.arn }
output "bucket_name" { value = aws_s3_bucket.logs.bucket }
output "trail_arn" { value = aws_cloudtrail.this.arn }
