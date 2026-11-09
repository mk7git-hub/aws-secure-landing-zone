variable "name" { type = string }

variable "cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "interface_endpoints" {
  type        = bool
  default     = false
  description = "Create SSM, logs, KMS and STS interface endpoints (adds cost)"
}

variable "kms_key_arn" { type = string }

variable "log_retention_days" {
  type    = number
  default = 365
}
