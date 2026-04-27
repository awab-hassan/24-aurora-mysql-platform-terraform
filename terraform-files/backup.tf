resource "aws_s3_bucket" "snapshot_bucket" {
  bucket = "aurora-snapshot-bucket-prod"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "expire_snapshots"
    enabled = true
    expiration {
      days = 150
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "aurora_snapshot_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "aurora_snapshot_policy"
  description = "Policy for RDS snapshots and S3 operations"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "rds:CreateDBSnapshot",
          "rds:DescribeDBSnapshots",
          "rds:DeleteDBSnapshot",
          "rds:StartExportTask",
          "rds:DescribeExportTasks"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action   = ["s3:PutObject", "s3:GetBucketLocation", "s3:ListBucket"],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::aurora-snapshot-bucket-prod",
          "arn:aws:s3:::aurora-snapshot-bucket-prod/*"
        ]
      },
      {
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "aurora_snapshot_lambda" {
  function_name = "aurora_snapshot_lambda"
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "lambda_function.zip"
  timeout       = 600 # Timeout increased to 10 minutes for long-running tasks

  environment {
    variables = {
      S3_BUCKET_NAME = "aurora-snapshot-bucket-prod"
    }
  }

  source_code_hash = filebase64sha256("lambda_function.zip")
}

resource "aws_cloudwatch_event_rule" "every_3_hours" {
  name                = "aurora_snapshot_schedule"
  schedule_expression = "rate(3 hours)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.every_3_hours.name
  target_id = "aurora_snapshot_lambda"
  arn       = aws_lambda_function.aurora_snapshot_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.aurora_snapshot_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_3_hours.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.snapshot_bucket.bucket
}

output "lambda_function_arn" {
  value = aws_lambda_function.aurora_snapshot_lambda.arn
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.every_3_hours.name
}
