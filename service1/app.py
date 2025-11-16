import os
import boto3
import logging
from flask import Flask, jsonify

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Get configuration from environment variables set by Terraform
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
AWS_REGION = os.environ.get("AWS_REGION")

try:
    sqs = boto3.client("sqs", region_name=AWS_REGION)
    logger.info(f"Service 1 configured for SQS queue: {SQS_QUEUE_URL}")
except Exception as e:
    logger.error(f"Could not connect to SQS queue '{SQS_QUEUE_NAME}': {e}")
    SQS_QUEUE_URL = None

@app.route("/")
def health_check():
    """Health check endpoint for the ALB."""
    return "Service 1 is healthy", 200

@app.route("/submit-job", methods=["POST", "GET"])
def submit_job():
    """Simulates submitting a job to SQS."""
    if not SQS_QUEUE_URL:
        return jsonify({"error": "SQS queue not configured"}), 500
        
    try:
        # Send a message to SQS
        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
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