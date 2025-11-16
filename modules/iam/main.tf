# Standard execution role for ECS tasks [cite: 101]
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Service 1 Task Role ---
resource "aws_iam_role" "service1_task_role" {
  name = "service1-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
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
        Action   = ["sqs:SendMessage"] # [cite: 101]
        Effect   = "Allow"
        Resource = var.sqs_queue_arn
      },
      {
        Action   = ["rds-data:ExecuteStatement"] # Example for RDS access
        Effect   = "Allow"
        Resource = "arn:aws:rds:*:*:db:${var.db_instance_id}"
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
      Action = "sts:AssumeRole"
      Effect = "Allow"
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
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"] # [cite: 101]
        Effect   = "Allow"
        Resource = var.sqs_queue_arn
      },
      {
        Action   = ["rds-data:ExecuteStatement"] # Example for RDS access [cite: 102]
        Effect   = "Allow"
        Resource = "arn:aws:rds:*:*:db:${var.db_instance_id}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "service2_attach" {
  role       = aws_iam_role.service2_task_role.name
  policy_arn = aws_iam_policy.service2_policy.arn
}