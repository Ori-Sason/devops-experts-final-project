resource "aws_vpc" "devops_experts_vpc" {
  cidr_block = "172.20.0.0/16"
  tags = {
    Name = "devops-experts-vpc"
  }
}

# Adopts the default main route table to keep it clean and labeled
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.devops_experts_vpc.default_route_table_id

  route = []

  tags = {
    Name = "devops-experts-default-main-rt-do-not-use"
  }
}

# Adopts and completely strip the default security group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.devops_experts_vpc.id

  tags = {
    Name = "devops-experts-vpc-default-sg-isolated"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devops_experts_vpc.id
  tags = {
    Name = "devops-experts-igw"
  }
}

resource "aws_subnet" "pub_sub_1" {
  vpc_id            = aws_vpc.devops_experts_vpc.id
  cidr_block        = "172.20.1.0/24"
  availability_zone = var.zone1
  tags = {
    Name = "devops-experts-pub-sub-1"
  }
}

resource "aws_route_table" "pub_sub_1_rt" {
  vpc_id = aws_vpc.devops_experts_vpc.id

  tags = {
    Name = "devops-experts-pub-sub-1-rt"
  }
}

resource "aws_route" "pub_sub_1_rt_route" {
  route_table_id         = aws_route_table.pub_sub_1_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "pub_sub_1" {
  subnet_id      = aws_subnet.pub_sub_1.id
  route_table_id = aws_route_table.pub_sub_1_rt.id
}

resource "aws_subnet" "pub_sub_2" {
  vpc_id            = aws_vpc.devops_experts_vpc.id
  cidr_block        = "172.20.2.0/24"
  availability_zone = var.zone2
  tags = {
    Name = "devops-experts-pub-sub-2"
  }
}

resource "aws_route_table" "pub_sub_2_rt" {
  vpc_id = aws_vpc.devops_experts_vpc.id

  tags = {
    Name = "devops-experts-pub-sub-2-rt"
  }
}

resource "aws_route" "pub_sub_2_rt_route" {
  route_table_id         = aws_route_table.pub_sub_2_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "pub_sub_2" {
  subnet_id      = aws_subnet.pub_sub_2.id
  route_table_id = aws_route_table.pub_sub_2_rt.id
}

resource "aws_eip" "nat_gw_eip" {
  domain = "vpc"

  tags = {
    Name = "devops-experts-nat-gw-iep"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  subnet_id     = aws_subnet.pub_sub_1.id
  allocation_id = aws_eip.nat_gw_eip.id
  tags = {
    Name = "devops-experts-nat-gw"
  }
}
