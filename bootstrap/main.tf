# One-time bootstrap: remote state bucket, lock table, and the GitHub OIDC role.
# Run locally once with admin credentials, then CI takes over with short-lived tokens.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.70" }
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = local.tags }
}

data "aws_caller_identity" "me" {}

locals {
  tags       = { Project = var.project, Owner = var.owner, ManagedBy = "terraform", Environment = "bootstrap" }
  state_name = "${var.project}-tfstate-${data.aws_caller_identity.me.account_id}"
  # Since July 2026 GitHub puts immutable IDs in the OIDC subject for new repos:
  # repo:<owner>@<owner_id>/<repo>@<repo_id>:<context>. IDs stop a deleted-and-recreated
  # repo with the same name from inheriting this trust.
  gh_owner = split("/", var.github_repo)[0]
  gh_name  = split("/", var.github_repo)[1]
  gh_sub   = "repo:${local.gh_owner}@${var.github_owner_id}/${local.gh_name}@${var.github_repo_id}"
}

resource "aws_kms_key" "state" {
  description             = "Encrypts Terraform state"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AccountAdmin"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.me.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
  #checkov:skip=CKV_AWS_111:Standard AWS key policy; access is delegated to IAM
  #checkov:skip=CKV_AWS_109:Standard AWS key policy; access is delegated to IAM
  #checkov:skip=CKV_AWS_356:Key policies always use Resource "*" (the key itself)
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_s3_bucket" "state" {
  bucket        = local.state_name
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "state_tls" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_dynamodb_table" "lock" {
  name         = "${var.project}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.state.arn
  }
}

# GitHub Actions OIDC: no long-lived AWS keys anywhere.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only this repo, and only main or pull requests, can assume the role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.gh_sub}:ref:refs/heads/main",
        "${local.gh_sub}:pull_request",
        "${local.gh_sub}:environment:dev",
      ]
    }
  }
}

resource "aws_iam_role" "ci" {
  name                 = "${var.project}-github-ci"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
  permissions_boundary = aws_iam_policy.boundary.arn
}

# Boundary: CI can never create IAM users/keys or disable logging, whatever policy it gets.
resource "aws_iam_policy" "boundary" {
  #checkov:skip=CKV_AWS_62:Permissions boundary; the Allow * is the ceiling, the Deny list is the control
  #checkov:skip=CKV_AWS_63:Permissions boundary ceiling, grants nothing on its own
  #checkov:skip=CKV_AWS_286:Permissions boundary ceiling, grants nothing on its own
  #checkov:skip=CKV_AWS_287:Permissions boundary ceiling, grants nothing on its own
  #checkov:skip=CKV_AWS_288:Permissions boundary ceiling, grants nothing on its own
  #checkov:skip=CKV_AWS_289:Permissions boundary ceiling, grants nothing on its own
  #checkov:skip=CKV_AWS_290:Permissions boundary ceiling, grants nothing on its own
  #checkov:skip=CKV_AWS_355:Permissions boundary ceiling, grants nothing on its own
  #checkov:skip=CKV2_AWS_40:Permissions boundary ceiling, grants nothing on its own
  name = "${var.project}-ci-boundary"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "AllowWithinBoundary", Effect = "Allow", Action = "*", Resource = "*" },
      {
        Sid    = "DenyDangerous"
        Effect = "Deny"
        Action = [
          "iam:CreateUser", "iam:CreateAccessKey", "iam:CreateLoginProfile",
          "cloudtrail:StopLogging", "cloudtrail:DeleteTrail",
          "guardduty:DeleteDetector", "organizations:*", "account:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Scoped to the services this repo manages. Tighten further with IAM Access Analyzer policy generation after the first apply.
resource "aws_iam_role_policy" "ci" {
  name = "landing-zone-deploy"
  role = aws_iam_role.ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "State"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
        Resource = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*", aws_dynamodb_table.lock.arn, aws_kms_key.state.arn]
      },
      {
        Sid    = "ManagedServices"
        Effect = "Allow"
        Action = [
          "ec2:*", "logs:*", "cloudtrail:*", "s3:*", "kms:*", "guardduty:*", "securityhub:*",
          "config:*", "access-analyzer:*", "budgets:*", "sns:*", "iam:GetRole", "iam:PassRole",
          "iam:CreateRole", "iam:DeleteRole", "iam:TagRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole", "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
      }
    ]
  })
}
