module "networking" {
  source      = "./modules/networking"
  environment = var.environment
}

module "storage" {
  source        = "./modules/storage"
  environment   = var.environment
  aws_region    = var.aws_region
  force_destroy = var.force_destroy
}

module "iam" {
  source      = "./modules/iam"
  environment = var.environment
  log_bucket_arns = [
    module.storage.cloudtrail_bucket_arn,
    module.storage.flowlogs_bucket_arn,
  ]
}

module "detection" {
  source                 = "./modules/detection"
  environment            = var.environment
  vpc_id                 = module.networking.vpc_id
  cloudtrail_bucket_name = module.storage.cloudtrail_bucket_name
  cloudtrail_bucket_arn  = module.storage.cloudtrail_bucket_arn
  flowlogs_bucket_arn    = module.storage.flowlogs_bucket_arn

  # CloudTrail and Flow Logs validate bucket write access at creation, so the
  # bucket policies (in storage/) must exist first.
  depends_on = [module.storage]
}
