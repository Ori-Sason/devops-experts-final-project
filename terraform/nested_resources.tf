module "jenkins" {
  source = "./jenkins"

  region                = var.region
  zone1                 = var.zone1
  t3_micro_ami_id       = var.t3_micro_ami_id
  devops_experts_vpc_id = aws_vpc.devops_experts_vpc.id
  devops_experts_nat_id = aws_nat_gateway.nat_gw.id
  alb_sg_id             = aws_security_group.alb_sg.id
}
