resource "aws_db_subnet_group" "default" {
  name       = "main-db-subnet-group"
  subnet_ids = var.db_subnets
  tags = merge(var.tags, {
    Name = "main-db-subnet-group"
  })
}

resource "aws_db_instance" "default" {
  identifier             = "app-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres" # [cite: 24]
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  db_name                = "appdb"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [var.db_security_group]
  skip_final_snapshot    = true
  tags                   = var.tags
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.tags.Project}-${var.tags.Environment}-db-credentials-v9"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}
