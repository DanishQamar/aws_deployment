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

3.  **Queue:** We will use **Amazon SQS (Simple Queue Service)** as the fully managed message queue to decouple Service
