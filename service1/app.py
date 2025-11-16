import os
import boto3
import logging
import psycopg2
import json
from flask import Flask, jsonify, render_template, request

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__, template_folder='./templates')

# Get configuration from environment variables set by Terraform
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
AWS_REGION = os.environ.get("AWS_REGION")

# Database connection details from environment variables
DB_NAME = os.environ.get("DB_NAME")
DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")
DB_HOST = os.environ.get("DB_HOST")

def get_db_connection():
    """Establishes a connection to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST
        )
        return conn
    except Exception as e:
        logger.error(f"Could not connect to database: {e}")
        return None

try:
    sqs = boto3.client("sqs", region_name=AWS_REGION)
    logger.info(f"Service 1 configured for SQS queue: {SQS_QUEUE_URL}")
except Exception as e:
    logger.error(f"Could not connect to SQS queue: {e}")
    SQS_QUEUE_URL = None

@app.route("/")
def index():
    """Serves the main UI page."""
    return render_template("index.html")

@app.route("/health")
def health_check():
    """Health check for ALB"""
    return "OK", 200

@app.route("/submit-job", methods=["POST"])
def submit_job():
    """Simulates submitting a job to SQS."""
    if not SQS_QUEUE_URL:
        return jsonify({"error": "SQS queue not configured"}), 500
        
    try:
        # Send a message to SQS
        job_description = request.json.get("description", "No description")

        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps({"description": job_description})
        )
        message_id = response.get('MessageId')
        logger.info(f"Job submitted to SQS. Message ID: {message_id}")
        
        # Log the job submission to the database
        conn = get_db_connection()
        if conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO jobs (id, description, status) VALUES (%s, %s, %s)",
                    (message_id, job_description, 'SUBMITTED')
                )
                conn.commit()
            conn.close()

        return jsonify({
            "message": "Job submitted successfully",
            "message_id": message_id
        }), 200

    except Exception as e:
        logger.error(f"Error submitting job to SQS: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/jobs", methods=["GET"])
def get_jobs():
    """Fetches all jobs from the database."""
    conn = get_db_connection()
    if not conn:
        return jsonify({"error": "Database connection failed"}), 500
    
    jobs = []
    with conn.cursor() as cur:
        cur.execute("SELECT id, description, status, submitted_at FROM jobs ORDER BY submitted_at DESC")
        rows = cur.fetchall()
        for row in rows:
            jobs.append({
                "id": row[0],
                "description": row[1],
                "status": row[2],
                "submitted_at": row[3].isoformat()
            })
    conn.close()
    return jsonify(jobs)

if __name__ == "__main__":
    # For local testing (not used by Gunicorn)
    app.run(host="0.0.0.0", port=8080)