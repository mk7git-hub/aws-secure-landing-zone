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

variable "github_owner_id" {
  type        = number
  description = "Numeric GitHub owner ID (api.github.com/repos/<owner>/<repo> -> owner.id)"
}

variable "github_repo_id" {
  type        = number
  description = "Numeric GitHub repository ID (api.github.com/repos/<owner>/<repo> -> id)"
}
