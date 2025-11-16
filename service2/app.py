import os
import time
import boto3
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# We'll discover the queue URL just like in Service 1
SQS_QUEUE_NAME = "job-queue"

try:
    sqs = boto3.client("sqs")
    queue_url = sqs.get_queue_url(QueueName=SQS_QUEUE_NAME)["QueueUrl"]
    logger.info(f"Successfully connected to SQS queue: {SQS_QUEUE_NAME}")
except Exception as e:
    logger.error(f"Could not connect to SQS queue '{SQS_QUEUE_NAME}': {e}")
    queue_url = None

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
    if not queue_url:
        logger.error("No SQS queue URL found. Worker exiting.")
        return

    logger.info(f"Starting worker. Polling SQS queue: {SQS_QUEUE_NAME}")
    
    while True:
        try:
            # Poll SQS for messages
            response = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=1,  # Process one message at a time
                WaitTimeSeconds=20,     # Use long polling
                MessageAttributeNames=['All']
            )

            if "Messages" in response:
                message = response["Messages"][0]
                receipt_handle = message["ReceiptHandle"]

                try:
                    # Process the message
                    process_message(message)
                    
                    # Delete the message from the queue once processed
                    sqs.delete_message(
                        QueueUrl=queue_url,
                        ReceiptHandle=receipt_handle
                    )
                    logger.info(f"Deleted message {message['MessageId']} from queue.")
                
                except Exception as e:
                    logger.error(f"Error processing message {message['MessageId']}: {e}")
                    # In a real app, you might let the message visibility timeout
                    # expire so another worker can retry it.
            
            else:
                logger.info("No messages in queue. Polling...")

        except Exception as e:
            logger.error(f"Error polling SQS: {e}")
            time.sleep(10) # Wait before retrying

if __name__ == "__main__":
    main_loop()