resource "aws_ecs_cluster" "main" {
  name = "main-cluster"
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "main" {
  name = "/ecs/main-cluster"
  tags = var.tags
}

resource "aws_ecr_repository" "service1" {
  name = "service1"
  image_tag_mutability = "MUTABLE"
  tags = var.tags
}

resource "aws_ecr_repository" "service2" {
  name = "service2"
  image_tag_mutability = "MUTABLE"
  tags = var.tags
}