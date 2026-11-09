locals {
  name = "${var.project}-dev"
}

module "budget" {
  source            = "../../modules/budget"
  name              = local.name
  alert_email       = var.alert_email
  monthly_limit_usd = var.monthly_limit_usd
}

module "logging" {
  source          = "../../modules/logging"
  name            = local.name
  alert_topic_arn = module.budget.alert_topic_arn
  force_destroy   = var.lab_mode
}

module "network" {
  source              = "../../modules/network"
  name                = local.name
  cidr                = var.vpc_cidr
  kms_key_arn         = module.logging.kms_key_arn
  interface_endpoints = var.interface_endpoints
}

module "security" {
  source          = "../../modules/security"
  name            = local.name
  log_bucket      = module.logging.bucket_name
  kms_key_arn     = module.logging.kms_key_arn
  alert_topic_arn = module.budget.alert_topic_arn
}
