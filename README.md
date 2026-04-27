# Aurora MySQL Production Platform on AWS

This project provisions a production-grade **Amazon Aurora MySQL** database platform on AWS using Terraform. It stands up a multi-AZ Aurora cluster with two writer/reader instances, read-replica autoscaling driven by CloudWatch metrics, CloudWatch alarms wired to SNS for CPU and memory pressure, and a scheduled **AWS Lambda** snapshot pipeline that exports cluster snapshots to a versioned, lifecycle-managed S3 bucket every three hours. It exists to demonstrate end-to-end ownership of a managed relational database stack — deployment, observability, scaling, and backup/DR — expressed entirely as code.

## Highlights

- **Multi-AZ Aurora MySQL cluster** (engine `5.7.mysql_aurora.2.11.5`) with two `db.r5.large` instances split across `ap-northeast-1a` and `ap-northeast-1c`, storage encryption on, and error/general/slowquery logs shipped to CloudWatch.
- **Application Auto Scaling** for read replicas using `TargetTrackingScaling` on `RDSReaderAverageCPUUtilization` (target 70%, min 1 / max 5, 5-minute cooldowns).
- **Automated snapshot Lambda** triggered by an EventBridge rule every 3 hours; snapshots are created via the RDS API, waited on, and the snapshot metadata JSON is written to a versioned S3 bucket with a 150-day lifecycle expiration.
- **CloudWatch alarms + SNS topic** for high CPU (>= 80%) and low freeable memory (<= 1 GB) on the cluster.
- **Supporting Nginx bootstrap script** that registers the EC2 private IP as a `server_name` and installs `/health` and `/elb-status` endpoints — used on the web tier fronting the DB.

## Architecture

Traffic flow and resource relationships:

```
                          +-------------------------+
                          |    EventBridge rule     |
                          |  rate(3 hours)          |
                          +-----------+-------------+
                                      |
                                      v
       +------------------+   +-------+---------+   +--------------------+
       |  CloudWatch      |   |  Lambda         |   |  S3 (versioned)    |
       |  alarms + SNS    |<--+  snapshot       +-->|  aurora-snapshot-  |
       |  (CPU, memory)   |   |  function       |   |  bucket-prod       |
       +---------+--------+   +--------+--------+   +--------------------+
                 ^                     |
                 |                     v
       +---------+---------------------+------------+
       |        Aurora MySQL cluster                |
       |   etc-prod-db (2 writers/readers)    |
       |   SG: aurora-sg   Subnets: 2 private AZs   |
       +---------+----------------------------------+
                 |
                 +--- Auto Scaling target (1-5 read replicas, 70% CPU)
```

The cluster lives inside a pre-existing VPC (`<your-vpc-id>`). A dedicated security group (`aurora-sg`) and DB subnet group (`aurora-subnet-group`) bind it to two private subnets. The Lambda snapshot role has scoped IAM for `rds:CreateDBSnapshot`, `rds:DescribeDBSnapshots`, `rds:StartExportTask`, and `s3:PutObject` against the snapshot bucket only. Alarms publish to a single SNS topic that can be subscribed to Slack/email/PagerDuty out of band.

## Tech stack

- **Terraform** 1.3+ (AWS provider ~> 5.0)
- **AWS services:** RDS Aurora MySQL, Application Auto Scaling, CloudWatch Alarms, CloudWatch Logs, EventBridge, Lambda (Python 3.9), S3, SNS, IAM, VPC/Security Groups, DB Subnet Groups
- **Other:** Python 3.9 (boto3 1.26.137) for snapshot Lambda


## How it works

1. `terraform init && terraform apply` provisions, in order:
   - the Aurora security group, DB subnet group, cluster, and two cluster instances in separate AZs;
   - the Application Auto Scaling target and target-tracking policy for read replicas (1-5 instances based on CPU);
   - the CloudWatch CPU and memory alarms and the shared SNS topic;
   - the S3 snapshot bucket (versioned, 150-day expiration) and the IAM role/policy for the snapshot Lambda;
   - the Lambda function (packaged from `lambda_function.zip` — rebuild from `lambda_function.py`) with a 10-minute timeout;
   - the EventBridge rule (`rate(3 hours)`) and the `lambda:InvokeFunction` permission for EventBridge.
2. Every 3 hours, EventBridge triggers the Lambda, which calls `create_db_cluster_snapshot`, waits for `db_cluster_snapshot_available`, then PUTs the snapshot metadata JSON to `s3://<snapshot-bucket>/snapshots/<cluster-id>-snapshot-<timestamp>.json`.
3. CloudWatch alarms publish to SNS whenever CPU >= 80% or freeable memory <= 1 GB.
4. On the web tier (outside this Terraform), `script.sh` runs at boot to append the EC2 private IP to the Nginx `server_name` and install `/health` and `/elb-status` probe endpoints.

## Prerequisites

- Terraform >= 1.3
- AWS CLI configured (`aws configure`)
- AWS account with permissions for: `rds:*`, `application-autoscaling:*`, `iam:CreateRole`/`CreatePolicy`/`AttachRolePolicy`, `lambda:*`, `events:*`, `s3:*`, `cloudwatch:PutMetricAlarm`, `sns:CreateTopic`, `ec2:*SecurityGroup*`, `ec2:*Subnet*`
- An existing VPC with at least two private subnets in different AZs
- Configured `terraform.tfvars` in `config/` folder (copy from `terraform.tfvars.example`)

## Teardown

```bash
terraform destroy
```

Note: the S3 snapshot bucket is versioned; empty it (`aws s3 rm s3://<bucket> --recursive` plus a version-aware cleanup) before destroy.

## Notes

- Demonstrates: multi-AZ HA, application auto scaling for read replicas, scheduled serverless backup workflows, least-privilege Lambda IAM, and CloudWatch-based alerting.
- All configuration is parameterized via `variables.tf` and `terraform.tfvars` — no hardcoded values in tracked files.
  

