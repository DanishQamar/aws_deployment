# Standard execution role for ECS tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- FIX: Give the Execution Role permission to pull  database secrets ---
# This is Correction #1 from ADR-002: Credential Management
resource "aws_iam_policy" "ecs_execution_secrets_policy" {
  name = "ecs-execution-secrets-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["secretsmanager:GetSecretValue"]
        Effect   = "Allow"
        Resource = var.db_credentials_secret_arn # Must be the specific secret ARN
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_secrets_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_secrets_policy.arn
}
# --- END FIX ---

# --- Service 1 Task Role ---
resource "aws_iam_role" "service1_task_role" {
  name = "service1-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "service1_policy" {
  name = "service1-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # --- FIX: Added "sqs:GetQueueAttributes" to allow SqsTemplate to init ---
        # This is Correction #3 from ADR-002: SQS Client Permissions
        Action = ["sqs:SendMessage", "sqs:GetQueueAttributes"] #
        # --- END FIX ---
        Effect   = "Allow"
        Resource = var.sqs_queue_arn
      },
      {
        Action = ["rds-data:ExecuteStatement"] #

        Effect   = "Allow"
        Resource = "arn:aws:rds:*:*:db:${var.db_instance_id}"
      },
      {
        Action   = ["secretsmanager:GetSecretValue"]
        Effect   = "Allow"
        Resource = var.db_credentials_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "service1_attach" {
  role       = aws_iam_role.service1_task_role.name
  policy_arn = aws_iam_policy.service1_policy.arn
}

# --- Service 2 Task Role ---
resource "aws_iam_role" "service2_task_role" {
  name = "service2-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "service2_policy" {
  name = "service2-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {

        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"] #
        Effect   = "Allow"
        Resource = var.sqs_queue_arn
      },
      {
        Action   = ["rds-data:ExecuteStatement"] # Example for RDS access
        Effect   = "Allow"
        Resource = "arn:aws:rds:*:*:db:${var.db_instance_id}"
      },
      {

        Action   = ["secretsmanager:GetSecretValue"]
        Effect   = "Allow"
        Resource = var.db_credentials_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "service2_attach" {
  role       = aws_iam_role.service2_task_role.name
  policy_arn = aws_iam_policy.service2_policy.arn
}
