variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "slz"
}

variable "owner" { type = string }

variable "repo" {
  type    = string
  default = "aws-secure-landing-zone"
}

variable "alert_email" { type = string }

variable "monthly_limit_usd" {
  type    = number
  default = 10
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "interface_endpoints" {
  type    = bool
  default = false
}

variable "lab_mode" {
  type        = bool
  default     = true
  description = "true lets terraform destroy remove the non-empty log bucket"
}
