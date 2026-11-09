# Detective controls: GuardDuty, Security Hub with CIS and AWS Foundational standards,
# AWS Config recording plus a few managed rules, and IAM Access Analyzer.

data "aws_region" "current" {}
data "aws_partition" "p" {}

resource "aws_guardduty_detector" "this" {
  #checkov:skip=CKV2_AWS_3:Single-account lab; org-wide delegation is out of scope (see README roadmap)
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_detector_feature" "s3" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_securityhub_account" "this" {
  enable_default_standards = false
  auto_enable_controls     = true
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:${data.aws_partition.p.partition}:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:${data.aws_partition.p.partition}:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/3.0.0"
  depends_on    = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "nist" {
  count         = var.enable_nist_800_53 ? 1 : 0
  standards_arn = "arn:${data.aws_partition.p.partition}:securityhub:${data.aws_region.current.name}::standards/nist-800-53/v/5.0.0"
  depends_on    = [aws_securityhub_account.this]
}

# AWS Config
data "aws_iam_policy_document" "config_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "${var.name}-config"
  assume_role_policy = data.aws_iam_policy_document.config_trust.json
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${data.aws_partition.p.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "this" {
  name     = "${var.name}-recorder"
  role_arn = aws_iam_role.config.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.name}-delivery"
  s3_bucket_name = var.log_bucket
  s3_key_prefix  = "config"
  s3_kms_key_arn = var.kms_key_arn
  snapshot_delivery_properties { delivery_frequency = "TwentyFour_Hours" }
  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

locals {
  managed_rules = {
    s3-public-read-prohibited = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    s3-sse-enabled            = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    root-mfa                  = "ROOT_ACCOUNT_MFA_ENABLED"
    iam-no-admin-policies     = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS"
    cloudtrail-enabled        = "CLOUD_TRAIL_ENABLED"
    vpc-flow-logs             = "VPC_FLOW_LOGS_ENABLED"
    ebs-encrypted             = "ENCRYPTED_VOLUMES"
    restricted-ssh            = "INCOMING_SSH_DISABLED"
  }
}

resource "aws_config_config_rule" "managed" {
  for_each = local.managed_rules
  name     = "${var.name}-${each.key}"
  source {
    owner             = "AWS"
    source_identifier = each.value
  }
  depends_on = [aws_config_configuration_recorder_status.this]
}

resource "aws_accessanalyzer_analyzer" "this" {
  analyzer_name = "${var.name}-account-analyzer"
  type          = "ACCOUNT"
}

# Account-wide guardrails.
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  password_reuse_prevention      = 24
  max_password_age               = 90
  allow_users_to_change_password = true
}

# High and critical findings go to the alert topic.
resource "aws_cloudwatch_event_rule" "high_findings" {
  name        = "${var.name}-securityhub-high"
  description = "Security Hub HIGH and CRITICAL findings"
  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity    = { Label = ["HIGH", "CRITICAL"] }
        Workflow    = { Status = ["NEW"] }
        RecordState = ["ACTIVE"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "high_findings" {
  rule      = aws_cloudwatch_event_rule.high_findings.name
  target_id = "sns"
  arn       = var.alert_topic_arn
}
