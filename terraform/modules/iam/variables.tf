variable "environment" {
  description = "Deployment environment (lab/dev/prod). Used in resource names."
  type        = string
}

variable "log_bucket_arns" {
  description = "Telemetry bucket ARNs the Elastic instance (Filebeat) reads from."
  type        = list(string)
}

variable "cloudtrail_sqs_queue_arn" {
  description = "CloudTrail notification queue ARN; grants Filebeat SQS receive/delete"
  type        = string
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
