variable "name" { type = string }
variable "log_bucket" { type = string }
variable "kms_key_arn" { type = string }
variable "alert_topic_arn" { type = string }

variable "enable_nist_800_53" {
  type        = bool
  default     = true
  description = "Subscribe Security Hub to NIST SP 800-53 Rev 5 (maps to CMMC and 800-171 work)"
}
