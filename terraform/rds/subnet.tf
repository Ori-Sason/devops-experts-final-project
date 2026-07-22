resource "aws_subnet" "rds_priv_1" {
  vpc_id            = var.devops_experts_vpc_id
  cidr_block        = "172.20.4.0/24"
  availability_zone = var.zone1
  tags = {
    Name = "devops-experts-rds-priv-sub"
  }
}

resource "aws_route_table" "rds_priv_1_rt" {
  vpc_id = var.devops_experts_vpc_id

  tags = {
    Name = "devops-experts-rds-priv-rt"
  }
}

resource "aws_subnet" "rds_priv_2" {
  vpc_id            = var.devops_experts_vpc_id
  cidr_block        = "172.20.5.0/24"
  availability_zone = var.zone2
  tags = {
    Name = "devops-experts-rds-priv-sub"
  }
}

resource "aws_route_table" "rds_priv_2_rt" {
  vpc_id = var.devops_experts_vpc_id

  tags = {
    Name = "devops-experts-rds-priv-rt"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "devops-experts-rds-subnet-group"
  subnet_ids = [
    aws_subnet.rds_priv_1.id,
    aws_subnet.rds_priv_2.id
  ]

  tags = {
    Name = "devops-experts-rds-subnet-group"
  }
}
