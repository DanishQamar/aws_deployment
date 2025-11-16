import os
import time
import boto3
import signal
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# --- Graceful Shutdown ---
class GracefulKiller:
  kill_now = False
  def __init__(self):
    signal.signal(signal.SIGINT, self.exit_gracefully)
    signal.signal(signal.SIGTERM, self.exit_gracefully)

  def exit_gracefully(self, *args):
    logger.info("Shutdown signal received. Finishing current job, then exiting.")
    self.kill_now = True

# Get configuration from environment variables set by Terraform
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
AWS_REGION = os.environ.get("AWS_REGION")

try:
    sqs = boto3.client("sqs", region_name=AWS_REGION)
    logger.info(f"Service 2 configured for SQS queue: {SQS_QUEUE_URL}")
except Exception as e:
    logger.error(f"Could not initialize SQS client: {e}")
    SQS_QUEUE_URL = None

def process_message(message):
    """
    Simulates a long-running job and communication with the RDS database.
    """
    logger.info(f"Received job. Message ID: {message['MessageId']}")
    logger.info(f"Job body: {message['Body']}")
    
    # Simulate job processing time (e.g., 5-15 seconds)
    processing_time = 10 
    logger.info(f"Processing job for {processing_time} seconds...")
    
    # Simulate writing job status to RDS (as per doc)
    # rds_client = boto3.client('rds-data')
    # rds_client.execute_statement(..., database='appdb', ...)
    logger.info("Simulating write to RDS: 'JOB_IN_PROGRESS'")
    
    time.sleep(processing_time)
    
    logger.info("Simulating write to RDS: 'JOB_COMPLETE'")
    logger.info(f"Job {message['MessageId']} finished.")

def main_loop():
    """Continuously polls the SQS queue for messages."""
    if not SQS_QUEUE_URL:
        logger.error("No SQS queue URL found. Worker exiting.")
        return

    logger.info(f"Starting worker. Polling SQS queue: {SQS_QUEUE_URL}")
    
    killer = GracefulKiller()
    while not killer.kill_now:
        try:
            # Poll SQS for messages
            response = sqs.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=1,  # Process one message at a time
                WaitTimeSeconds=20,     # Use long polling
                MessageAttributeNames=['All']
            )

            if "Messages" in response:
                message = response["Messages"][0]
                receipt_handle = message["ReceiptHandle"]

                # Check for shutdown signal *after* receiving a message but *before* processing it.
                if killer.kill_now:
                    logger.info("Shutdown signal received. Not starting new job. Message will be returned to queue.")
                    break # Exit the loop and allow the application to shut down.

                try:
                    # Process the message
                    process_message(message)
                    
                    # Delete the message from the queue once processed
                    sqs.delete_message(
                        QueueUrl=SQS_QUEUE_URL,
                        ReceiptHandle=receipt_handle
                    )
                    logger.info(f"Deleted message {message['MessageId']} from queue.")
                
                except Exception as e:
                    logger.error(f"Error processing message {message['MessageId']}: {e}")
                    # In a real app, you might let the message visibility timeout
                    # expire so another worker can retry it.
            
            else:
                # When long polling is enabled, a lack of messages is normal.
                # No need to log this every time.
                pass

        except Exception as e:
            logger.error(f"Error polling SQS: {e}")
            time.sleep(10) # Wait before retrying
    logger.info("Worker has been shut down gracefully.")

if __name__ == "__main__":
    main_loop()