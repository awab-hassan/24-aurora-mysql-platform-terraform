# =====================================================================
# Terraform Outputs
# =====================================================================

output "aurora_cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint (load balanced across replicas)"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_cluster_identifier" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.aurora.cluster_identifier
}

output "aurora_cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.aurora.arn
}

output "aurora_instance_1_endpoint" {
  description = "Aurora instance 1 endpoint"
  value       = aws_rds_cluster_instance.aurora_instance_1.endpoint
}

output "aurora_instance_2_endpoint" {
  description = "Aurora instance 2 endpoint"
  value       = aws_rds_cluster_instance.aurora_instance_2.endpoint
}

output "db_security_group_id" {
  description = "Security group ID for Aurora cluster"
  value       = aws_security_group.aurora_sg.id
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.aurora_subnet_group.name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = aws_sns_topic.sns_alerts.arn
}

output "sns_topic_name" {
  description = "SNS topic name for subscriptions"
  value       = aws_sns_topic.sns_alerts.name
}

output "high_cpu_alarm_name" {
  description = "High CPU alarm name"
  value       = aws_cloudwatch_metric_alarm.high_cpu_alarm.alarm_name
}

output "low_memory_alarm_name" {
  description = "Low memory alarm name"
  value       = aws_cloudwatch_metric_alarm.low_memory_alarm.alarm_name
}
