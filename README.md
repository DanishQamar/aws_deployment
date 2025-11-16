# aws_deployment
AWS Cloud Deployment Solution

# ADR-001: Adopt a Serverless Container-based Architecture on AWS

**Status:** Accepted

**Date:** 2025-11-15

---

## Context

We need to deploy a new web application onto the AWS cloud. The application architecture consists of a **UI Service**, a backend **Service 1**, and a job executor **Service 2**, which requires parallel processing.

The key technical requirements are:
* Service 1 and Service 2 are decoupled by a **Queue**.
* Service 2 runs **long-running jobs** and requires **frequent upscaling and downscaling**.
* Jobs must **not terminate prematurely** during downscaling.
* Both services require **OpenJDK 11/17** installed.
* A **common database** is needed for job management.
* The solution must be **cost-effective** and automated with **Terraform**.

---

## Decision

We will adopt a cloud-native, serverless container architecture using the following AWS services:

1.  **Application Services (Service 1 & 2):** We will containerize both services using **Docker** to package the OpenJDK dependency. These containers will be deployed on **Amazon ECS (Elastic Container Service)** using the **AWS Fargate** launch type. This eliminates the need to manage underlying EC2 instances.

2.  **UI Service:** The static UI will be hosted in an **Amazon S3** bucket and distributed globally with low latency via **Amazon CloudFront**.

3.  **Queue:** We will use **Amazon SQS (Simple Queue Service)** as the fully managed message queue to decouple Service 1 and Service 2.

4.  **Database:** We will use **Amazon RDS** (e.g., PostgreSQL or MySQL) as the fully managed "common database."

5.  **Scaling (Service 2):** We will use **ECS Service Auto Scaling** for Service 2. The scaling policy will be triggered by the SQS queue depth (a CloudWatch `ApproximateNumberOfMessagesVisible` metric). This will automatically launch more tasks as jobs pile up and remove them when the queue is empty.

6.  **Job Protection (Service 2):** We will configure the ECS task definition with a `stopTimeout` (e.g., 300 seconds). This instructs ECS to send a `SIGTERM` signal and wait for the specified time before forcefully stopping a task, allowing it to finish its in-flight job gracefully.

7.  **Automation:** All infrastructure will be provisioned and managed as code using **Terraform**.

---

## Considered Options (Alternatives)

1.  **AWS EC2 Auto Scaling Groups:**
    * **Why not?** This approach requires manual management of the underlying OS, including patching, security, and installing the OpenJDK dependency. It has a higher operational overhead and is generally less cost-effective, as instances would be idle during quiet periods.

2.  **AWS Elastic Beanstalk:**
    * **Why not?** While a good PaaS option, it is less flexible for this decoupled, event-driven architecture. ECS provides more granular control over the scaling policies, especially for a "worker" service (Service 2) that isn't driven by web traffic.

3.  **AWS Lambda:**
    * **Why not?** The requirement states Service 2 runs "long running jobs". Lambda functions have a 15-minute maximum execution timeout, which may not be sufficient. Fargate tasks can run indefinitely, making them a much safer choice for this requirement.

---

## Consequences

**Positive:**
* **Reduced Operational Overhead:** Fargate is "serverless," so there are no virtual machines to manage, patch, or secure.
* **Cost-Effective:** The pay-per-use model of Fargate and SQS, combined with scaling Service 2 based on demand (potentially to zero), will be highly cost-efficient.
* **Fulfils All Requirements:** This design directly addresses every requirement, including the OpenJDK dependency (via containers), parallel processing (multiple Fargate tasks), auto-scaling (via SQS), and job protection (via `stopTimeout`).
* **Scalable & Managed:** The architecture is built on highly scalable, managed AWS services (ECS, SQS, RDS, S3), reducing the management burden.

**Negative (Trade-offs):**
* **Vendor Lock-in:** This solution is deeply integrated with AWS managed services. Migrating to a different cloud provider in the future would be a significant effort.
* **Fargate Startup Times:** Fargate tasks have a startup time (to pull the container image) that is longer than Lambda. This is acceptable for the asynchronous Service 2 but must be monitored for Service 1's API latency.
* **Configuration Complexity:** The initial Terraform setup for all the service integrations (IAM roles, security groups, VPC, ECS task definitions, and scaling policies) is complex, though it provides long-term automation benefits.
