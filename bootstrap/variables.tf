variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "slz"
}

variable "owner" {
  type        = string
  description = "Tag value for Owner"
}

variable "github_repo" {
  type        = string
  description = "owner/repo allowed to assume the CI role"
}
