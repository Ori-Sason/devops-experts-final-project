resource "aws_security_group" "jenkins_sg" {
  name        = "devops-experts-jenkins-sg"
  description = "devops-experts-jenkins-sg"
  vpc_id      = var.devops_experts_vpc_id
  tags = {
    Name = "devops-experts-jenkins-subnet-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_sg_inbound_allow_alb_80" {
  security_group_id            = aws_security_group.jenkins_sg.id
  referenced_security_group_id = var.alb_sg_id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
}

resource "aws_vpc_security_group_egress_rule" "jenkins_sg_outbound_allow_all" {
  security_group_id = aws_security_group.jenkins_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
