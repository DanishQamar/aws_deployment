import os
import time
import boto3
import signal
import psycopg2
import json
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
DB_CREDENTIALS_SECRET_ARN = os.environ.get("DB_CREDENTIALS_SECRET_ARN")
DB_NAME = os.environ.get("DB_NAME")
DB_HOST = os.environ.get("DB_HOST")

def get_db_credentials():
    """Retrieves database credentials from AWS Secrets Manager."""
    if not DB_CREDENTIALS_SECRET_ARN:
        logger.error("DB_CREDENTIALS_SECRET_ARN environment variable not set.")
        return None

    secrets_client = boto3.client("secretsmanager", region_name=AWS_REGION)
    try:
        response = secrets_client.get_secret_value(SecretId=DB_CREDENTIALS_SECRET_ARN)
        secret = json.loads(response['SecretString'])
        return secret
    except Exception as e:
        logger.error(f"Failed to retrieve database credentials from Secrets Manager: {e}")
        return None

def get_db_connection():
    """Establishes a connection to the PostgreSQL database."""
    credentials = get_db_credentials()
    if not credentials:
        return None
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME,
            user=credentials['username'],
            password=credentials['password'],
            host=DB_HOST
        )
        return conn
    except Exception as e:
        logger.error(f"Could not connect to database: {e}")
        return None

def initialize_db():
    """Creates the jobs table if it doesn't exist."""
    conn = get_db_connection()
    if not conn:
        logger.error("Cannot initialize DB, connection failed.")
        return
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS jobs (
                id VARCHAR(255) PRIMARY KEY,
                description TEXT,
                status VARCHAR(50),
                submitted_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ DEFAULT NOW()
            );
        """)
        conn.commit()
    conn.close()
    logger.info("Database initialized successfully.")

try:
    sqs = boto3.client("sqs", region_name=AWS_REGION)
    logger.info(f"Service 2 configured for SQS queue: {SQS_QUEUE_URL}")
except Exception as e:
    logger.error(f"Could not initialize SQS client: {e}")
    SQS_QUEUE_URL = None

def process_message(message, db_conn):
    """Simulates a long-running job and updates status in the RDS database."""
    logger.info(f"Received job. Message ID: {message['MessageId']}")
    logger.info(f"Job body: {message['Body']}")
    
    # Simulate job processing time (e.g., 5-15 seconds)
    processing_time = 10 
    logger.info(f"Processing job for {processing_time} seconds...")
    
    # Update job status to IN_PROGRESS
    update_job_status(db_conn, message['MessageId'], 'IN_PROGRESS')
    
    time.sleep(processing_time)
    
    # Update job status to COMPLETE
    update_job_status(db_conn, message['MessageId'], 'COMPLETE')
    logger.info(f"Job {message['MessageId']} finished.")

def update_job_status(conn, message_id, status):
    """Updates the status of a job in the database."""
    with conn.cursor() as cur:
        cur.execute("UPDATE jobs SET status = %s, updated_at = NOW() WHERE id = %s", (status, message_id))
        conn.commit()
    logger.info(f"Updated job {message_id} status to {status}")

def main_loop():
    """Continuously polls the SQS queue for messages."""
    if not SQS_QUEUE_URL:
        logger.error("No SQS queue URL found. Worker exiting.")
        return

    logger.info(f"Starting worker. Polling SQS queue: {SQS_QUEUE_URL}")
    
    db_conn = get_db_connection()
    if not db_conn:
        logger.error("Worker cannot start without a database connection.")
        return
    
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
                    process_message(message, db_conn)
                    
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
    
    db_conn.close()
    logger.info("Worker has been shut down gracefully.")

if __name__ == "__main__":
    initialize_db()
    main_loop()