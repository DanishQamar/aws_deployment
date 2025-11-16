# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory
WORKDIR /app

# Copy the dependencies file and install them
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY app.py .

# Expose port 8080 (as specified in the terraform module)
EXPOSE 8080

# Run the Flask app
# Gunicorn is a production-ready server
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]