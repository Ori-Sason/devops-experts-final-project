resource "aws_subnet" "k3s_priv" {
  vpc_id            = var.devops_experts_vpc_id
  cidr_block        = "172.20.3.0/24"
  availability_zone = var.zone1
  tags = {
    Name = "devops-experts-k3s-priv-sub"
  }
}

resource "aws_route_table" "k3s_priv_rt" {
  vpc_id = var.devops_experts_vpc_id

  tags = {
    Name = "devops-experts-k3s-priv-rt"
  }
}

resource "aws_route" "k3s_priv_nat_route" {
  route_table_id         = aws_route_table.k3s_priv_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.devops_experts_nat_id
}

resource "aws_route_table_association" "devops_experts_k3s_priv_sub" {
  subnet_id      = aws_subnet.k3s_priv.id
  route_table_id = aws_route_table.k3s_priv_rt.id

  # For making sure NAT GW is available before creating instances
  depends_on = [aws_route.k3s_priv_nat_route]
}
