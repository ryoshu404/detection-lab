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
  cloudtrail_sqs_queue_arn = module.detection.cloudtrail_sqs_queue_arn
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

module "siem" {
  source                = "./modules/siem"
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  vpc_cidr_block        = module.networking.vpc_cidr_block
  private_subnet_id     = module.networking.private_subnet_ids[0]
  instance_profile_name = module.iam.elastic_instance_profile_name
  instance_type         = "t3.large"
}
