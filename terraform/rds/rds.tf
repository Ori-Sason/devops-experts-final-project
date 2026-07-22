resource "aws_db_instance" "devops_experts_rds" {
  engine                = "postgres"
  engine_version        = "18.3"
  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  storage_type          = "gp3"
  max_allocated_storage = 0

  apply_immediately = true # Dev/Test template applies changes immediately rather than waiting for the maintenance window

  identifier = "devops-experts-db"
  db_name    = "devops_final_project_prod"

  username                            = var.db_username
  password                            = var.db_password
  iam_database_authentication_enabled = false # FIX - Default is false; set to true if using IAM Auth

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  port                   = 5432
  publicly_accessible    = false

  backup_retention_period    = 0
  auto_minor_version_upgrade = true
  deletion_protection        = false # Set to true in production to prevent accidental terraform destroy
  skip_final_snapshot        = true  # Set to false in real production to take a backup on destroy

  storage_encrypted            = true
  performance_insights_enabled = false

  tags = {
    Name = "devops-experts-db"
  }
}

resource "aws_ssm_parameter" "db_credentials" {
  name = "/devops-experts-final-project/prod/db-credentials"
  type = "SecureString"
  value = jsonencode({
    POSTGRES_USER     = aws_db_instance.devops_experts_rds.username
    POSTGRES_PASSWORD = aws_db_instance.devops_experts_rds.password
    POSTGRES_DB       = aws_db_instance.devops_experts_rds.db_name
    DB_HOST           = aws_db_instance.devops_experts_rds.address
  })
}
