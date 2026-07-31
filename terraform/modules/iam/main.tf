# Trust policy: only the EC2 service can assume this role (it's an instance role).
data "aws_iam_policy_document" "elastic_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "elastic_instance" {
  name               = "${var.environment}-elastic-instance"
  assume_role_policy = data.aws_iam_policy_document.elastic_assume.json
}

# SSM Session Manager access — how we reach the instance without SSH or a public IP.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.elastic_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 read so Filebeat can pull logs from the telemetry buckets. ListBucket on the
# buckets, GetObject on their objects — split so each action sits on its right resource.
data "aws_iam_policy_document" "s3_log_read" {
  statement {
    sid       = "ListLogBuckets"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = var.log_bucket_arns
  }

  statement {
    sid       = "ReadLogObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [for arn in var.log_bucket_arns : "${arn}/*"]
  }
}

# Managed + named, not inline, per the IAM baseline.
resource "aws_iam_policy" "s3_log_read" {
  name   = "${var.environment}-elastic-s3-log-read"
  policy = data.aws_iam_policy_document.s3_log_read.json
}

resource "aws_iam_role_policy_attachment" "s3_log_read" {
  role       = aws_iam_role.elastic_instance.name
  policy_arn = aws_iam_policy.s3_log_read.arn
}

# EC2 attaches a role via an instance profile, not the role directly.
resource "aws_iam_instance_profile" "elastic_instance" {
  name = "${var.environment}-elastic-instance"
  role = aws_iam_role.elastic_instance.name
}

# Local Filebeat (Proxmox VM) reads CloudTrail from S3/SQS using static keys
# instead of an instance role, since it's off-AWS. Reuses the same scoped
# s3_log_read + sqs_read policies the EC2 instance role used.
resource "aws_iam_user" "filebeat_local" {
  name = "filebeat-local-${var.environment}"
}

resource "aws_iam_user_policy_attachment" "filebeat_s3_log_read" {
  user       = aws_iam_user.filebeat_local.name
  policy_arn = aws_iam_policy.s3_log_read.arn
}

resource "aws_iam_user_policy_attachment" "filebeat_sqs_read" {
  user       = aws_iam_user.filebeat_local.name
  policy_arn = aws_iam_policy.sqs_read.arn
}

resource "aws_iam_access_key" "filebeat_local" {
  user = aws_iam_user.filebeat_local.name
}

data "aws_iam_policy_document" "sqs_read" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [var.cloudtrail_sqs_queue_arn]
  }
}

resource "aws_iam_policy" "sqs_read" {
  name        = "elastic-cloudtrail-sqs-read-${var.environment}"
  description = "Filebeat: receive/delete CloudTrail notification messages"
  policy      = data.aws_iam_policy_document.sqs_read.json
}

resource "aws_iam_role_policy_attachment" "sqs_read" {
  role       = aws_iam_role.elastic_instance.name
  policy_arn = aws_iam_policy.sqs_read.arn
}

# GuardDuty API read so the Elastic Agent can pull findings directly,
# rather than via S3/SQS — no notification queue exists on the findings bucket.
data "aws_iam_policy_document" "guardduty_read" {
  statement {
    sid       = "ListDetectors"
    effect    = "Allow"
    actions   = ["guardduty:ListDetectors"]
    resources = ["*"]
  }

  statement {
    sid    = "ReadFindings"
    effect = "Allow"
    actions = [
      "guardduty:ListFindings",
      "guardduty:GetFindings",
    ]
    resources = [
      var.guardduty_detector_arn,
      "${var.guardduty_detector_arn}/*",
    ]
  }
}

resource "aws_iam_policy" "guardduty_read" {
  name        = "elastic-guardduty-read-${var.environment}"
  description = "Elastic Agent: list and fetch GuardDuty findings via API"
  policy      = data.aws_iam_policy_document.guardduty_read.json
}

resource "aws_iam_user_policy_attachment" "filebeat_guardduty_read" {
  user       = aws_iam_user.filebeat_local.name
  policy_arn = aws_iam_policy.guardduty_read.arn
}
