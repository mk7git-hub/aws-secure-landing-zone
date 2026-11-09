output "state_bucket" { value = aws_s3_bucket.state.bucket }
output "lock_table" { value = aws_dynamodb_table.lock.name }
output "state_kms_key" { value = aws_kms_key.state.arn }
output "ci_role_arn" {
  value       = aws_iam_role.ci.arn
  description = "Save as the AWS_ROLE_ARN repository variable in GitHub"
}
