module "jenkins" {
  source = "./jenkins"

  region                = var.region
  zone1                 = var.zone1
  ubuntu_ami_id         = var.ubuntu_ami_id
  devops_experts_vpc_id = aws_vpc.devops_experts_vpc.id
  devops_experts_nat_id = aws_nat_gateway.nat_gw.id
  alb_sg_id             = aws_security_group.alb_sg.id
}

module "k3_cluster" {
  source = "./k3_cluster"

  region                = var.region
  zone1                 = var.zone1
  ubuntu_ami_id         = var.ubuntu_ami_id
  devops_experts_vpc_id = aws_vpc.devops_experts_vpc.id
  devops_experts_nat_id = aws_nat_gateway.nat_gw.id
  alb_sg_id             = aws_security_group.alb_sg.id
  web_app_node_port     = var.web_app_node_port
  jenkins_sg_id         = module.jenkins.jenkins_sg_id
}
