variable "name" { type = string }
variable "alert_email" { type = string }

variable "monthly_limit_usd" {
  type    = number
  default = 10
}
