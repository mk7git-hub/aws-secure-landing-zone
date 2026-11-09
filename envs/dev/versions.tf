terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.70" }
  }
  # Values come from -backend-config in CI (see the workflow) so no account IDs live in Git.
  backend "s3" {
    key     = "landing-zone/dev.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = var.project
      Environment = "dev"
      Owner       = var.owner
      ManagedBy   = "terraform"
      Repo        = var.repo
    }
  }
}
