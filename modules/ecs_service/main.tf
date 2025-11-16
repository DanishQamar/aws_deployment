# --- Task Definition ---
resource "aws_ecs_task_definition" "main" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = "${var.image_uri}:latest"
      cpu       = var.cpu
      memory    = var.memory
      essential = true
      portMappings = var.container_port != null ? [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ] : []
      environment = [
        # Pass the SQS queue URL as an environment variable
        # This is used by the Python application to avoid hardcoding values.
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url },
        { name = "SQS_QUEUE_NAME", value = var.sqs_queue_name }, # We will add this variable
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_NAME", value = var.db_name },
        # Pass the ARN of the secret, not the credentials themselves
        #{ name = "DB_CREDENTIALS_SECRET_ARN", value = var.db_credentials_secret_arn }

      ]
      secrets = [
        {
          "name" : "username", # Creates an env var named 'username'
          "valueFrom" : "${var.db_credentials_secret_arn}:username::"
        },
        {
          "name" : "password", # Creates an env var named 'password'
          "valueFrom" : "${var.db_credentials_secret_arn}:password::"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = var.service_name
        }
      }
    }
  ])
  tags = var.tags
}

# --- ALB (Conditional for Service 1) [cite: 108] ---
resource "aws_lb" "main" {
  count              = var.create_alb ? 1 : 0
  name               = "${var.service_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids
  tags               = var.tags
}

resource "aws_lb_target_group" "main" {
  count       = var.create_alb ? 1 : 0
  name        = "${var.service_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    # --- FIX IS HERE ---
    path     = "/jobs" # Change this from "/" to "/jobs"
    matcher  = "200"   # Explicitly state that 200 is healthy
    protocol = "HTTP"
    # --- END FIX ---
  }

  tags = var.tags
}
resource "aws_lb_listener" "http" {
  count             = var.create_alb ? 1 : 0
  load_balancer_arn = aws_lb.main[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[0].arn
  }

  # Add this explicit dependency
  depends_on = [aws_lb_target_group.main]
}

# --- ECS Service ---
resource "aws_ecs_service" "main" {
  name            = var.service_name
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = var.ecs_security_group_ids
  }

  # Conditionally create the load_balancer block if create_alb is true
  dynamic "load_balancer" {
    for_each = var.create_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.main[0].arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  # This ensures the service depends on the ALB listener being ready
  depends_on = [aws_lb_listener.http]
  tags       = var.tags
}

# --- SQS Auto Scaling (Conditional for Service 2) [cite: 109, 110] ---
resource "aws_appautoscaling_target" "ecs_target" {
  count        = var.enable_sqs_scaling ? 1 : 0
  max_capacity = var.max_tasks
  min_capacity = var.min_tasks
  # FIX: Use the 'name' attribute from the service resource
  # This creates an implicit dependency.
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "sqs_scaling_policy" {
  count              = var.enable_sqs_scaling ? 1 : 0
  name               = "${var.service_name}-sqs-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 5.0 # Target 5 messages per task
    scale_out_cooldown = 60
    scale_in_cooldown  = 60

    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"
      dimensions {
        name  = "QueueName"
        value = data.aws_sqs_queue.main[0].name
      }
    }
  }
}

# --- Data Sources ---
data "aws_region" "current" {}

data "aws_sqs_queue" "main" {
  count = var.enable_sqs_scaling ? 1 : 0
  # The queue name is derived from the ARN passed in.
  # The ARN format is arn:partition:service:region:account-id:resource-id
  name = split(":", var.sqs_queue_arn)[5]
}
