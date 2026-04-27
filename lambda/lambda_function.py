import boto3
import os
import json
import logging
from datetime import datetime
from typing import Dict, Any

# Configure structured logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS SDK clients with region from environment or default to Tokyo
region = os.getenv('AWS_REGION', 'ap-northeast-1')
rds_client = boto3.client('rds', region_name=region)
s3_client = boto3.client('s3', region_name=region)

# Configuration from environment variables with sensible defaults
S3_BUCKET_NAME = os.getenv('SNAPSHOT_BUCKET_NAME', 'aurora-snapshot-bucket-prod')
DB_CLUSTER_IDENTIFIER = os.getenv('DB_CLUSTER_IDENTIFIER', 'etc-prod-db')


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Create a snapshot of the Aurora DB cluster and store metadata to S3.

    Args:
        event: Lambda event (not used in this scheduled function)
        context: Lambda context

    Returns:
        Dict with statusCode and body containing result or error message
    """
    try:
        # Generate a unique snapshot identifier for the DB cluster with timestamp
        timestamp = datetime.utcnow().strftime('%Y-%m-%d-%H-%M-%S')
        snapshot_identifier = f"{DB_CLUSTER_IDENTIFIER}-snapshot-{timestamp}"

        # Create a snapshot of the Aurora DB cluster
        logger.info(
            f"Creating snapshot for DB Cluster: {DB_CLUSTER_IDENTIFIER} with ID: {snapshot_identifier}"
        )
        rds_client.create_db_cluster_snapshot(
            DBClusterSnapshotIdentifier=snapshot_identifier,
            DBClusterIdentifier=DB_CLUSTER_IDENTIFIER
        )

        # Wait for the snapshot to be available
        logger.info("Waiting for snapshot to be available...")
        waiter = rds_client.get_waiter('db_cluster_snapshot_available')
        waiter.wait(
            DBClusterSnapshotIdentifier=snapshot_identifier
        )
        logger.info(f"Snapshot {snapshot_identifier} is now available.")

        # Retrieve the snapshot details
        snapshot_details = rds_client.describe_db_cluster_snapshots(
            DBClusterSnapshotIdentifier=snapshot_identifier
        )
        snapshot_arn = snapshot_details['DBClusterSnapshots'][0]['DBClusterSnapshotArn']
        logger.info(f"Snapshot ARN: {snapshot_arn}")

        # Store snapshot details in S3
        file_name = f"snapshots/{snapshot_identifier}.json"
        snapshot_json = json.dumps(snapshot_details, default=str)
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=file_name,
            Body=snapshot_json,
            ContentType='application/json'
        )
        logger.info(f"Snapshot details stored in S3: s3://{S3_BUCKET_NAME}/{file_name}")

        return {
            'statusCode': 200,
            'body': f"Snapshot {snapshot_identifier} created and details stored in S3."
        }

    except rds_client.exceptions.DBClusterNotFoundFault as e:
        logger.error(f"DB Cluster not found: {DB_CLUSTER_IDENTIFIER}", exc_info=True)
        return {
            'statusCode': 404,
            'body': f"DB Cluster {DB_CLUSTER_IDENTIFIER} not found: {str(e)}"
        }
    except Exception as e:
        logger.error(f"Unexpected error creating snapshot: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': f"An error occurred: {str(e)}"
        }
