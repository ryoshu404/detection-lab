terraform {
  backend "s3" {
    bucket       = "ryoshu404-detection-lab-tfstate"
    key          = "foundation/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
