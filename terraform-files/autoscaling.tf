# Enable Aurora Auto Scaling
resource "aws_appautoscaling_target" "aurora_auto_scaling" {
  service_namespace = "rds"
  resource_id       = "cluster:etc-prod-db"
  scalable_dimension = "rds:cluster:ReadReplicaCount"

  min_capacity = 1  # Minimum number of replicas
  max_capacity = 5  # Maximum number of replicas
}

# Define a scaling policy based on CPU utilization
resource "aws_appautoscaling_policy" "aurora_scaling_policy" {
  name               = "aurora-scaling-policy"
  service_namespace  = aws_appautoscaling_target.aurora_auto_scaling.service_namespace
  resource_id        = aws_appautoscaling_target.aurora_auto_scaling.resource_id
  scalable_dimension = aws_appautoscaling_target.aurora_auto_scaling.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0  # Scale when average CPU usage exceeds 70%
    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageCPUUtilization"
    }
    scale_in_cooldown  = 300  # 5 minutes cooldown
    scale_out_cooldown = 300  # 5 minutes cooldown
  }
}
