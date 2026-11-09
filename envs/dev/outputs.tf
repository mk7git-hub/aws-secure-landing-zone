output "vpc_id" { value = module.network.vpc_id }
output "private_subnet_ids" { value = module.network.private_subnet_ids }
output "audit_bucket" { value = module.logging.bucket_name }
output "cloudtrail_arn" { value = module.logging.trail_arn }
output "guardduty_detector_id" { value = module.security.guardduty_detector_id }
