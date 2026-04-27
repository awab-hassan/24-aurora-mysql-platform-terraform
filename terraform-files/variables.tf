terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "xx-region-1"
}

variable "vpc_id" {
  description = "VPC ID where Aurora cluster will be deployed"
  type        = string
  sensitive   = true
  # Example: "VPC-ID"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group (minimum 2 in different AZs)"
  type        = list(string)
  sensitive   = true
  # Example: ["subnet-xxx", "subnet-xx]
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 subnets in different AZs are required for HA."
  }
}

variable "db_cluster_identifier" {
  description = "Aurora DB cluster identifier"
  type        = string
  default     = "etc-prod-db"
}

variable "db_instance_identifier_1" {
  description = "Aurora DB instance identifier for first instance"
  type        = string
  default     = "etc-prod-db-instance-1"
}

variable "db_instance_identifier_2" {
  description = "Aurora DB instance identifier for second instance"
  type        = string
  default     = "etc-prod-db-instance-2"
}

variable "db_master_username" {
  description = "Master username for Aurora cluster"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "db_master_password" {
  description = "Master password for Aurora cluster (use AWS Secrets Manager in production)"
  type        = string
  sensitive   = true
  # IMPORTANT: Never commit actual passwords. Use terraform.tfvars (in .gitignore)
  # or AWS Secrets Manager / SSM Parameter Store
  validation {
    condition     = length(var.db_master_password) >= 8
    error_message = "Database password must be at least 8 characters."
  }
}

variable "db_engine_version" {
  description = "Aurora MySQL engine version"
  type        = string
  default     = "5.7.mysql_aurora.2.11.5"
}

variable "db_instance_class" {
  description = "Instance class for Aurora cluster instances"
  type        = string
  default     = "db.r5.large"
}

variable "database_name" {
  description = "Initial database name"
  type        = string
  default     = "etc_db"
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "preferred_backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "04:00-04:30"
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "Mon:06:00-Mon:06:30"
}

variable "snapshot_bucket_name" {
  description = "S3 bucket name for Aurora snapshots"
  type        = string
  default     = "aurora-snapshot-bucket-prod"
}

variable "snapshot_retention_days" {
  description = "Number of days to retain snapshots in S3"
  type        = number
  default     = 150
}

variable "lambda_timeout_seconds" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 600 # 10 minutes
  validation {
    condition     = var.lambda_timeout_seconds >= 60 && var.lambda_timeout_seconds <= 900
    error_message = "Lambda timeout must be between 60 and 900 seconds."
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "Aurora-Implementation"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
