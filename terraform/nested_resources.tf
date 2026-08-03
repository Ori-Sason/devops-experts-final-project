data "aws_caller_identity" "current" {}

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

  region                              = var.region
  zone1                               = var.zone1
  ubuntu_ami_id                       = var.ubuntu_ami_id
  devops_experts_vpc_id               = aws_vpc.devops_experts_vpc.id
  devops_experts_nat_id               = aws_nat_gateway.nat_gw.id
  account_id                          = data.aws_caller_identity.current.account_id
  alb_sg_id                           = aws_security_group.alb_sg.id
  web_app_node_port                   = var.web_app_node_port
  jenkins_sg_id                       = module.jenkins.jenkins_sg_id
  ssm_read_for_rds_secrets_policy_arn = module.rds.ssm_read_for_rds_secrets_policy_arn
}

module "rds" {
  source = "./rds"

  region                  = var.region
  zone1                   = var.zone1
  zone2                   = var.zone2
  devops_experts_vpc_id   = aws_vpc.devops_experts_vpc.id
  account_id              = data.aws_caller_identity.current.account_id
  db_username             = var.db_username
  db_password             = var.db_password
  k3s_web_app_nodes_sg_id = module.k3_cluster.k3s_web_app_nodes_sg_id
}
