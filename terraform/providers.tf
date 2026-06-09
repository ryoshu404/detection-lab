provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "detection-lab"
      ManagedBy = "terraform"
    }
  }
}
