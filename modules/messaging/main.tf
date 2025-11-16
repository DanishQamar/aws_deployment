resource "aws_sqs_queue" "default" {
  name = "job-queue"
  tags = var.tags
}