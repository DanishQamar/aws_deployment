import os
import boto3
import logging
from flask import Flask, jsonify

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Get the SQS queue URL from an environment variable
# We will set this in the ECS Task Definition
# For this example, we'll fetch the queue name from the `messaging` module.
# A better way is to pass this as an env var in Terraform.
# For simplicity, we'll assume the queue is named 'job-queue'
# as defined in `modules/messaging/main.tf`
SQS_QUEUE_NAME = "job-queue"

# A real app would get the region and queue URL from env vars
# In the `deployment.sh` script, you could add:
# TF_VARS_FILE="terraform.tfvars"
# SQS_QUEUE_URL=$(terraform output -raw sqs_queue_url)
#
# And in `modules/ecs_service/main.tf` in the `container_definitions`:
# "environment" : [
#   { "name" : "SQS_QUEUE_URL", "value" : var.sqs_queue_url }
# ]
#
# For now, we'll discover it using boto3
try:
    sqs = boto3.client("sqs")
    queue_url = sqs.get_queue_url(QueueName=SQS_QUEUE_NAME)["QueueUrl"]
    logger.info(f"Successfully connected to SQS queue: {SQS_QUEUE_NAME}")
except Exception as e:
    logger.error(f"Could not connect to SQS queue '{SQS_QUEUE_NAME}': {e}")
    queue_url = None

@app.route("/")
def health_check():
    """Health check endpoint for the ALB."""
    return "Service 1 is healthy", 200

@app.route("/submit-job", methods=["POST", "GET"])
def submit_job():
    """Simulates submitting a job to SQS."""
    if not queue_url:
        return jsonify({"error": "SQS queue not configured"}), 500
        
    try:
        # Send a message to SQS
        response = sqs.send_message(
            QueueUrl=queue_url,
            MessageBody="This is a test job payload"
        )
        
        logger.info(f"Job submitted to SQS. Message ID: {response.get('MessageId')}")
        return jsonify({
            "message": "Job submitted successfully",
            "message_id": response.get("MessageId")
        }), 200

    except Exception as e:
        logger.error(f"Error submitting job to SQS: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    # For local testing (not used by Gunicorn)
    app.run(host="0.0.0.0", port=8080)