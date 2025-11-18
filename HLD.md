High-Level Design (HLD): AWS Cloud-Native Job Processing System
1. Executive Summary
This document outlines the architecture for a scalable, event-driven web application deployed on AWS. The system allows users to submit jobs via a web UI, which are then processed asynchronously by background workers. The solution leverages "serverless container" technologies (AWS Fargate) to minimize operational overhead and optimize costs through demand-based auto-scaling.

2. Solution Architecture
The following diagram illustrates the high-level interaction between AWS services, network zones, and application components.

2.1. Architectural Flow
The data flow operates as follows:

Frontend Delivery: Users access the application via Amazon CloudFront, which serves static assets (HTML, CSS, JS) stored in Amazon S3.

API Ingestion: API requests (e.g., /submit-job) are routed by the Application Load Balancer (ALB) to Service 1.

Job Enqueueing: Service 1 (REST API) persists the job status to the database and pushes a message containing the job ID to an Amazon SQS queue.

Asynchronous Processing: Service 2 (Worker) polls the SQS queue. When a message is received, it retrieves the job details from the database, simulates processing (sleeping), and updates the status to COMPLETED or FAILED.

Data Persistence: Both services read/write shared state to a central Amazon RDS (PostgreSQL) database.

Auto-Scaling: Amazon CloudWatch monitors the SQS queue depth. If the backlog increases, Application Auto Scaling triggers the launch of additional Service 2 tasks to handle the load.

3. Detailed Component Design
3.1. Networking & Security (VPC)
The infrastructure is deployed within a custom Amazon VPC spanning two Availability Zones for high availability.

Public Subnets: Host the NAT Gateways and Application Load Balancer (ALB).

Private Subnets: Host the ECS Tasks (Service 1 & 2) to ensure they are not directly addressable from the internet.

Database Subnets: Host the RDS instance, isolated with restricted Security Groups.

Security Groups enforce a strict "need-to-know" traffic flow:

ALB SG: Allows inbound HTTP (80) from CloudFront prefix lists.

ECS SG: Allows inbound TCP (8080) only from the ALB SG.

DB SG: Allows inbound TCP (5432) only from the ECS SG.

3.2. Compute: AWS ECS Fargate
The application runs on Amazon ECS using the Fargate launch type, removing the need to manage EC2 instances.

Service 1 (API): A Spring Boot web application exposing REST endpoints. It is fronted by an ALB and handles user traffic.

Service 2 (Worker): A Spring Boot worker application. It does not have a public port but runs as a daemon task, listening to SQS.

Graceful Shutdown: Tasks are configured with a stopTimeout of 120 seconds, allowing workers to finish processing active jobs before termination during scale-in events.

3.3. Data & State Management
Database: A centralized PostgreSQL 15 database on Amazon RDS. Credentials are managed securely via AWS Secrets Manager and injected into containers at runtime, avoiding hardcoded secrets.

Messaging: Amazon SQS is used to decouple the API from the Worker. This ensures that if the Worker service is down or under heavy load, incoming jobs are buffered rather than lost.

3.4. Auto-Scaling Strategy
The system utilizes Target Tracking Scaling based on the SQS metric ApproximateNumberOfMessagesVisible.

Scaling Metric: Target of 5 messages per task.

Behavior:

If the queue has >5 visible messages per worker, ECS adds tasks (up to max_capacity).

If the queue empties, ECS removes tasks (down to min_capacity), optimizing costs.

Manual Override: Service 1 exposes a specialized endpoint (/update-scaling) allowing administrators to dynamically adjust the min/max capacity of Service 2 via API.

4. Deployment & Automation
4.1. Infrastructure as Code (Terraform)
The entire environment is provisioned via Terraform, organized into modular components for reusability:

modules/vpc: Networking foundation.

modules/ecs_service: Reusable module for deploying both API and Worker services, conditionally creating ALBs and Scaling Policies based on input variables.

modules/database: RDS and Secrets Manager configuration.

modules/frontend: S3 and CloudFront setup.

4.2. Build & Release
Containerization: Applications are packaged using Docker (OpenJDK 17).

Registry: Images are stored in Amazon ECR.

Deployment Script: A deployment.sh script automates the workflow:

terraform apply to provision infrastructure.

Docker build and push to ECR.

aws ecs update-service to force a new deployment with the latest images.

5. Resilience & Observability
Health Checks: The ALB performs health checks on the /health endpoint. A grace period of 60 seconds is configured to allow Spring Boot ample time to initialize before traffic is routed.

Logging: Application logs are streamed directly to Amazon CloudWatch Logs (/ecs/main-cluster) for analysis and debugging.

Availability: The RDS instance and ECS services utilize multiple subnets, ensuring the application survives the loss of a single Availability Zone.
