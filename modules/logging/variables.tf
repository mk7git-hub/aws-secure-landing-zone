variable "name" { type = string }
variable "alert_topic_arn" { type = string }

variable "log_retention_days" {
  type    = number
  default = 365
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Allow destroy of a non-empty log bucket (lab teardown only)"
}
