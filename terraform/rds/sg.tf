resource "aws_security_group" "rds_sg" {
  name        = "devops-experts-rds-sg"
  description = "Allow inbound PostgreSQL traffic"
  vpc_id      = var.devops_experts_vpc_id

  tags = {
    Name = "devops-experts-rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_k3s" {
  security_group_id            = aws_security_group.rds_sg.id
  referenced_security_group_id = var.k3s_web_app_nodes_sg_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "rds_allow_all_outbound" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
