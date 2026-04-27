provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# =====================================================================
# Security Group for Aurora Cluster
# =====================================================================
resource "aws_security_group" "aurora_sg" {
  name_prefix = "aurora-sg-"
  description = "Aurora Security Group - managed by Terraform"
  vpc_id      = var.vpc_id

  tags = {
    Name = "aurora-sg"
  }
}

# =====================================================================
# Aurora Cluster and Instances
# =====================================================================
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = var.db_cluster_identifier
  engine                  = "aurora-mysql"
  engine_version          = var.db_engine_version
  master_username         = var.db_master_username
  master_password         = var.db_master_password
  database_name           = var.database_name
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  vpc_security_group_ids = [aws_security_group.aurora_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.aurora_subnet_group.name

  storage_encrypted             = true
  skip_final_snapshot          = false
  final_snapshot_identifier    = "${var.db_cluster_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Enable CloudWatch logs for error tracking, slow queries
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = {
    Name = var.db_cluster_identifier
  }
}

# First Aurora cluster instance (writer/reader in first AZ)
resource "aws_rds_cluster_instance" "aurora_instance_1" {
  identifier              = var.db_instance_identifier_1
  cluster_identifier      = aws_rds_cluster.aurora.id
  instance_class          = var.db_instance_class
  engine                  = aws_rds_cluster.aurora.engine
  engine_version          = aws_rds_cluster.aurora.engine_version
  availability_zone       = data.aws_availability_zones.available.names[0]
  performance_insights_enabled = true
  publicly_accessible     = false
  monitoring_interval     = 60
  monitoring_role_arn     = aws_iam_role.rds_monitoring.arn

  tags = {
    Name = var.db_instance_identifier_1
  }
}

# Second Aurora cluster instance (reader in second AZ for HA)
resource "aws_rds_cluster_instance" "aurora_instance_2" {
  identifier              = var.db_instance_identifier_2
  cluster_identifier      = aws_rds_cluster.aurora.id
  instance_class          = var.db_instance_class
  engine                  = aws_rds_cluster.aurora.engine
  engine_version          = aws_rds_cluster.aurora.engine_version
  availability_zone       = data.aws_availability_zones.available.names[1]
  performance_insights_enabled = true
  publicly_accessible     = false
  monitoring_interval     = 60
  monitoring_role_arn     = aws_iam_role.rds_monitoring.arn

  tags = {
    Name = var.db_instance_identifier_2
  }
}

# =====================================================================
# DB Subnet Group
# =====================================================================
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name_prefix = "aurora-subnet-group-"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "aurora-subnet-group"
  }
}

# =====================================================================
# Data sources for AZ information
# =====================================================================
data "aws_availability_zones" "available" {
  state = "available"
}

# =====================================================================
# IAM Role for RDS Enhanced Monitoring
# =====================================================================
resource "aws_iam_role" "rds_monitoring" {
  name_prefix = "rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# =====================================================================
# CloudWatch Alarms for Aurora Monitoring
# =====================================================================
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "aurora-${var.db_cluster_identifier}-high-cpu"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_description   = "Alert when Aurora cluster CPU exceeds 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.cluster_identifier
  }

  alarm_actions = [aws_sns_topic.sns_alerts.arn]

  tags = {
    Name = "aurora-high-cpu-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "low_memory_alarm" {
  alarm_name          = "aurora-${var.db_cluster_identifier}-low-memory"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1000000000  # 1 GB in bytes
  comparison_operator = "LessThanOrEqualToThreshold"
  alarm_description   = "Alert when freeable memory falls below 1 GB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.cluster_identifier
  }

  alarm_actions = [aws_sns_topic.sns_alerts.arn]

  tags = {
    Name = "aurora-low-memory-alarm"
  }
}

# =====================================================================
# SNS Topic for Alarms
# =====================================================================
resource "aws_sns_topic" "sns_alerts" {
  name_prefix = "aurora-alerts-"

  tags = {
    Name = "aurora-alerts"
  }
}

resource "aws_sns_topic_policy" "sns_alerts_policy" {
  arn = aws_sns_topic.sns_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.sns_alerts.arn
      }
    ]
  })
}
