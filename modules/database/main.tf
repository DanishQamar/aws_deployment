resource "aws_db_subnet_group" "default" {
  name       = "main-db-subnet-group"
  subnet_ids = var.db_subnets
  tags = merge(var.tags, {
    Name = "main-db-subnet-group"
  })
}

resource "aws_db_instance" "default" {
  identifier           = "app-db"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres" # [cite: 24]
  # AWS RDS engine versions are region-specific and updated frequently.
  # Version 15.3 is not available. Using a more recent, stable minor version.
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  db_name              = "appdb"
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [var.db_security_group]
  skip_final_snapshot  = true
  tags = var.tags
}