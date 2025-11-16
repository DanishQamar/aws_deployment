resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "main" {
  name = "/ecs/main-cluster"
  tags = var.tags
}

resource "aws_ecr_repository" "service1" {
  name                 = "service1"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = true # Allows deletion even if images are present

  tags = var.tags
}

resource "aws_ecr_repository" "service2" {
  name                 = "service2"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  force_delete = true # Allows deletion even if images are present

  tags = var.tags
}
