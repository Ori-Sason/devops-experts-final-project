resource "aws_instance" "k3s_monitoring" {
  ami                    = var.ubuntu_ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_route_table_association.devops_experts_k3s_priv_sub.subnet_id # Making sure NAT GW is available before creating the instance
  iam_instance_profile   = aws_iam_instance_profile.k3s_worker_profile.name
  vpc_security_group_ids = [aws_security_group.k3s_monitoring_sg.id]

  user_data = templatefile("${path.module}/scripts/worker_provision.sh", {
    aws_region      = var.region,
    node_role_label = "monitoring"
  })

  tags = {
    Name = "devops-experts-k3s-monitoring"
    Role = "k3s-monitoring"
  }
}
