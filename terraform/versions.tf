terraform {
  # use_lockfile (S3-native state locking) requires >= 1.10; stable since 1.11
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
