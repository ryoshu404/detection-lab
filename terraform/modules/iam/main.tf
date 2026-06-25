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
