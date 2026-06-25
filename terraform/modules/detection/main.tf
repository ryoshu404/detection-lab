# Multi-region trail with log file validation. Management events plus S3 data events.
resource "aws_cloudtrail" "this" {
  name                       = "${var.environment}-trail"
  s3_bucket_name             = var.cloudtrail_bucket_name
  is_multi_region_trail      = var.multi_region_trail
  enable_log_file_validation = true

  advanced_event_selector {
    name = "Management events"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  # S3 data events, excluding the trail's own log bucket — otherwise each log write
  # generates a data event that gets logged, which is another write, and so on.
  dynamic "advanced_event_selector" {
    for_each = var.enable_s3_data_events ? [1] : []
    content {
      name = "S3 data events"

      field_selector {
        field  = "eventCategory"
        equals = ["Data"]
      }
      field_selector {
        field  = "resources.type"
        equals = ["AWS::S3::Object"]
      }
      field_selector {
        field           = "resources.ARN"
        not_starts_with = ["${var.cloudtrail_bucket_arn}/"]
      }
    }
  }
}

# VPC Flow Logs to S3. No IAM role needed for S3 delivery — the bucket policy (storage/)
# grants the delivery.logs.amazonaws.com service principal directly.
resource "aws_flow_log" "this" {
  log_destination_type = "s3"
  log_destination      = var.flowlogs_bucket_arn
  traffic_type         = "ALL"
  vpc_id               = var.vpc_id

  tags = {
    Name = "${var.environment}-vpc-flowlog"
  }
}

# GuardDuty detector. FIFTEEN_MINUTES publishing (vs the 6-hour default) so findings
# surface quickly during detection testing. Findings export to S3 is wired at T9 with
# the Elastic ingestion path (it needs a KMS key, which is deferred until then).
resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    Name = "${var.environment}-guardduty"
  }
}

# S3 Protection: analyzes S3 data events for threats. Managed as a feature resource;
# the old datasources block on the detector is deprecated.
resource "aws_guardduty_detector_feature" "s3" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

data "aws_caller_identity" "current" {}

resource "aws_sqs_queue" "cloudtrail_notifications" {
  name                       = "cloudtrail-notifications-${var.environment}"
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 300
  sqs_managed_sse_enabled    = true
}

data "aws_iam_policy_document" "cloudtrail_sqs" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.cloudtrail_notifications.arn]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [var.cloudtrail_bucket_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sqs_queue_policy" "cloudtrail_notifications" {
  queue_url = aws_sqs_queue.cloudtrail_notifications.id
  policy    = data.aws_iam_policy_document.cloudtrail_sqs.json
}

resource "aws_s3_bucket_notification" "cloudtrail" {
  bucket = var.cloudtrail_bucket_name
  queue {
    queue_arn     = aws_sqs_queue.cloudtrail_notifications.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "AWSLogs/"
  }
  depends_on = [aws_sqs_queue_policy.cloudtrail_notifications]
}

resource "aws_guardduty_publishing_destination" "s3" {
  detector_id     = aws_guardduty_detector.this.id
  destination_arn = var.guardduty_bucket_arn
  kms_key_arn     = var.guardduty_kms_key_arn
}
